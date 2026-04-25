import 'package:flutter/material.dart';
//importa somnete o widget MesclaInvestLogo
import 'splash_screen.dart' show MesclaInvestLogo;
import '../authentication/login_screen.dart';
import '../authentication/register_screen.dart';


class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      //SafeArea evita que o conteudo fique em areas problematicas
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const MesclaInvestLogo(),
              const Spacer(flex: 3),
              OutlinedButton(
                onPressed: () {
                  Navigator.push( 
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
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
                  'Entrar',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              //espaço fixo de 16 px entre os elemnetos
              const SizedBox(height: 16),
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
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CadastroScreen()),
                  );
                  // TODO: navegar para cadastro
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}