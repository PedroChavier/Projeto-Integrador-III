import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../balcao/balcao_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../startups/startups_catalog_screen.dart';
import '../wallet/wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    _Header(),
                    const SizedBox(height: 24),
                    const _SaldoCard(),
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

class _Header extends StatefulWidget {
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  final AuthService _authService = AuthService();
  Future<UserProfile?>? _perfilFuture;

  @override
  void initState() {
    super.initState();
    _perfilFuture = _authService.getCurrentUserProfile();
  }

  String _primeiroNome(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '';
    return nome.trim().split(RegExp(r'\s+')).first;
  }

  String _iniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '';
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return partes[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _perfilFuture,
      builder: (context, snapshot) {
        final nome = snapshot.data?.fullName ?? '';
        final iniciais = _iniciais(nome);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              nome.isNotEmpty ? 'Olá, ${_primeiroNome(nome)}' : 'Olá!',
              style: const TextStyle(
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
                child: iniciais.isNotEmpty
                    ? Text(
                        iniciais,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 22,
                        color: Color(0xFF6C63FF),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SaldoCard extends StatefulWidget {
  const _SaldoCard();

  @override
  State<_SaldoCard> createState() => _SaldoCardState();
}

class _SaldoCardState extends State<_SaldoCard> {
  final AuthService _authService = AuthService();
  Future<UserProfile?>? _perfilFuture;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _perfilFuture = _authService.getCurrentUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _perfilFuture,
      builder: (context, snapshot) {
        final saldo = snapshot.data?.saldo ?? 0;

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
        );
      },
    );
  }
}

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
      case 3:
        screen = const BalcaoScreen();
        break;
      case 4:
        screen = const DashboardScreen();
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
      selectedItemColor: const Color.fromARGB(255, 5, 0, 91),
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
