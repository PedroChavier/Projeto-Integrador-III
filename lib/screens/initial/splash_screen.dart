//Giovana Uchelli - 25008818

import 'package:flutter/material.dart';
import 'inicio_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Aguarda 2 segundos e vai para a próxima tela
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement( //Remove a splash da pilha
          MaterialPageRoute(builder: (_) => const InicioScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.15,
          child: Image.asset('assets/logo.png'),
        ),
      ),
    );
  }
}


class MesclaInvestLogo extends StatelessWidget {
  const MesclaInvestLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      height: MediaQuery.of(context).size.height * 0.35,
      fit: BoxFit.contain,
    );
  }
}