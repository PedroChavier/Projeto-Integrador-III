import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/user_profile.dart';
import '../../models/wallet_holding.dart';
import '../../models/wallet_transaction.dart';
import '../../services/auth_service.dart';
import '../balcao/balcao_screen.dart';
import '../home/home_screen.dart';
import 'deposit_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final AuthService _authService = AuthService();
  Stream<UserProfile?>? _perfilStream;
  Future<List<WalletTransaction>>? _transacoesFuture;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _perfilStream = _authService.streamCurrentUserProfile();
    _carregarHistorico();
  }

  void _carregarHistorico() {
    _transacoesFuture = _authService.getCurrentUserTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _perfilStream,
      builder: (context, snapshot) {
        final saldo = snapshot.data?.saldo ?? 0;
        final holdings = snapshot.data?.holdings ?? const <WalletHolding>[];

        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          body: Column(
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF9A1C63),
                              Color(0xFF1A237E),
                            ],
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

                            if (!mounted) return;
                            setState(_carregarHistorico);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color.fromARGB(79, 0, 0, 0),
                            ),
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
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (holdings.isNotEmpty) ...[
                        const Text(
                          'Tokens na Carteira',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...holdings.map(
                          (holding) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HoldingCard(
                              holding: holding,
                              currencyFormat: _currencyFormat,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        'Histórico de Transações',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<List<WalletTransaction>>(
                        future: _transacoesFuture,
                        builder: (context, transacoesSnapshot) {
                          if (transacoesSnapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Nao foi possivel carregar o historico: ${transacoesSnapshot.error}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.redAccent,
                                ),
                              ),
                            );
                          }

                          if (transacoesSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final transacoes = transacoesSnapshot.data ?? const <WalletTransaction>[];

                          if (transacoes.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Nenhuma movimentacao registrada ainda.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black45,
                                ),
                              ),
                            );
                          }

                          return Column(
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
  }

  String _formatValorTransacao(double valor, bool positivo) {
    final prefixo = positivo ? '+ ' : '- ';
    return '$prefixo${_currencyFormat.format(valor)}';
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.holding,
    required this.currencyFormat,
  });

  final WalletHolding holding;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
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
            children: [
              Expanded(
                child: Text(
                  holding.startupNome.isNotEmpty
                      ? holding.startupNome
                      : holding.startupUid,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '${holding.quantidade} token(s)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          if (holding.startupSetor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              holding.startupSetor,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Investido: ${currencyFormat.format(holding.valorInvestido)}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PreÃ§o mÃ©dio: ${currencyFormat.format(holding.precoMedio)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TransacaoItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String valor;
  final bool positivo;
  final String direcaoLabel;
  final String fonte;

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
    final highlightColor =
        positivo ? const Color(0xFF2E7D32) : const Color(0xFFE53935);
    final backgroundColor =
        positivo ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    
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
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        direcaoLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: highlightColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: fonteBgColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        fonte,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: fonteColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }
}
