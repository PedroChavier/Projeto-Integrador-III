import 'package:flutter/material.dart';
import '../startups/startups_catalog_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            // Gradiente topo
            SizedBox(height: 20),
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _Header(),
                    const SizedBox(height: 24),

                    // Card Saldo
                    _SaldoCard(),
                    const SizedBox(height: 28),

                    // Meus Tokens
                    const Text(
                      'Meus tokens',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TokenItem(
                      nome: 'AgroSense',
                      tokens: '150 tokens',
                      valor: 'R\$ 3.750',
                      variacao: '+8,2%',
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    _TokenItem(
                      nome: 'MedConnect',
                      tokens: '50 tokens',
                      valor: 'R\$ 2.750',
                      variacao: '+4,2%',
                    ),
                    const SizedBox(height: 28),

                    // Atualizações
                    const Text(
                      'Atualizações',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AtualizacaoCard(
                      tag: 'Atualização',
                      tagColor: Color(0xFFE8E6FF),
                      tagTextColor: Color(0xFF6C63FF),
                      tempo: 'há 2h',
                      titulo: 'AgroSense lança versão 2.0',
                      descricao: 'Novos sensores IoT para monitoramento de lavouras em tempo real',
                    ),
                    const SizedBox(height: 12),
                    _AtualizacaoCard(
                      tag: 'Evento',
                      tagColor: Color(0xFFF3E8FF),
                      tagTextColor: Color(0xFFAB47BC),
                      tempo: 'amanhã',
                      titulo: 'AgroSense lança versão 2.0',
                      descricao: 'Novos sensores IoT para monitoramento de lavouras em tempo real',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Olá, Ana',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PerfilScreen()),
          ),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFD1CEFF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'AN',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Card Saldo ────────────────────────────────────────────────
class _SaldoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'R\$ 2.000,00',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '3 Startups Investidas',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Token Item ────────────────────────────────────────────────
class _TokenItem extends StatelessWidget {
  final String nome;
  final String tokens;
  final String valor;
  final String variacao;

  const _TokenItem({
    required this.nome,
    required this.tokens,
    required this.valor,
    required this.variacao,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tokens,
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                variacao,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card Atualização ──────────────────────────────────────────
class _AtualizacaoCard extends StatelessWidget {
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final String tempo;
  final String titulo;
  final String descricao;

  const _AtualizacaoCard({
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.tempo,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tagTextColor,
                  ),
                ),
              ),
              Text(
                tempo,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget screen;

    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const StartupsScreen();
        break;
      case 2:
        screen = const WalletScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _navigate(context, index),
      selectedItemColor: const Color(0xFF6C63FF),
      unselectedItemColor: Colors.black45,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Startups'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Carteira'),
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz_outlined), label: 'Balcão'),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), label: 'DashBoard'),
      ],
    );
  }
}