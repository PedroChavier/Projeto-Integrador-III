import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class ChatPrivadoScreen extends StatefulWidget {
  const ChatPrivadoScreen({super.key});

  // Use este método para navegar até o ChatPrivadoScreen
  // Substitua o Navigator.push(...MaterialPageRoute...) pelo:
  // ChatPrivadoScreen.push(context)
  static Future<void> push(BuildContext context) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ChatPrivadoScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ));
          return SlideTransition(position: slide, child: child);
        },
      ),
    );
  }

  @override
  State<ChatPrivadoScreen> createState() =>
      _ChatPrivadoScreenState();
}

class _ChatPrivadoScreenState extends State<ChatPrivadoScreen> {
  final TextEditingController _msgController = TextEditingController();

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat Privado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Converse de forma privada com a startup',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEAEAEA)),

            // MENSAGENS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _BubbleInvestidor(
                    iniciais: 'PD',
                    texto: 'Qual é o modelo de receita principal da startup?',
                  ),

                  const SizedBox(height: 10),

                  _BubbleStartup(
                    nomeStartup: 'AgroSense',
                    texto:
                        'Nosso modelo é baseado em assinatura mensal por sensor ativo na lavoura.',
                  ),

                  const SizedBox(height: 18),

                  _BubbleInvestidor(
                    iniciais: 'PD',
                    texto: 'Vocês possuem previsão de expansão internacional?',
                  ),

                  const SizedBox(height: 10),

                  _BubbleStartup(
                    nomeStartup: 'AgroSense',
                    texto:
                        'Sim. Estamos planejando expansão para América Latina.',
                  ),

                  const SizedBox(height: 18),

                  _BubbleInvestidor(
                    iniciais: 'PD',
                    texto: 'Como funciona o suporte técnico para produtores?',
                  ),

                  const SizedBox(height: 10),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 42),
                      child: Text(
                        'Aguardando resposta...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // INPUT
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  const _Avatar(iniciais: 'AN'),

                  const SizedBox(width: 8),

                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enviar Mensagem',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.black38,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C63FF),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 5, 5, 79),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Enviar',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// BOLHA DO INVESTIDOR (direita)
class _BubbleInvestidor extends StatelessWidget {
  final String iniciais;
  final String texto;

  const _BubbleInvestidor({
    required this.iniciais,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF05054F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Avatar(iniciais: iniciais),
      ],
    );
  }
}

// BOLHA DA STARTUP (esquerda)
class _BubbleStartup extends StatelessWidget {
  final String nomeStartup;
  final String texto;

  const _BubbleStartup({
    required this.nomeStartup,
    required this.texto,
  });

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFD1CEFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _iniciais(nomeStartup),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nomeStartup,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 78, 78, 78),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String iniciais;

  const _Avatar({required this.iniciais});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFD1CEFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        iniciais,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }
}