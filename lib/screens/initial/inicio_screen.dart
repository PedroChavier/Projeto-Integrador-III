//Giovana Uchelli - 25008818
import 'package:flutter/material.dart';
// Importa as telas de login e cadastro
import '../authentication/login_screen.dart';
import '../authentication/register_screen.dart';


// Tela inicial do app — não tem estado, por isso StatelessWidget
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // SafeArea evita que o conteúdo fique em áreas problemáticas (notch, barra de status)
      body: SafeArea(
        child: Padding(
          // Espaçamento horizontal de 32px dos dois lados
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              // Espaço flexível acima da logo
              const Spacer(flex: 2),

              // Logo do app com altura proporcional à tela
              Image.asset(
                'assets/logo.png',
                height: MediaQuery.of(context).size.height * 0.15,
              ),

              // Espaço flexível entre a logo e os botões
              const Spacer(flex: 3),

              // Botão "Entrar" — navega para a tela de login
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52), // Largura total, altura 52px
                  side: const BorderSide(color: Colors.black26), // Borda cinza clara
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // Cantos arredondados
                  ),
                ),
                child: const Text(
                  'Entrar',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),

              // Espaço fixo de 16px entre os elementos
              const SizedBox(height: 16),

              // Divisor visual com texto "ou" no meio
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: TextStyle(color: Colors.black45)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 16),

              // Botão "Criar Conta" — navega para a tela de cadastro
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CadastroScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Criar Conta',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),

              // Espaço flexível abaixo dos botões
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}