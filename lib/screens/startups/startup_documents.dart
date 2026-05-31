  //Giovana Uchelli - 25008818
  import 'package:flutter/material.dart';
  import 'package:url_launcher/url_launcher.dart'; //Usado para abrir url externas (documentos)
  import '../../models/documento.dart';
  import '../../models/startup.dart';
  import '../../services/document_service.dart';
  import '../balcao/balcao_screen.dart';

  // Aba de documentos da startup — exibe docs públicos e exclusivos para investidores
  class DocumentosTab extends StatefulWidget {
    final Startup? startup;
    const DocumentosTab({super.key, this.startup});

    @override
    State<DocumentosTab> createState() => _DocumentosTabState();
  }

  class _DocumentosTabState extends State<DocumentosTab> {
    late final DocumentoService _service;
    late Future<_DocumentosData> _futureData; // Future que carrega todos os dados da aba

    // Lista fixa dos tipos de documentos públicos esperados
    static const _tiposFixos = [
      {
        'tipo': 'sumario_executivo',
        'titulo': 'Sumário Executivo',
        'descricao': 'Visão geral do negócio, mercado e proposta de valor',
      },
      {
        'tipo': 'plano_negocios',
        'titulo': 'Plano de Negócios',
        'descricao': 'Projeções financeiras, estratégia e roadmap completo',
      },
    ];

    @override
    void initState() {
      super.initState();
      _service = DocumentoService();
      _futureData = _carregarDados(); // Inicia o carregamento ao abrir a aba
    }

    // Busca documentos, status de investidor e doc exclusivo em paralelo
    Future<_DocumentosData> _carregarDados() async {
      final startupId = widget.startup?.uid;
      if (startupId == null) {
        return _DocumentosData(documentos: [], isInvestidor: false, docExclusivo: null);
      }

      // Future.wait executa as 3 chamadas ao mesmo tempo para melhor performance
      final results = await Future.wait([
        _service.getDocumentos(startupId),
        _service.isInvestidor(startupId),
        _service.getDocumentoExclusivo(startupId),
      ]);

      return _DocumentosData(
        documentos: results[0] as List<Documento>,
        isInvestidor: results[1] as bool,
        docExclusivo: results[2] as Documento?,
      );
    }

    // Abre a URL do documento no navegador externo
    Future<void> _baixarDocumento(String url) async {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o documento.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      return FutureBuilder<_DocumentosData>(
        future: _futureData,
        builder: (context, snapshot) {
          // Exibe loading enquanto os dados não chegaram
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ??
              _DocumentosData(documentos: [], isInvestidor: false, docExclusivo: null);

          // Transforma a lista em mapa para buscar doc por tipo rapidamente
          final mapaDocumentos = {
            for (final doc in data.documentos) doc.tipo: doc,
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seção: documentos públicos (visíveis para todos)
                const Text(
                  'Documentos públicos',
                  style: TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                // Gera um item para cada tipo fixo, verificando se o doc existe no Firestore
                ..._tiposFixos.map((fixo) {
                  final doc = mapaDocumentos[fixo['tipo']];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DocumentoItem(
                      titulo: fixo['titulo']!,
                      descricao: fixo['descricao']!,
                      bloqueado: false,
                      disponivel: doc != null && doc.url.isNotEmpty,
                      onDownload: doc != null && doc.url.isNotEmpty
                          ? () => _baixarDocumento(doc.url)
                          : null,
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Seção: documento exclusivo para investidores
                const Text(
                  'Documentos exclusivos para investidores',
                  style: TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),

                _DocumentoItem(
                  titulo: 'Relatório financeiro detalhado',
                  // Descrição muda conforme o usuário for ou não investidor
                  descricao: data.isInvestidor
                      ? 'Disponível para você como investidor desta startup'
                      : 'Disponível somente para investidores desta startup',
                  bloqueado: !data.isInvestidor,
                  disponivel: data.isInvestidor &&
                      data.docExclusivo != null &&
                      data.docExclusivo!.url.isNotEmpty,
                  // Link "Investir para desbloquear" aparece só para não-investidores
                  linkText: !data.isInvestidor ? 'Investir para desbloquear' : null,
                  // Investidor mas o doc ainda não foi enviado pela startup
                  indisponivel: data.isInvestidor &&
                      (data.docExclusivo == null || data.docExclusivo!.url.isEmpty),
                  onDownload: data.isInvestidor &&
                      data.docExclusivo != null &&
                      data.docExclusivo!.url.isNotEmpty
                      ? () => _baixarDocumento(data.docExclusivo!.url)
                      : null,
                  // Clique no link leva ao balcão para o usuário investir
                  onLinkTap: !data.isInvestidor
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BalcaoScreen(abaInicial: 0),
                            ),
                          )
                      : null,
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // Classe interna que agrupa os dados carregados para a aba
  class _DocumentosData {
    final List<Documento> documentos; // Documentos públicos da startup
    final bool isInvestidor;          // Se o usuário logado é investidor desta startup
    final Documento? docExclusivo;    // Documento exclusivo (pode ser null se não cadastrado)

    _DocumentosData({
      required this.documentos,
      required this.isInvestidor,
      required this.docExclusivo,
    });
  }

  // Widget reutilizável que representa um card de documento
  class _DocumentoItem extends StatelessWidget {
    final String titulo;
    final String descricao;
    final bool bloqueado;    // Exibe cadeado se o usuário não tem acesso
    final bool disponivel;   // Se o documento tem URL para download
    final bool indisponivel; // Investidor com acesso, mas doc ainda sem URL
    final String? linkText;  // Texto do link opcional (ex: "Investir para desbloquear")
    final VoidCallback? onDownload;
    final VoidCallback? onLinkTap;

    const _DocumentoItem({
      required this.titulo,
      required this.descricao,
      required this.bloqueado,
      required this.disponivel,
      this.indisponivel = false,
      this.linkText,
      this.onDownload,
      this.onLinkTap,
    });

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descricao,
                    style: const TextStyle(fontSize: 12, color: Colors.black45, height: 1.4),
                  ),
                  // Doc público mas ainda não enviado pela startup
                  if (!bloqueado && !disponivel && !indisponivel) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Documento não disponível',
                      style: TextStyle(fontSize: 12, color: Colors.black38, fontStyle: FontStyle.italic),
                    ),
                  ],
                  // Investidor com acesso, mas startup ainda não enviou o arquivo
                  if (indisponivel) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Documento em preparação pela startup',
                      style: TextStyle(fontSize: 12, color: Colors.black38, fontStyle: FontStyle.italic),
                    ),
                  ],
                  // Link clicável opcional (ex: "Investir para desbloquear")
                  if (linkText != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Ícone à direita: cadeado, download ou relógio conforme o estado
            GestureDetector(
              onTap: onDownload,
              child: Icon(
                bloqueado
                    ? Icons.lock_outline
                    : disponivel
                        ? Icons.download_outlined
                        : Icons.hourglass_empty_outlined,
                size: 20,
                color: bloqueado
                    ? Colors.black38
                    : disponivel
                        ? const Color(0xFF1A237E)
                        : Colors.black26,
              ),
            ),
          ],
        ),
      );
    }
  }