//Giovana Uchelli - 25008818

import 'package:cloud_firestore/cloud_firestore.dart'; // Banco de dados Firestore (Firebase)
import 'package:firebase_auth/firebase_auth.dart';     // Autenticação Firebase
import 'package:flutter/material.dart';                // Widgets do Flutter
import '../balcao/balcao_screen.dart';
import '../startups/startup_overview.dart';
import '../startups/startup_society.dart';
import '../startups/startup_documents.dart';
import '../startups/startup_questions.dart';
import '../home/home_screen.dart';
import '../../models/orderbook_models.dart' show Wallet;      // Importa apenas o modelo Wallet
import '../../models/startup.dart';
import '../../services/balcao_service.dart';
import '../../services/startup_service.dart' hide Startup;   // Serviço de startups (oculta a classe Startup para evitar conflito com o model)

// Tela de detalhes de uma startup — recebe o ID da startup por parâmetro
class StartupDetalheScreen extends StatefulWidget {
  final String startupUid;

  const StartupDetalheScreen({super.key, required this.startupUid});

  @override
  State<StartupDetalheScreen> createState() => _StartupDetalheScreenState();
}

// SingleTickerProviderStateMixin fornece um "ticker" (temporizador de animação)
// necessário para o TabController animar as abas com vsync: this
class _StartupDetalheScreenState extends State<StartupDetalheScreen>
    with SingleTickerProviderStateMixin {


  late TabController _tabController; // Controla as abas (Visão Geral, Sociedade, etc.)

  final StartupService _service = StartupService();
  final BalcaoService _balcaoService = BalcaoService();

  Startup? _startup;             // Dados da startup carregados do Firestore
  bool _carregando = true;       // Exibe loading enquanto busca os dados
  bool _comprando = false;       // Bloqueia o botão durante uma compra
  int _tokensNaCarteira = 0;     // Quantidade de tokens que o usuário possui dessa startup
  bool _eInvestidorAtivo = false;
  String? _erroCarregamento;     // Mensagem de erro, se houver

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 abas
    _carregarStartup();  // Busca os dados da startup
    _carregarPosicao();  // Busca a posição do usuário nessa startup
  }

  // Busca os dados da startup pelo ID e atualiza o estado
  Future<void> _carregarStartup() async {
    try {
      final startup = await _service.getStartup(widget.startupUid);
      if (mounted) {
        setState(() {
          _startup = startup;
          _carregando = false;
          _erroCarregamento = startup == null ? 'Startup não encontrada.' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erroCarregamento = 'Erro ao carregar dados: $e';
        });
      }
    }
  }

  // Busca no Firestore quantos tokens o usuário tem dessa startup
  Future<void> _carregarPosicao() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('positions')
          .doc(widget.startupUid)
          .get();
      final data = snap.data() ?? {};
      final tokens = (data['tokens_livres'] as num?)?.toInt() ?? 0;
      final ativo = (data['investidor_ativo'] as bool?) ?? false;
      if (mounted) setState(() {
        _tokensNaCarteira = tokens;
        _eInvestidorAtivo = ativo;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose(); // Libera o controlador de abas
    super.dispose();
  }

  // Formata valores grandes: 1500000 → "R$ 1.5M", 3000 → "R$ 3K"
  String _formatarCapital(double valor) {
    if (valor >= 1000000) return 'R\$ ${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return 'R\$ ${(valor / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${valor.toStringAsFixed(0)}';
  }

  // Retorna a cor de fundo da tag de status
  Color _tagColor(String status) {
    switch (status) {
      case 'Em expansão': return const Color(0xFFFFF3E0);
      case 'Em operação': return const Color(0xFFE8F5E9);
      case 'Nova':        return const Color(0xFFE8E6FF);
      default:            return const Color(0xFFEEEEEE);
    }
  }

  // Retorna a cor do texto da tag de status
  Color _tagTextColor(String status) {
    switch (status) {
      case 'Em expansão': return const Color(0xFFE65100);
      case 'Em operação': return const Color(0xFF2E7D32);
      case 'Nova':        return const Color(0xFF6C63FF);
      default:            return Colors.black54;
    }
  }

  // Formata preço com vírgula: 12.50 → "R$ 12,50"
  String _formatarPreco(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Abre o diálogo de compra direta a mercado
  Future<void> _abrirCompraDireta() async {
    final startup = _startup;
    if (startup == null || _comprando) return;

    final quantidadeController = TextEditingController(text: '1');

    // Busca o saldo atual da carteira antes de abrir o diálogo
    final Wallet wallet = await _balcaoService.watchWallet().first;
    if (!mounted) {
      quantidadeController.dispose();
      return;
    }
    final saldoAtual = wallet.brlDisponivel;

    // Diálogo com campo de quantidade, total estimado e saldo pós-compra
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantidade = int.tryParse(quantidadeController.text.trim()) ?? 0;
            final total = quantidade > 0 ? quantidade * startup.precoToken : 0.0;
            final saldoPosCom = saldoAtual - total;
            final saldoInsuficiente = total > saldoAtual && total > 0;

            return AlertDialog(
              title: const Text('Comprar tokens'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    startup.nome ?? 'Startup',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text('Preço atual: ${_formatarPreco(startup.precoToken)} por token'),
                  const SizedBox(height: 4),
                  // Aviso: o preço final pode variar conforme o book de ordens
                  const Text(
                    'Ordem a mercado — preço final depende do book.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  // Campo para o usuário digitar a quantidade
                  TextField(
                    controller: quantidadeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}), // Recalcula ao digitar
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total estimado: ${_formatarPreco(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  // Card com saldo atual e saldo após a compra
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo atual: ${_formatarPreco(saldoAtual)}',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saldo após compra: ${_formatarPreco(saldoPosCom.clamp(0, double.infinity))}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            // Vermelho se saldo insuficiente, verde se ok
                            color: saldoInsuficiente ? Colors.redAccent : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  // Desabilita o botão se o saldo for insuficiente
                  onPressed: saldoInsuficiente
                      ? null
                      : () {
                          final parsed = int.tryParse(quantidadeController.text.trim()) ?? 0;
                          if (parsed <= 0) return;
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Confirmar compra'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true || !mounted) {
      quantidadeController.dispose();
      return;
    }

    final quantidade = int.parse(quantidadeController.text.trim());
    quantidadeController.dispose();

    setState(() => _comprando = true); // Ativa o loading no botão

    // Envia a ordem de compra a mercado
    final result = await _balcaoService.createOrder(
      startupId: widget.startupUid,
      side: 'buy',
      orderType: 'market',
      qty: quantidade,
    );

    if (!mounted) return;
    setState(() => _comprando = false);

    if (result.success) {
      // Mensagem diferente se a ordem foi executada imediatamente ou ficou no book
      final msg = result.tradesExecuted > 0
          ? 'Compra executada: $quantidade token(s) de ${startup.nome ?? 'startup'}.'
          : 'Ordem enviada — aguardando contraparte no book.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _carregarPosicao(); // Atualiza os tokens na carteira
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Erro ao processar compra.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _startup;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Cabeçalho fixo com botão voltar, dados da startup e abas
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    constraints: const BoxConstraints(),
                  ),

                  // Exibe loading, erro ou dados conforme o estado
                  if (_carregando)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_erroCarregamento != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _erroCarregamento!,
                            style: const TextStyle(fontSize: 13, color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _carregando = true;
                                _erroCarregamento = null;
                              });
                              _carregarStartup();
                            },
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Nome, setor e tag de status da startup
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s?.nome ?? '',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s?.setor ?? '',
                                style: const TextStyle(fontSize: 13, color: Colors.black45),
                              ),
                            ],
                          ),
                          // Tag colorida com o status da startup
                          if (s?.status != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _tagColor(s!.status!),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.status!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tagTextColor(s.status!),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Barra de progresso do capital captado
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Capital captado',
                                  style: TextStyle(fontSize: 12, color: Colors.black45)),
                              Text(
                                s == null
                                    ? ''
                                    : '${_formatarCapital(s.cptAportado)} / ${_formatarCapital(s.metaCapital)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black45),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Barra com gradiente mostrando % do capital captado
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(height: 5, color: const Color(0xFFEEEEEE)),
                                FractionallySizedBox(
                                  widthFactor: s?.progressoCapital ?? 0,
                                  child: Container(
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(255, 20, 16, 107),
                                          Color.fromARGB(255, 140, 4, 104),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Botões de ação: Comprar e Vender/Negociar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Botão "Comprar" — abre o diálogo de compra direta
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _comprando ? null : _abrirCompraDireta,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1A237E)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              // Exibe loading enquanto processa a compra
                              child: _comprando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Comprar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A237E),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Botão "Vender (N)" se tem tokens, senão "Negociar"
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => const BalcaoScreen(),
                                  transitionDuration: Duration.zero,      // Sem animação
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: Text(
                                _tokensNaCarteira > 0
                                    ? 'Vender ($_tokensNaCarteira)'
                                    : 'Negociar',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),

                  // Abas de navegação da startup
                  TabBar(
                    controller: _tabController,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    labelColor: const Color(0xFF1A237E),
                    unselectedLabelColor: Colors.black45,
                    indicatorColor: const Color.fromARGB(143, 26, 34, 126),
                    indicatorWeight: 2,
                    tabs: const [
                      Tab(text: 'Visão Geral'),
                      Tab(text: 'Sociedade'),
                      Tab(text: 'Perguntas'),
                      Tab(text: 'Documentos'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo de cada aba
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                VisaoGeralTab(startup: _startup),
                SociedadeTab(startup: _startup),
                PerguntasTab(startup: _startup),
                DocumentosTab(startup: _startup),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}