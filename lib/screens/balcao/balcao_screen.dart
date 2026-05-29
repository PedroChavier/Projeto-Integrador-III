import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/orderbook_models.dart';
import '../../models/wallet_holding.dart';
import '../../services/auth_service.dart';
import '../../services/balcao_service.dart';
import '../home/home_screen.dart';

class BalcaoScreen extends StatefulWidget {
  final int abaInicial;

  const BalcaoScreen({super.key, this.abaInicial = 0});

  @override
  State<BalcaoScreen> createState() => _BalcaoScreenState();
}

class _BalcaoScreenState extends State<BalcaoScreen> {
  static const _buyColor = Color(0xFF2E7D32);
  static const _buySoft = Color(0xFFF0F7F3);
  static const _sellColor = Color(0xFFE53935);
  static const _sellSoft = Color(0xFFFEF3F1);
  static const _ink = Color(0xFF121212);
  static const _muted = Color(0xFF6E6E73);
  static const _card = Color(0xFFF8F8F3);
  static const _border = Color(0xFFE2E3D8);
  static const _mine = Color(0xFFE8F0FB);
  static const _accent = Color(0xFF173B7A);

  late OrderbookState _orderbookState;
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _actionPanelKey = GlobalKey();

  final _service = BalcaoService();

  bool _submitting = false;
  bool _dropdownAberto = false;
  bool _loadingStartups = true;
  String _marketQuickMode = 'balance';
  bool _showQuickSlider = false;
  double _quickSliderPct = 50;

  List<Startup> _startups = [];
  int _startupSelecionada = 0;

  // Posições do usuário em todas as startups: startupId -> total tokens
  Map<String, int> _posicoes = const {};
  StreamSubscription<List<WalletHolding>>? _posicoesSub;

  // Entradas de compra do investidor na startup atual (para lock-up de tempo)
  List<({int qty, DateTime acquiredAt})> _purchaseEntries = [];

