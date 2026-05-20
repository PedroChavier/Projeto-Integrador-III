import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/documento.dart';
import '../../models/startup.dart';
import '../../services/document_service.dart';
import '../balcao/balcao_screen.dart';

class DocumentosTab extends StatefulWidget {
  final Startup? startup;

  const DocumentosTab({super.key, this.startup});

  @override
  State<DocumentosTab> createState() => _DocumentosTabState();
}

class _DocumentosTabState extends State<DocumentosTab> {
  late final DocumentoService _service;
  late Future<List<Documento>> _futureDocumentos;

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
    _futureDocumentos = widget.startup?.uid != null
        ? _service.getDocumentos(widget.startup!.uid!)
        : Future.value([]);
  }

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
    return FutureBuilder<List<Documento>>(
      future: _futureDocumentos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documentos = snapshot.data ?? [];
        final mapaDocumentos = {
          for (final doc in documentos) doc.tipo: doc,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Documentos públicos ───────────────────────────
              const Text(
                'Documentos públicos',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
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

              // ── Documentos exclusivos (placeholder) ───────────
              const Text(
                'Documentos exclusivos para investidores',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _DocumentoItem(
                titulo: 'Relatório financeiro detalhado',
                descricao: 'Disponível somente para investidores desta startup',
                bloqueado: true,
                disponivel: false,
                linkText: 'Investir para desbloquear',
                onDownload: null,
                onLinkTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BalcaoScreen(abaInicial: 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentoItem extends StatelessWidget {
  final String titulo;
  final String descricao;
  final bool bloqueado;
  final bool disponivel;
  final String? linkText;
  final VoidCallback? onDownload;
  final VoidCallback? onLinkTap;

  const _DocumentoItem({
    required this.titulo,
    required this.descricao,
    required this.bloqueado,
    required this.disponivel,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    height: 1.4,
                  ),
                ),
                if (!bloqueado && !disponivel) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Documento não disponível',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
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