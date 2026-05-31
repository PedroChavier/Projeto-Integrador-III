//Giovana Uchelli - 25008818
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/orderbook_models.dart';
import '../../models/wallet_holding.dart';
import '../../models/wallet_transaction.dart';
import '../../services/auth_service.dart';
import '../../services/balcao_service.dart';
import '../balcao/balcao_screen.dart';
import '../home/home_screen.dart';
import 'deposit_screen.dart';

// Tela da carteira — exibe saldo, tokens, ordens e histórico de transações
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final AuthService _authService = AuthService();
  final BalcaoService _balcaoService = BalcaoService();

  // Streams em tempo real via Firestore
  late final Stream<Wallet> _walletStream;
  late Stream<List<WalletHolding>> _holdingsStream;
  late final Stream<List<OrderHistoryEntry>> _orderHistoryStream;

  // Histórico de transações carregado uma única vez (não é stream)
  Future<List<WalletTransaction>>? _transacoesFuture;

  // Formatadores de moeda e data
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM HH:mm', 'pt_BR');

  // Controla quais seções estão expandidas
  bool _holdingsExpanded = true;
  bool _ordersExpanded = false;
  bool _transacoesExpanded = false;

  @override
  void initState() {
    super.initState();
    _walletStream = _balcaoService.watchWallet();
    _holdingsStream = _balcaoService.watchHoldings();
    _orderHistoryStream = _balcaoService.watchOrderHistory();
    _carregarHistorico();
  }

  // Carrega o histórico de transações do usuário logado
  void _carregarHistorico() {
    _transacoesFuture = _authService.getCurrentUserTransactions();
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder externo: escuta o saldo da carteira em tempo real
    return StreamBuilder<Wallet>(
      stream: _walletStream,
      builder: (context, walletSnapshot) {
        final saldo = walletSnapshot.data?.brl ?? 0;

        // StreamBuilder interno: escuta os tokens (holdings) em tempo real
        return StreamBuilder<List<WalletHolding>>(
          stream: _holdingsStream,
          builder: (context, holdingsSnapshot) {

            // Exibe tela de erro se os holdings falharem ao carregar
            if (holdingsSnapshot.hasError) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Erro ao carregar carteira',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        // Recria o stream para tentar novamente
                        onPressed: () => setState(() {
                          _holdingsStream = _balcaoService.watchHoldings();
                        }),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: const AppBottomNav(currentIndex: 2),
              );
            }

            final holdings = holdingsSnapshot.data ?? const <WalletHolding>[];

            return Scaffold(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              body: Column(
                children: [
                  const SizedBox(height: 20),
                  // Barra decorativa com gradiente no topo
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Carteira',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Card de saldo disponível com gradiente
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF9A1C63), Color(0xFF1A237E)],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Saldo Disponível',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currencyFormat.format(saldo),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botão para ir à tela de depósito simulado
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => AdicionarSaldoScreen(
                                      saldoAtual: saldo,
                                      telaRetorno: const WalletScreen(),
                                    ),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );
                                // Recarrega o histórico ao voltar do depósito
                                if (!mounted) return;
                                setState(_carregarHistorico);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color.fromARGB(79, 0, 0, 0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Adicionar saldo simulado',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Atalho para o Balcão de negociações
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => const BalcaoScreen(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(194, 240, 240, 240),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.swap_horiz_outlined,
                                    color: Color.fromARGB(255, 112, 121, 133),
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Comprar ou vender tokens?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Ir para Balcão',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6C63FF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black45),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Seção colapsável: tokens na carteira (só aparece se houver)
                          if (holdings.isNotEmpty) ...[
                            _CollapsibleSection(
                              title: 'Tokens na Carteira',
                              count: holdings.length,
                              collapsedSummary: _holdingsSummary(holdings),
                              expanded: _holdingsExpanded,
                              onToggle: () => setState(() => _holdingsExpanded = !_holdingsExpanded),
                              child: Column(
                                children: holdings
                                    .map(
                                      (holding) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _HoldingCard(
                                          holding: holding,
                                          currencyFormat: _currencyFormat,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Seção colapsável: histórico de ordens (stream em tempo real)
                          StreamBuilder<List<OrderHistoryEntry>>(
                            stream: _orderHistoryStream,
                            builder: (context, orderSnap) {
                              final orders = orderSnap.data ?? const <OrderHistoryEntry>[];
                              if (orders.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CollapsibleSection(
                                    title: 'Histórico de Ordens',
                                    count: orders.length,
                                    collapsedSummary: _ordersSummary(orders),
                                    expanded: _ordersExpanded,
                                    onToggle: () => setState(() => _ordersExpanded = !_ordersExpanded),
                                    child: Column(
                                      children: orders
                                          .map(
                                            (order) => Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: _OrderHistoryCard(
                                                order: order,
                                                currencyFormat: _currencyFormat,
                                                dateFormat: _dateFormat,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),

                          // Seção colapsável: histórico de transações (carregado uma vez)
                          FutureBuilder<List<WalletTransaction>>(
                            future: _transacoesFuture,
                            builder: (context, transacoesSnapshot) {
                              final hasError = transacoesSnapshot.hasError;
                              final isLoading = transacoesSnapshot.connectionState == ConnectionState.waiting;
                              final transacoes = transacoesSnapshot.data ?? const <WalletTransaction>[];

                              Widget body;
                              if (hasError) {
                                body = Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Nao foi possivel carregar o historico: ${transacoesSnapshot.error}',
                                    style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                                  ),
                                );
                              } else if (isLoading) {
                                body = const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              } else if (transacoes.isEmpty) {
                                body = const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Nenhuma movimentacao registrada ainda.',
                                    style: TextStyle(fontSize: 13, color: Colors.black45),
                                  ),
                                );
                              } else {
                                // Lista de transações com divisores entre cada item
                                body = Column(
                                  children: [
                                    ...transacoes.map(
                                      (transacao) => Column(
                                        children: [
                                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                          _TransacaoItem(
                                            titulo: transacao.titulo,
                                            subtitulo: transacao.subtitulo,
                                            valor: _formatValorTransacao(
                                              transacao.valor,
                                              transacao.positivo,
                                            ),
                                            positivo: transacao.positivo,
                                            direcaoLabel: transacao.positivo
                                                ? 'Entrada de capital'
                                                : 'Saida de capital',
                                            fonte: transacao.fonte,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                  ],
                                );
                              }

                              return _CollapsibleSection(
                                title: 'Histórico de Transações',
                                count: transacoes.length,
                                collapsedSummary: _transacoesSummary(transacoes),
                                expanded: _transacoesExpanded,
                                onToggle: () => setState(() => _transacoesExpanded = !_transacoesExpanded),
                                child: body,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: const AppBottomNav(currentIndex: 2),
            );
          },
        );
      },
    );
  }

  // Formata o valor com prefixo "+" ou "-"
  String _formatValorTransacao(double valor, bool positivo) {
    final prefixo = positivo ? '+ ' : '- ';
    return '$prefixo${_currencyFormat.format(valor)}';
  }

  // Resumo colapsado dos tokens: total investido
  String _holdingsSummary(List<WalletHolding> holdings) {
    final total = holdings.fold<double>(0, (sum, h) => sum + h.valorInvestido);
    return 'Total captado · ${_currencyFormat.format(total)}';
  }

  // Resumo colapsado das ordens: quantas em aberto e executadas
  String _ordersSummary(List<OrderHistoryEntry> orders) {
    var abertas = 0;
    var executadas = 0;
    for (final o in orders) {
      if (o.status == 'aberta' || o.status == 'parcialmente_executada') abertas++;
      else if (o.status == 'executada') executadas++;
    }
    final parts = <String>[];
    if (abertas > 0) parts.add('$abertas em aberto');
    if (executadas > 0) parts.add('$executadas executadas');
    if (parts.isEmpty) return '${orders.length} ${orders.length == 1 ? 'ordem' : 'ordens'}';
    return parts.join(' · ');
  }

  // Resumo colapsado das transações: saldo líquido (entradas - saídas)
  String _transacoesSummary(List<WalletTransaction> txs) {
    if (txs.isEmpty) return 'Sem movimentações';
    var net = 0.0;
    for (final t in txs) {
      net += t.positivo ? t.valor : -t.valor;
    }
    final sign = net >= 0 ? '+' : '−';
    return 'Saldo bruto · $sign${_currencyFormat.format(net.abs())}';
  }
}

// Seção com cabeçalho clicável que expande/colapsa o conteúdo com animação
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.collapsedSummary,
  });

  final String title;
  final int count;           // Exibido como badge no cabeçalho
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final String? collapsedSummary; // Texto resumido quando recolhido

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  // Badge com contagem de itens
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFE040FB)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Seta que gira 180° ao expandir
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Animação de transição entre resumo (recolhido) e conteúdo (expandido)
        AnimatedCrossFade(
          firstChild: SizedBox(
            width: double.infinity,
            child: collapsedSummary == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      collapsedSummary!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(width: double.infinity, child: child),
          ),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 260),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
        ),
      ],
    );
  }
}

// Badge de variação percentual: verde se positivo, vermelho se negativo
class _VariacaoBadge extends StatelessWidget {
  const _VariacaoBadge({required this.pct});

  final double pct;

  @override
  Widget build(BuildContext context) {
    final isPositive = pct > 0;
    final isNegative = pct < 0;
    final color = isPositive
        ? const Color(0xFF2E7D32)
        : isNegative
            ? const Color(0xFFE53935)
            : Colors.black45;
    final sign = isPositive ? '+' : '';
    final text = '$sign${pct.toStringAsFixed(2).replaceAll('.', ',')}%';
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    );
  }
}

// Card de um token na carteira: nome, quantidade e valor investido
class _HoldingCard extends StatelessWidget {
  const _HoldingCard({required this.holding, required this.currencyFormat});

  final WalletHolding holding;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final nome = holding.startupNome.isNotEmpty ? holding.startupNome : holding.startupUid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBEBF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (holding.startupSetor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          holding.startupSetor,
                          style: const TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Quantidade total de tokens
                  Text(
                    '${holding.quantidadeTotal} ${holding.startupSigla}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  // Tokens reservados em ordens abertas (só aparece se houver)
                  if (holding.quantidadeReservada > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${holding.quantidadeReservada} ${holding.startupSigla} em ordens',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Linha: valor total investido
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Valor captado', style: TextStyle(fontSize: 12, color: Colors.black45)),
              Text(
                currencyFormat.format(holding.valorInvestido),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Linha: preço médio e variação em relação ao preço de emissão
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Preço atual', style: TextStyle(fontSize: 12, color: Colors.black45)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currencyFormat.format(holding.precoMedio),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (holding.precoEmissao > 0) ...[
                    const SizedBox(width: 6),
                    _VariacaoBadge(pct: holding.variacaoEmissao),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Card de uma ordem no histórico: startup, tipo, status e valor
class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({
    required this.order,
    required this.currencyFormat,
    required this.dateFormat,
  });

  final OrderHistoryEntry order;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final isBuy = order.side == 'buy';
    final sideColor = isBuy ? const Color(0xFF2E7D32) : const Color(0xFFE53935);
    final sideBg = isBuy ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final sideLabel = isBuy ? 'Compra' : 'Venda';
    final typeLabel = order.orderType == 'market' ? 'Market' : 'Limit';

    final statusLabel = _statusLabel(order.status);
    final statusColor = _statusColor(order.status);
    final statusBg = _statusBg(order.status);

    // Ordem a mercado sem preço definido exibe "—"
    final priceText = order.orderType == 'market' && order.price <= 0
        ? '—'
        : currencyFormat.format(order.price);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBEBF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome da startup e badge de status
          Row(
            children: [
              Expanded(
                child: Text(
                  order.startupNome.isNotEmpty ? order.startupNome : order.startupId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Data e hora da ordem
          Text(
            dateFormat.format(order.createdAt),
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Badge: tipo da ordem (Compra/Venda · Market/Limit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sideBg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '$sideLabel · $typeLabel',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sideColor),
                ),
              ),
              const SizedBox(width: 8),
              // Valor total e detalhes (quantidade · preço · variação)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatOrderTotal(order),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${order.qtyOriginal} ${order.startupSigla.isNotEmpty ? order.startupSigla : 'tkn'} · $priceText',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, color: Colors.black45),
                        ),
                        // Variação em relação ao preço da ordem (só para compras)
                        if (isBuy && order.price > 0 && order.precoAtual > 0) ...[
                          const SizedBox(width: 6),
                          _VariacaoBadge(
                            pct: (order.precoAtual - order.price) / order.price * 100,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Calcula o valor total da ordem (quantidade × preço)
  String _formatOrderTotal(OrderHistoryEntry order) {
    final total = order.qtyOriginal * order.price;
    return currencyFormat.format(total);
  }

  // Converte o status do banco para texto legível
  String _statusLabel(String s) {
    switch (s) {
      case 'executada':             return 'Executada';
      case 'parcialmente_executada': return 'Parcial';
      case 'cancelada':             return 'Cancelada';
      default:                      return 'Aberta';
    }
  }

  // Cor do texto do badge de status
  Color _statusColor(String s) {
    switch (s) {
      case 'executada':             return const Color(0xFF2E7D32);
      case 'parcialmente_executada': return const Color(0xFFE65100);
      case 'cancelada':             return const Color(0xFFE53935);
      default:                      return const Color(0xFF1A237E);
    }
  }

  // Cor de fundo do badge de status
  Color _statusBg(String s) {
    switch (s) {
      case 'executada':             return const Color(0xFFE8F5E9);
      case 'parcialmente_executada': return const Color(0xFFFFF3E0);
      case 'cancelada':             return const Color(0xFFFFEBEE);
      default:                      return const Color(0xFFE8E6FF);
    }
  }
}

// Item de transação: título, subtítulo, valor e badges de direção e fonte
class _TransacaoItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String valor;
  final bool positivo;      // true = entrada, false = saída
  final String direcaoLabel;
  final String fonte;       // "Externo", "Mercado" ou outro

  const _TransacaoItem({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.positivo,
    required this.direcaoLabel,
    required this.fonte,
  });

  @override
  Widget build(BuildContext context) {
    // Cores da badge de direção: verde para entrada, vermelho para saída
    final highlightColor = positivo ? const Color(0xFF2E7D32) : const Color(0xFFE53935);
    final backgroundColor = positivo ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    // Cores da badge de fonte: azul = Externo, roxo = Mercado, cinza = outros
    final fonteColor = fonte == "Externo"
        ? const Color(0xFF1976D2)
        : fonte == "Mercado"
            ? const Color(0xFF7B1FA2)
            : const Color(0xFF616161);
    final fonteBgColor = fonte == "Externo"
        ? const Color(0xFFE3F2FD)
        : fonte == "Mercado"
            ? const Color(0xFFF3E5F5)
            : const Color(0xFFF5F5F5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitulo, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 8),
                // Badges: direção (entrada/saída) e fonte (Externo/Mercado)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        direcaoLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlightColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: fonteBgColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        fonte,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fonteColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Valor da transação alinhado à direita
          Text(
            valor,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: highlightColor),
          ),
        ],
      ),
    );
  }
}