  // Stream subscriptions – cancelled on startup change and dispose
  StreamSubscription<(List<Order>, List<Order>)>? _ordersSub;
  StreamSubscription<List<Trade>>? _tradesSub;
  StreamSubscription<
      ({double? lastPrice, int tokensVendidos, int tokensEmitidos})>? _stateSub;
  StreamSubscription<Wallet>? _walletSub;
  StreamSubscription<({int tokensLivres, int tokensReservados})>? _positionSub;
  StreamSubscription<List<({int qty, DateTime acquiredAt})>>? _purchasesSub;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _qtyController = TextEditingController();
    _orderbookState = OrderbookState(
      wallet: Wallet(brl: 0, tokens: 0, tokensReserved: 0),
      currentStartup: Startup(
          id: '',
          nome: '...',
          sigla: '...',
          precoEmissao: 0,
          tokensEmitidos: 0),
    );
    _posicoesSub = _service.watchHoldings().listen((holdings) {
      if (!mounted) return;
      setState(() {
        _posicoes = {
          for (final h in holdings) h.startupUid: h.quantidadeTotal,
        };
      });
    });
    _loadStartups();
  }

  Future<void> _loadStartups() async {
    try {
      final startups = await _service.fetchStartups();
      if (!mounted) return;
      setState(() {
        _startups = startups;
        _loadingStartups = false;
      });
      if (startups.isNotEmpty) {
        _applyStartup(0, initialTab: widget.abaInicial == 1 ? 'sell' : 'buy');
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStartups = false);
    }
  }

  void _applyStartup(int index, {String? initialTab}) {
    if (index >= _startups.length) return;
    final startup = _startups[index];

    // Cancel previous subscriptions
    _cancelSubscriptions();
    _clearInputs();

    _orderbookState.changeStartup(startup);
    if (initialTab != null) _orderbookState.setTab(initialTab);

    final startupId = startup.id;

    _walletSub = _service.watchWallet().listen((w) {
      if (mounted) _orderbookState.updateWallet(w);
    });

    _positionSub = _service.watchPosition(startupId).listen((pos) {
      if (mounted) {
        _orderbookState.updatePosition(pos.tokensLivres, pos.tokensReservados);
      }
    });

    _ordersSub = _service.watchOrders(startupId).listen((books) {
      if (mounted) _orderbookState.updateBothBooks(books.$1, books.$2);
    });

    _tradesSub = _service.watchTrades(startupId).listen((t) {
      if (mounted) _orderbookState.updateTrades(t);
    });

    _stateSub = _service.watchBalcaoState(startupId).listen((s) {
      if (mounted) {
        _orderbookState.updateStartupState(s.lastPrice, s.tokensVendidos);
      }
    });

    _purchaseEntries = [];
    _purchasesSub = _service.watchTokenPurchases(startupId).listen((entries) {
      if (mounted) setState(() => _purchaseEntries = entries);
    });
  }

  void _cancelSubscriptions() {
    _ordersSub?.cancel();
    _tradesSub?.cancel();
    _stateSub?.cancel();
    _walletSub?.cancel();
    _positionSub?.cancel();
    _purchasesSub?.cancel();
    _ordersSub = null;
    _tradesSub = null;
    _stateSub = null;
    _walletSub = null;
    _positionSub = null;
    _purchasesSub = null;
  }

  void _changeStartup(int index) {
    final previousTab = _orderbookState.currentTab;
    final previousOrderType = _orderbookState.orderType;
    setState(() {
      _startupSelecionada = index;
      _dropdownAberto = false;
    });
    _applyStartup(index, initialTab: previousTab);
    _orderbookState.setOrderType(previousOrderType);
  }

  void _clearInputs() {
    _priceController.clear();
    _qtyController.clear();
    _orderbookState.inputPrice = 0;
    _orderbookState.inputQty = 0;
    _marketQuickMode = 'balance';
    _showQuickSlider = false;
    _quickSliderPct = 50;
  }

  void _fillFromBook(double price) {
    _orderbookState.setOrderType('limit');
    _priceController.text = price.toStringAsFixed(2).replaceAll('.', ',');
    _orderbookState.inputPrice = price;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 80), () {
      final ctx = _actionPanelKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  String _ticker(Startup s) => s.sigla;

  String _stateText(Startup s) =>
      s.lastPrice == null ? 'Preço de emissão' : 'Mercado ativo';

  // Retorna true quando qualquer lock-up impede a venda.
  // Ambos devem estar desbloqueados simultaneamente para vender.
  bool _isSellLocked(OrderbookState state, Startup startup) {
    // Lock-up por valor (global)
    bool valorUnlocked = true;
    if (startup.lockupQuantidadeTipo != null && startup.lockupQuantidadeValor > 0) {
      final vendidos = state.startupTokensVendidos;
      final int required = startup.lockupQuantidadeTipo == 'percentual'
          ? (startup.lockupQuantidadeValor * startup.tokensEmitidos).ceil()
          : startup.lockupQuantidadeValor.toInt();
      valorUnlocked = vendidos >= required;
    }

    // Lock-up por tempo: verifica datas reais de compra do investidor,
    // igual ao que o backend faz em validateLockupTempo.
    bool tempoUnlocked = true;
    if (startup.lockupDiasMinimo > 0) {
      if (_purchaseEntries.isEmpty) {
        tempoUnlocked = false;
      } else {
        final lockupMs = startup.lockupDiasMinimo * Duration.millisecondsPerDay;
        final now = DateTime.now().millisecondsSinceEpoch;
        final available = _purchaseEntries
            .where((e) => now >= e.acquiredAt.millisecondsSinceEpoch + lockupMs)
            .fold(0, (sum, e) => sum + e.qty);
        tempoUnlocked = available > 0;
      }
    }

    return !(valorUnlocked && tempoUnlocked);
  }

  @override
  void dispose() {
    _posicoesSub?.cancel();
    _cancelSubscriptions();
    _priceController.dispose();
    _qtyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStartups) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFFE040FB),
                      Color(0xFFFF6B6B),
                    ],
                  ),
                ),
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      );
    }

    return AnimatedBuilder(
      animation: _orderbookState,
      builder: (context, _) {
        final state = _orderbookState;
        final startup = state.currentStartup;
        final isPositive = startup.variation >= 0;

        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6C63FF),
                        Color(0xFFE040FB),
                        Color(0xFFFF6B6B),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(state, startup, isPositive),
                        const SizedBox(height: 14),
                        _buildStartupSelector(startup),
                        const SizedBox(height: 14),
                        _buildWalletCards(state, startup),
                        if (state.wallet.brl <= 0) ...[
                          const SizedBox(height: 12),
                          _buildEmptyWalletCta(),
                        ],
                        const SizedBox(height: 14),
                        _buildSpreadBar(state),
                        const SizedBox(height: 14),
                        _buildOrderBookGrid(state),
                        const SizedBox(height: 6),
                        _buildBookLegend(),
                        const SizedBox(height: 14),
                        _buildActionPanel(state, startup),
                        const SizedBox(height: 14),
                        _buildTradeHistory(state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 3),
        );
      },
    );
  }

  // ── HERO ───────────────────────────────────────────────────────────────────

  Widget _buildHero(OrderbookState state, Startup startup, bool isPositive) {
    final progress = state.startupSaleProgress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromARGB(255, 227, 227, 227)),
        
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balcão de Tokens',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _ink),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Negociação simulada em tempo real.',
                      style:
                          TextStyle(fontSize: 12, color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                            'Emissão', state.formatPrice(startup.precoEmissao)),
                        _buildChip('Vendido',
                            '${(progress * 100).toStringAsFixed(1)}%'),
                        _buildChip(
                            'Spread',
                            state.spread > 0
                                ? state.formatPrice(state.spread)
                                : '—'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    state.formatPrice(startup.displayPrice),
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: _ink),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPositive ? _buySoft : _sellSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      startup.variationText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? _buyColor : _sellColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Progresso da emissão',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
              ),
              const Spacer(),
              Text(
                '${state.formatQty(state.startupTokensVendidos)} / ${state.formatQty(startup.tokensEmitidos)}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDEEDE),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          ..._buildLockupInfo(state, startup),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: _muted, fontSize: 10),
          children: [
            TextSpan(text: '$label\n'),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLockupInfo(OrderbookState state, Startup startup) {
    final hasQtd = startup.lockupQuantidadeTipo != null &&
        startup.lockupQuantidadeValor > 0;
    final hasTempo = startup.lockupDiasMinimo > 0;

    if (!hasQtd && !hasTempo) return [];

    final widgets = <Widget>[
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(Icons.lock_outline, size: 13, color: _muted),
          const SizedBox(width: 4),
          const Text(
            'Lock-up',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
          ),
        ],
      ),
      const SizedBox(height: 8),
    ];

    if (hasQtd) {
      final vendidos = state.startupTokensVendidos;
      final int required;
      final String metaLabel;
      if (startup.lockupQuantidadeTipo == 'percentual') {
        required =
            (startup.lockupQuantidadeValor * startup.tokensEmitidos).ceil();
        final pct = (startup.lockupQuantidadeValor * 100).toStringAsFixed(0);
        metaLabel = 'meta: $pct% dos tokens emitidos';
      } else {
        required = startup.lockupQuantidadeValor.toInt();
        metaLabel =
            'meta: ${state.formatQty(required)} ${startup.sigla} vendidos';
      }
      final percorrido = vendidos.clamp(0, required);
      final falta = (required - percorrido).clamp(0, required);
      final progress =
          required > 0 ? (percorrido / required).clamp(0.0, 1.0) : 1.0;
      final unlocked = falta == 0;

      widgets.add(_buildLockupCard(
        icon: Icons.bar_chart_rounded,
        title: 'Por valor',
        subtitle: metaLabel,
        progress: progress,
        unlocked: unlocked,
        percorridoLabel: '${state.formatQty(percorrido)} ${startup.sigla} vendidos',
        faltaLabel: unlocked
            ? 'Desbloqueado'
            : 'Faltam ${state.formatQty(falta)} ${startup.sigla}',
      ));
    }

    if (hasTempo) {
      final lancamento = startup.dataLancamento;
      final totalDias = startup.lockupDiasMinimo;
      double? tempoProgress;
      bool tempoUnlocked = false;
      String percorridoTempoLabel;
      String faltaTempoLabel;

      if (lancamento != null) {
        final diasDecorridos =
            DateTime.now().difference(lancamento).inDays.clamp(0, totalDias);
        final diasFaltando = totalDias - diasDecorridos;
        tempoProgress = (diasDecorridos / totalDias).clamp(0.0, 1.0);
        tempoUnlocked = diasFaltando == 0;
        percorridoTempoLabel = '$diasDecorridos de $totalDias dias decorridos';
        faltaTempoLabel =
            tempoUnlocked ? 'Desbloqueado' : 'Faltam $diasFaltando dias';
      } else {
        percorridoTempoLabel = 'carência de $totalDias dias por compra';
        faltaTempoLabel = 'data de lançamento não definida';
      }

      widgets.add(_buildLockupCard(
        icon: Icons.schedule_rounded,
        title: 'Por tempo',
        subtitle: 'desde o lançamento da startup',
        progress: tempoProgress,
        unlocked: tempoUnlocked,
        percorridoLabel: percorridoTempoLabel,
        faltaLabel: faltaTempoLabel,
      ));
    }

    return widgets;
  }

  Widget _buildLockupCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double? progress,
    required bool unlocked,
    required String percorridoLabel,
    required String faltaLabel,
  }) {
    final accent =
        unlocked ? const Color(0xFF2E7D32) : const Color(0xFFB8860B);
    final bg =
        unlocked ? const Color(0xFFF0F7F3) : const Color(0xFFFFF8E1);
    final borderColor =
        unlocked ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082);
    final barColor =
        unlocked ? const Color(0xFF2E7D32) : const Color(0xFFFFB300);
    final textStrong =
        unlocked ? const Color(0xFF1B5E20) : const Color(0xFF7B5800);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 10, color: accent.withValues(alpha: 0.75)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  percorridoLabel,
                  style: TextStyle(fontSize: 10, color: accent.withValues(alpha: 0.8)),
                ),
              ),
              Text(
                faltaLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textStrong),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── STARTUP SELECTOR ───────────────────────────────────────────────────────

  Widget _buildStartupSelector(Startup startup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Startup',
          style: TextStyle(
              fontSize: 12, color: _muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _dropdownAberto ? _accent : _border),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _dropdownAberto = !_dropdownAberto),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      _TickerBadge(ticker: _ticker(startup), color: _accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              startup.nome,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_stateText(startup)}  ·  ${_orderbookState.formatQty(startup.tokensEmitidos)} ${_ticker(startup)}',
                              style:
                                  const TextStyle(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _dropdownAberto ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: _muted, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dropdownAberto)
                ...List.generate(_startups.length, (index) {
                  final item = _startups[index];
                  final selected = index == _startupSelecionada;
                  final positive = item.variation >= 0;
                  final qtdTokens = _posicoes[item.id] ?? 0;
                  return InkWell(
                    onTap: () => _changeStartup(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: const Border(top: BorderSide(color: _border)),
                        color:
                            selected ? const Color(0xFFF4F7FB) : Colors.white,
                      ),
                      child: Row(
                        children: [
                          _TickerBadge(
                            ticker: _ticker(item),
                            color: selected ? _accent : _muted,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nome,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? _accent : _ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_orderbookState.formatPrice(item.displayPrice)}  ·  ${item.variationText}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: positive ? _buyColor : _sellColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (qtdTokens > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8ECF8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_orderbookState.formatQty(qtdTokens)} ${_ticker(item)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: _accent, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ── WALLET CARDS ───────────────────────────────────────────────────────────

  Widget _buildWalletCards(OrderbookState state, Startup startup) {
    final ticker = _ticker(startup);
    final brlReservedHint = state.wallet.brlReserved > 0
        ? 'R\$ ${state.wallet.brlReserved.toStringAsFixed(2).replaceAll('.', ',')} em ordens'
        : null;
    return Row(
      children: [
        Expanded(
          child: _buildWalletCard(
            'Disponível',
            state.formatPrice(state.wallet.brlDisponivel),
            Icons.account_balance_wallet_outlined,
            _accent,
            subtitle: brlReservedHint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildWalletCard(
            'Em carteira',
            '${state.formatQty(state.wallet.tokens)} $ticker',
            Icons.token_outlined,
            _buyColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildWalletCard(
            'Reservado',
            '${state.formatQty(state.wallet.tokensReserved)} $ticker',
            Icons.lock_outline,
            _muted,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard(
    String label,
    String value,
    IconData icon,
    Color iconColor, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14, color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 9, color: _muted, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  // ── EMPTY WALLET CTA ───────────────────────────────────────────────────────

  static const double _creditoSimuladoValor = 50000;

  Widget _buildEmptyWalletCta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F7FB), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.savings_outlined, size: 18, color: _accent),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sem saldo de teste',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: _ink),
                ),
                SizedBox(height: 2),
                Text(
                  'Adicione crédito simulado para começar a negociar.',
                  style: TextStyle(fontSize: 11, color: _muted, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _submitting ? null : _handleAddSimulatedCredit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              '+ R\$ 50.000',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddSimulatedCredit() async {
    setState(() => _submitting = true);
    try {
      await AuthService().creditCurrentUserSaldo(_creditoSimuladoValor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crédito simulado adicionado!'),
          backgroundColor: _buyColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 2200),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── SPREAD BAR ─────────────────────────────────────────────────────────────

  Widget _buildSpreadBar(OrderbookState state) {
    final bestBid = state.bestBid?.price;
    final bestAsk = state.bestAsk?.price;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSpreadItem(
              'Melhor compra',
              bestBid == null ? '—' : state.formatPrice(bestBid),
              _buyColor,
              CrossAxisAlignment.start,
            ),
          ),
          GestureDetector(
            onTap: () => _showInfoDialog(
              context,
              'O que é spread?',
              'Spread é a diferença entre o menor preço de venda (ask) e o maior preço de compra (bid).\n\nQuanto menor o spread, mais líquido é o mercado — compradores e vendedores estão mais próximos de fechar negócio.',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SPREAD',
                        style: TextStyle(
                            fontSize: 9,
                            color: _muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.info_outline_rounded,
                          size: 10, color: _muted.withOpacity(0.7)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.spread > 0 ? state.formatPrice(state.spread) : '—',
                    style: const TextStyle(
                        fontSize: 12, color: _ink, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildSpreadItem(
              'Melhor venda',
              bestAsk == null ? '—' : state.formatPrice(bestAsk),
              _sellColor,
              CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadItem(
      String label, String value, Color color, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: _muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ── ORDER BOOK ─────────────────────────────────────────────────────────────

  Widget _buildOrderBookGrid(OrderbookState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildBookSide(state, 'buy')),
        const SizedBox(width: 8),
        Expanded(child: _buildBookSide(state, 'sell')),
      ],
    );
  }

  Widget _buildBookSide(OrderbookState state, String side) {
    final isBuy = side == 'buy';
    final orders = isBuy ? state.sortedBuyBook : state.sortedSellBook;
    final headerColor = isBuy ? _buySoft : _sellSoft;
    final headerTextColor = isBuy ? _buyColor : _sellColor;
    final maxQty = orders.isEmpty
        ? 1
        : orders.map((o) => o.qty).reduce((a, b) => a > b ? a : b);
    final totalVol = orders.fold(0, (sum, o) => sum + o.qty);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  isBuy
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 14,
                  color: headerTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isBuy ? 'COMPRA' : 'VENDA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: headerTextColor),
                ),
                const Spacer(),
                Text(
                  '${orders.length} ordens',
                  style: TextStyle(
                      fontSize: 10, color: headerTextColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Preço',
                    style: TextStyle(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Qtd',
                  style: TextStyle(
                      fontSize: 10, color: _muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0EA)),
          if (orders.isEmpty)
            _buildEmptyBookSide(isBuy)
          else
            ...orders.take(8).map(
                (order) => _buildOrderRow(state, order, side, isBuy, maxQty)),
          if (orders.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF0F0EA)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Vol. total',
                    style: const TextStyle(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    state.formatQty(totalVol),
                    style: TextStyle(
                      fontSize: 10,
                      color: headerTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyBookSide(bool isBuy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Icon(
            isBuy ? Icons.shopping_cart_outlined : Icons.sell_outlined,
            size: 28,
            color: const Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 8),
          Text(
            'Sem ordens de\n${isBuy ? 'compra' : 'venda'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFFB9B9B9), height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            isBuy
                ? 'Seja o primeiro a ofertar.'
                : 'Coloque uma ordem de venda.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFFCCCCCC)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
    OrderbookState state,
    Order order,
    String side,
    bool isBuy,
    int maxQty,
  ) {
    final isMine = state.myOrderIds.contains(order.id);
    final priceColor = isBuy ? _buyColor : _sellColor;
    final depthColor =
        isBuy ? _buyColor.withOpacity(0.09) : _sellColor.withOpacity(0.09);
    final depthFraction = (order.qty / maxQty).clamp(0.0, 1.0);
    final stopA = (depthFraction - 0.001).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _fillFromBook(order.price),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [stopA, depthFraction],
                  colors: [depthColor, Colors.transparent],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isMine ? _mine.withOpacity(0.7) : Colors.transparent,
              border: const Border(top: BorderSide(color: Color(0xFFF0F0EA))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.formatPrice(order.price),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: priceColor,
                        ),
                      ),
                      if (order.isStartup)
                        const Text('primária',
                            style: TextStyle(fontSize: 9, color: _muted))
                      else if (isMine)
                        const Text(
                          'sua ordem',
                          style: TextStyle(
                              fontSize: 9,
                              color: _accent,
                              fontWeight: FontWeight.w600),
                        )
                      else if (order.isPartiallyExecuted)
                        const Text('parcial',
                            style: TextStyle(fontSize: 9, color: _muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      state.formatQty(order.qty),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _muted),
                    ),
                    if (isMine)
                      GestureDetector(
                        onTap: () => _handleCancelOrder(order.id),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            'cancelar',
                            style: TextStyle(
                                fontSize: 9,
                                color: _sellColor,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _buildLegendItem(_mine, 'Suas ordens'),
          _buildLegendItem(_buyColor.withOpacity(0.15), 'Volume de compra'),
          _buildLegendItem(_sellColor.withOpacity(0.15), 'Volume de venda'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined, size: 11, color: _muted),
              const SizedBox(width: 4),
              const Text(
                'Toque em um preço para usá-lo',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _border, width: 0.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    );
  }

  // ── ACTION PANEL ───────────────────────────────────────────────────────────

  Widget _buildActionPanel(OrderbookState state, Startup startup) {
    final isBuy = state.currentTab == 'buy';
    final isMarket = state.orderType == 'market';
    final isSellLocked = !isBuy && _isSellLocked(state, startup);
    final actionColor = isBuy ? _buyColor : _sellColor;
    final actionSoft = isBuy ? _buySoft : _sellSoft;
    final ticker = _ticker(startup);

    final estimatedTotal = isMarket
        ? state.estimateMarketTotal(state.currentTab, state.inputQty)
        : (state.inputQty > 0 && state.inputPrice > 0
            ? state.inputQty * state.inputPrice
            : null);
    final averagePrice = isMarket
        ? state.estimateAverageMarketPrice(state.currentTab, state.inputQty)
        : state.inputPrice > 0
            ? state.inputPrice
            : null;

    // balance usage for buy: cost / available_brl (líquido — descontado o reservado)
    final brlDisponivel = state.wallet.brlDisponivel;
    final balanceUsageFraction = isBuy
        ? (estimatedTotal != null && brlDisponivel > 0
            ? estimatedTotal / brlDisponivel
            : 0.0)
        : (state.inputQty > 0 && state.wallet.tokens > 0
            ? state.inputQty / state.wallet.tokens
            : 0.0);
    final isOverBudget = isBuy
        ? (estimatedTotal != null && estimatedTotal > brlDisponivel)
        : (state.inputQty > state.wallet.tokens);

    return Container(
      key: _actionPanelKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buy / Sell tabs
          Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  'Comprar',
                  state.currentTab == 'buy',
                  _buySoft,
                  _buyColor,
                  () => state.setTab('buy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTabButton(
                  'Vender',
                  state.currentTab == 'sell',
                  _sellSoft,
                  _sellColor,
                  () => state.setTab('sell'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Order type
          _buildSectionLabel('Tipo de ordem'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildOrderTypeButton(
                  'Market',
                  'imediata',
                  Icons.bolt_rounded,
                  state.orderType == 'market',
                  () => state.setOrderType('market'),
                  infoLabel: 'O que é Market?',
                  infoText:
                      'Uma Market Order executa imediatamente ao melhor preço disponível no book.\n\nVocê não define o preço — o sistema consome as melhores ofertas até completar sua quantidade.',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOrderTypeButton(
                  'Limit',
                  'no book',
                  Icons.price_check_rounded,
                  state.orderType == 'limit',
                  () => state.setOrderType('limit'),
                  infoLabel: 'O que é Limit?',
                  infoText:
                      'Uma Limit Order entra no livro de ordens com o preço que você definir.\n\nSua ordem fica aguardando até que alguém aceite negociar pelo seu preço — ou você cancela.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hint card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: actionSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isMarket
                  ? 'Executa imediatamente contra as melhores ofertas do book.'
                  : 'Entra no livro e aguarda uma contraparte aceitar seu preço.',
              style: TextStyle(fontSize: 11, color: actionColor, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          // Price field (limit only)
          if (!isMarket) ...[
            _buildSectionLabel('Preço por token (R\$)'),
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              onChanged: (v) => setState(() {
                state.inputPrice = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              }),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDec(hint: 'Ex: 2,50'),
            ),
            const SizedBox(height: 14),
          ],
          // Quantity field
          _buildSectionLabel('Quantidade de tokens'),
          const SizedBox(height: 6),
          TextField(
            controller: _qtyController,
            onChanged: (v) => setState(() {
              state.inputQty = int.tryParse(v) ?? 0;
            }),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDec(hint: 'Ex: 100'),
          ),
          const SizedBox(height: 8),
          // Quick fill
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Rápido:',
                  style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600)),
              _buildPercentChip(actionColor, actionSoft, state, isBuy),
              if (isMarket) ...[
                _buildQuickModeButton(
                  'Saldo',
                  selected: _marketQuickMode == 'balance',
                  color: actionColor,
                  onTap: () {
                    setState(() => _marketQuickMode = 'balance');
                    _applyQuickFill(_quickSliderPct, state, isBuy);
                  },
                ),
                _buildQuickModeButton(
                  'Tokens',
                  selected: _marketQuickMode == 'tokens',
                  color: actionColor,
                  onTap: () {
                    setState(() => _marketQuickMode = 'tokens');
                    _applyQuickFill(_quickSliderPct, state, isBuy);
                  },
                ),
              ],
              ...[25, 50, 75, 100].map(
                (pct) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildQuickFillButton('$pct%', pct, state, isBuy),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _applyMaxFill(state, isBuy),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border, width: 1.5),
                    ),
                    child: const Text(
                      'Máx',
                      style: TextStyle(
                          fontSize: 11,
                          color: _ink,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isMarket) ...[
            const SizedBox(height: 6),
            Text(
              _marketQuickMode == 'balance'
                  ? (isBuy
                      ? 'Percentual sobre seu saldo em reais.'
                      : 'Percentual do saldo em reais convertido pela liquidez do book comprador.')
                  : (isBuy
                      ? 'Percentual dos tokens disponíveis no book de venda.'
                      : 'Percentual dos seus tokens livres para venda.'),
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
          const SizedBox(height: 12),
          // Botões de incremento de tokens
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Incrementar:',
                  style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600)),
              for (final increment in [1, 10, 100, 1000, 10000, 100000])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _incrementQuantity(increment, state, isBuy),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        '+$increment',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _ink,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Botões de decremento de tokens
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Decrementar:',
                  style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600)),
              for (final decrement in [1, 10, 100, 1000, 10000, 100000])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _decrementQuantity(decrement, state, isBuy),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        '-$decrement',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _ink,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_showQuickSlider
                ? const SizedBox(width: double.infinity, height: 0)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 12, color: actionColor),
                            const SizedBox(width: 6),
                            Text(
                              'Ajuste fino',
                              style: TextStyle(
                                fontSize: 11,
                                color: actionColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_quickSliderPct.round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: actionColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: actionColor,
                            inactiveTrackColor: actionSoft,
                            thumbColor: actionColor,
                            overlayColor: actionColor.withOpacity(0.12),
                            trackHeight: 4,
                            thumbShape: const _GrowingThumbShape(
                              minRadius: 6,
                              maxRadius: 14,
                            ),
                            showValueIndicator: ShowValueIndicator.never,
                          ),
                          child: Slider(
                            value: _quickSliderPct.clamp(1.0, 100.0),
                            min: 1,
                            max: 100,
                            divisions: 99,
                            onChanged: (value) {
                              setState(() => _quickSliderPct = value);
                              _applyQuickFill(_quickSliderPct, state, isBuy);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Contextual balance hint
          _buildBalanceHint(state, isBuy, ticker),
          const SizedBox(height: 12),
          // Balance usage bar
          if (state.inputQty > 0 && (estimatedTotal != null || !isBuy)) ...[
            _buildBalanceBar(balanceUsageFraction, isOverBudget, isBuy, state),
            const SizedBox(height: 14),
          ],
          // Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isOverBudget ? _sellColor.withOpacity(0.4) : _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Resumo da ordem',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _ink),
                    ),
                    if (isOverBudget) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _sellSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Saldo insuficiente',
                          style: TextStyle(
                              fontSize: 9,
                              color: _sellColor,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _buildSummaryLine('Tipo',
                    isMarket ? 'Market (imediata)' : 'Limit (aguardar book)'),
                _buildSummaryLine(
                  'Quantidade',
                  state.inputQty > 0
                      ? '${state.formatQty(state.inputQty)} $ticker'
                      : '—',
                ),
                _buildSummaryLine(
                  'Preço médio',
                  averagePrice != null && averagePrice > 0
                      ? state.formatPrice(averagePrice)
                      : '—',
                ),
                _buildSummaryLine(
                  isBuy ? 'Custo total' : 'Recebimento',
                  estimatedTotal != null && estimatedTotal > 0
                      ? state.formatPrice(estimatedTotal)
                      : '—',
                  highlight: estimatedTotal != null && estimatedTotal > 0,
                  alertColor: isOverBudget,
                ),
                if (isMarket && estimatedTotal != null && estimatedTotal > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '* Valor estimado com base no livro atual. O preço final pode variar.',
                      style: TextStyle(fontSize: 9, color: _muted, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_submitting ||
                      isOverBudget ||
                      isSellLocked ||
                      state.currentStartup.id.isEmpty)
                  ? null
                  : () => _handleSubmitOrder(state, isBuy),
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: (isOverBudget || isSellLocked)
                    ? _sellColor.withOpacity(0.3)
                    : actionColor.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isOverBudget
                          ? 'Saldo insuficiente'
                          : (isSellLocked
                              ? 'Venda bloqueada — lock-up ativo'
                              : (isBuy ? 'Comprar tokens' : 'Vender tokens')),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHint(OrderbookState state, bool isBuy, String ticker) {
    if (isBuy) {
      return Row(
        children: [
          const Icon(Icons.info_outline, size: 12, color: _muted),
          const SizedBox(width: 5),
          Text(
            'Disponível: ${state.formatPrice(state.wallet.brlDisponivel)}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 12, color: _muted),
        const SizedBox(width: 5),
        Text(
          'Disponível: ${state.formatQty(state.wallet.tokens)} $ticker livres',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  Widget _buildBalanceBar(
      double fraction, bool isOver, bool isBuy, OrderbookState state) {
    final barColor = isOver ? _sellColor : (isBuy ? _buyColor : _sellColor);
    final pctText =
        '${(fraction * 100).toStringAsFixed(0)}% do ${isBuy ? 'saldo' : 'portfólio'}';
    final overflowPct = ((fraction - 1.0) * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Uso do ${isBuy ? 'saldo' : 'portfólio'}',
              style: const TextStyle(
                  fontSize: 10, color: _muted, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              pctText,
              style: TextStyle(
                fontSize: 10,
                color: isOver ? _sellColor : _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFEDEEDE),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        if (isOver) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.arrow_upward_rounded,
                  size: 10, color: _sellColor),
              const SizedBox(width: 3),
              Text(
                '+$overflowPct% além do ${isBuy ? 'saldo disponível' : 'portfólio disponível'}',
                style: const TextStyle(
                  fontSize: 10,
                  color: _sellColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuickFillButton(
      String label, int pct, OrderbookState state, bool isBuy) {
    return GestureDetector(
      onTap: () => _applyQuickFill(pct.toDouble(), state, isBuy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 11, color: _ink, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _applyQuickFill(double pct, OrderbookState state, bool isBuy) {
    int qty;
    final brlDisponivel = state.wallet.brlDisponivel;
    if (state.orderType == 'market') {
      if (_marketQuickMode == 'balance') {
        final amount = brlDisponivel * pct / 100;
        qty = state.estimateMarketQtyForValue(state.currentTab, amount);
      } else {
        final tokenBase = isBuy
            ? state.availableMarketQty(state.currentTab)
            : state.wallet.tokens;
        qty = (tokenBase * pct / 100).floor();
      }
    } else if (isBuy) {
      final price = state.inputPrice > 0
          ? state.inputPrice
          : state.currentStartup.precoEmissao;
      qty = price > 0 ? ((brlDisponivel * pct / 100) / price).floor() : 0;
    } else {
      qty = (state.wallet.tokens * pct / 100).floor();
    }

    _qtyController.text = qty > 0 ? qty.toString() : '';
    setState(() {
      _quickSliderPct = pct;
      state.inputQty = qty;
    });
  }

  void _applyMaxFill(OrderbookState state, bool isBuy) {
    int qty;
    final brlDisponivel = state.wallet.brlDisponivel;

    if (isBuy) {
      // Para compra: usar 100% do saldo disponível
      if (state.orderType == 'market') {
        qty = state.estimateMarketQtyForValue(state.currentTab, brlDisponivel);
      } else {
        // Limit order: saldo disponível / preço da ordem
        final price = state.inputPrice > 0
            ? state.inputPrice
            : state.currentStartup.precoEmissao;
        qty = price > 0 ? (brlDisponivel / price).floor() : 0;
      }
    } else {
      // Para venda: usar todos os tokens disponíveis
      qty = state.wallet.tokens;
    }

    _qtyController.text = qty > 0 ? qty.toString() : '';
    setState(() {
      _quickSliderPct = 100.0;
      state.inputQty = qty;
    });
  }

  void _incrementQuantity(int increment, OrderbookState state, bool isBuy) {
    int currentQty = int.tryParse(_qtyController.text) ?? 0;
    final brlDisponivel = state.wallet.brlDisponivel;
    int newQty = currentQty + increment;

    // Validar limite máximo
    if (isBuy) {
      int maxQty;
      if (state.orderType == 'market') {
        maxQty =
            state.estimateMarketQtyForValue(state.currentTab, brlDisponivel);
      } else {
        final price = state.inputPrice > 0
            ? state.inputPrice
            : state.currentStartup.precoEmissao;
        maxQty = price > 0 ? (brlDisponivel / price).floor() : 0;
      }
      newQty = newQty.clamp(0, maxQty);
    } else {
      newQty = newQty.clamp(0, state.wallet.tokens);
    }

    _qtyController.text = newQty > 0 ? newQty.toString() : '';
    setState(() {
      state.inputQty = newQty;
    });
  }

  void _decrementQuantity(int decrement, OrderbookState state, bool isBuy) {
    int currentQty = int.tryParse(_qtyController.text) ?? 0;
    int newQty = (currentQty - decrement).clamp(0, double.infinity).toInt();

    _qtyController.text = newQty > 0 ? newQty.toString() : '';
    setState(() {
      state.inputQty = newQty;
    });
  }

  Widget _buildPercentChip(
    Color color,
    Color soft,
    OrderbookState state,
    bool isBuy,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _showQuickSlider = !_showQuickSlider),
      onLongPress: () => _showPercentInputDialog(state, isBuy, color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _showQuickSlider ? soft : _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _showQuickSlider ? color.withOpacity(0.4) : _border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 12,
              color: _showQuickSlider ? color : _muted,
            ),
            const SizedBox(width: 4),
            Text(
              _quickSliderPct % 1 == 0
                  ? '${_quickSliderPct.round()}%'
                  : '${_quickSliderPct.toStringAsFixed(2).replaceAll('.', ',')}%',
              style: TextStyle(
                fontSize: 11,
                color: _showQuickSlider ? color : _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickModeButton(
    String label, {
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : _card,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: selected ? color.withOpacity(0.35) : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? color : _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12, color: _muted, fontWeight: FontWeight.w700));
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool highlight = false,
    bool alertColor = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: alertColor ? _sellColor : (highlight ? _accent : _ink),
              fontWeight:
                  (highlight || alertColor) ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    bool isActive,
    Color background,
    Color foreground,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? background : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? foreground : _border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isActive ? foreground : _muted,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypeButton(
    String label,
    String caption,
    IconData icon,
    bool isActive,
    VoidCallback onTap, {
    required String infoLabel,
    required String infoText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF6F6F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? _ink : _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isActive ? _ink : _muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive ? _ink : _muted,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '· $caption',
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showInfoDialog(context, infoLabel, infoText),
              child: Icon(Icons.help_outline_rounded,
                  size: 13, color: _muted.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ── TRADE HISTORY ──────────────────────────────────────────────────────────

  Widget _buildTradeHistory(OrderbookState state) {
    final trades = state.trades;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Histórico de trades',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _ink),
                ),
                const Spacer(),
                if (trades.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${trades.length} trade${trades.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (trades.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: _card,
              child: Row(
                children: const [
                  Expanded(
                      child: Text('Horário',
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      child: Text('Tipo',
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      child: Text('Preço',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      child: Text('Qtd',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            ...trades.asMap().entries.map((entry) {
              final index = entry.key;
              final trade = entry.value;
              final isBuy = trade.side == 'compra';
              final sideColor = isBuy ? _buyColor : _sellColor;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      index == 0 ? const Color(0xFFEDF3FD) : Colors.transparent,
                  border:
                      const Border(top: BorderSide(color: Color(0xFFF0F0EA))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trade.time,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: sideColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            isBuy ? 'Compra' : 'Venda',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sideColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        state.formatPrice(trade.price),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            color: _ink,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${state.formatQty(trade.qty)} ${_ticker(state.currentStartup)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: const [
                  Icon(Icons.swap_horiz_rounded,
                      size: 32, color: Color(0xFFCCCCCC)),
                  SizedBox(height: 10),
                  Text(
                    'Nenhuma trade executada ainda',
                    style: TextStyle(fontSize: 13, color: Color(0xFFB9B9B9)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Execute uma Market ou Limit order para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── ORDER ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _handleSubmitOrder(OrderbookState state, bool isBuy) async {
    final qty = state.inputQty;
    final price = state.orderType == 'limit' ? state.inputPrice : null;
    final startupId = state.currentStartup.id;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida.')),
      );
      return;
    }
    if (state.orderType == 'limit' && (price == null || price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um preço válido para limite.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final result = await _service.createOrder(
      startupId: startupId,
      side: isBuy ? 'buy' : 'sell',
      orderType: state.orderType,
      qty: qty,
      price: price,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      _clearInputs();
      final msg = result.tradesExecuted > 0
          ? '${isBuy ? 'Compra' : 'Venda'} executada — ${result.tradesExecuted} trade(s)!'
          : (isBuy ? 'Ordem de compra enviada' : 'Ordem de venda enviada');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isBuy ? _buyColor : _sellColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2500),
        ),
      );
    } else {
      _showErrorDialog(result.errorMessage ?? 'Erro ao processar ordem.');
    }
  }

  Future<void> _handleCancelOrder(String orderId) async {
    final startupId = _orderbookState.currentStartup.id;
    final result = await _service.cancelOrder(
      startupId: startupId,
      orderId: orderId,
    );
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem cancelada'),
          duration: Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showErrorDialog(
          result.errorMessage ?? 'Não foi possível cancelar a ordem.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Atenção',
          style:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
        ),
        content: Text(message,
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.55)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK',
                style: TextStyle(fontWeight: FontWeight.w700, color: _accent)),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  void _showPercentInputDialog(
      OrderbookState state, bool isBuy, Color actionColor) {
    // buffer stores percentage × 100 (fixed-point 2 decimals)
    // e.g. 12,61% → 1261; right-to-left calculator entry
    int buffer = (_quickSliderPct * 100).round();
    bool replaceOnNext = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final whole = buffer ~/ 100;
            final frac = (buffer % 100).toString().padLeft(2, '0');
            final displayStr = '$whole,$frac';
            final overLimit = buffer > 10000; // > 100,00%
            final displayColor = overLimit ? _sellColor : _ink;

            void press(String key) {
              setLocal(() {
                if (key == 'C') {
                  buffer = 0;
                  replaceOnNext = true;
                } else if (key == '<') {
                  buffer = buffer ~/ 10;
                } else {
                  final digit = int.parse(key);
                  if (replaceOnNext) {
                    buffer = digit;
                    replaceOnNext = false;
                  } else if (buffer < 100000) {
                    buffer = buffer * 10 + digit;
                  }
                }
              });
            }

            void apply() {
              final raw = buffer / 100.0;
              final clamped = raw.clamp(0.01, 100.0);
              setState(() => _quickSliderPct = clamped);
              _applyQuickFill(clamped, state, isBuy);
              Navigator.pop(ctx);
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: actionColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Definir porcentagem',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close_rounded,
                              size: 20, color: _muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Valor entre 0,01 e 100,00.',
                      style:
                          TextStyle(fontSize: 11, color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              overLimit ? _sellColor.withValues(alpha: 0.6) : _border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            displayStr,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: displayColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: overLimit ? _sellColor : actionColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (overLimit) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Icon(Icons.error_outline_rounded,
                              size: 12, color: _sellColor),
                          SizedBox(width: 4),
                          Text(
                            'Máximo é 100% — será limitado',
                            style: TextStyle(
                              fontSize: 10,
                              color: _sellColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildKeypadRow(const ['1', '2', '3'], press, actionColor),
                    const SizedBox(height: 8),
                    _buildKeypadRow(const ['4', '5', '6'], press, actionColor),
                    const SizedBox(height: 8),
                    _buildKeypadRow(const ['7', '8', '9'], press, actionColor),
                    const SizedBox(height: 8),
                    _buildKeypadRow(const ['C', '0', '<'], press, actionColor),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (buffer == 0 || overLimit) ? null : apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              actionColor.withOpacity(0.35),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Aplicar',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKeypadRow(
    List<String> keys,
    void Function(String key) onPress,
    Color actionColor,
  ) {
    return Row(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildKeypadKey(keys[i], onPress, actionColor)),
        ],
      ],
    );
  }

  Widget _buildKeypadKey(
    String label,
    void Function(String key) onPress,
    Color actionColor,
  ) {
    final isClear = label == 'C';
    final isBack = label == '<';

    final Color fg = isClear ? _sellColor : (isBack ? _muted : _ink);

    Widget content;
    if (isBack) {
      content = const Icon(Icons.backspace_outlined, size: 18, color: _muted);
    } else {
      content = Text(
        label,
        style: TextStyle(
          fontSize: isClear ? 16 : 22,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      );
    }

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: actionColor.withOpacity(0.14),
        highlightColor: actionColor.withOpacity(0.06),
        onTap: () => onPress(label),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: content,
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
        content: Text(body,
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.55)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi',
                style: TextStyle(fontWeight: FontWeight.w700, color: _accent)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

// ── TICKER BADGE ────────────────────────────────────────────────────────────

class _GrowingThumbShape extends SliderComponentShape {
  final double minRadius;
  final double maxRadius;

  const _GrowingThumbShape({this.minRadius = 6, this.maxRadius = 14});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(maxRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final safeValue = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final radius = minRadius + (maxRadius - minRadius) * safeValue;
    final thumbColor = sliderTheme.thumbColor ?? const Color(0xFF173B7A);

    // Soft drop-shadow using two translucent layered discs (web-safe; no MaskFilter)
    canvas.drawCircle(
      center.translate(0, 2.0),
      radius + 1.5,
      Paint()..color = Colors.black.withOpacity(0.08),
    );
    canvas.drawCircle(
      center.translate(0, 1.2),
      radius + 0.5,
      Paint()..color = Colors.black.withOpacity(0.12),
    );

    // Main thumb
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = thumbColor,
    );

    // Inner highlight
    canvas.drawCircle(
      center.translate(-radius * 0.28, -radius * 0.28),
      radius * 0.32,
      Paint()..color = Colors.white.withOpacity(0.28),
    );
  }
}

class _TickerBadge extends StatelessWidget {
  final String ticker;
  final Color color;
  final double size;

  const _TickerBadge(
      {required this.ticker, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final label = ticker.substring(0, ticker.length.clamp(0, 3));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: size * 0.28,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
