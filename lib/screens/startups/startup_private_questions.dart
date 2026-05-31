//Giovana Uchelli - 25008818
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/pergunta.dart';
import '../../models/startup.dart';
import '../../services/auth_service.dart';
import '../../services/chatPrivado_service.dart';
import '../home/home_screen.dart';

// Tela de chat privado entre investidor e startup
class ChatPrivadoScreen extends StatefulWidget {
  final Startup startup;

  const ChatPrivadoScreen({super.key, required this.startup});

  //Navega para a tela de chat privado com animação de entrada da direita para a esquerda.
  static Future<void> push(BuildContext context, Startup startup) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatPrivadoScreen(startup: startup),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(1.0, 0.0), // entra da direita
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
          return SlideTransition(position: slide, child: child);
        },
      ),
    );
  }

  @override
  State<ChatPrivadoScreen> createState() => _ChatPrivadoScreenState();
}

class _ChatPrivadoScreenState extends State<ChatPrivadoScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final ChatPrivadoService _service;
  late final AuthService _authService;

  bool _enviando = false; // Bloqueia o botão enquanto envia

  // IDs do investidor logado e da startup
  String get _idInvestidor => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _idStartup => widget.startup.uid ?? '';

  @override
  void initState() {
    super.initState();
    _service = ChatPrivadoService();
    _authService = AuthService();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Gera iniciais do nome: "Ana Souza" → "AS"
  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '?';
  }

  // Rola a lista de mensagens para o final após o frame ser renderizado
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Envia a mensagem como uma pergunta privada no Firestore
  Future<void> _enviar() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty || _enviando) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _enviando = true);

    try {
      final nomeCompleto = await _authService.getUserFullName(user.uid) ?? 'Usuário';

      // Monta o objeto Pergunta com os dados do investidor e da startup
      final pergunta = Pergunta(
        id: '',
        idAutor: user.uid,
        nomeAutor: nomeCompleto,
        iniciaisAutor: _iniciais(nomeCompleto),
        idStartup: _idStartup,
        nomeStartup: widget.startup.nome ?? '',
        textoPergunta: texto,
        dataEnvio: DateTime.now(),
        privada: true,
      );

      await _service.enviarPerguntaPrivada(pergunta);
      _msgController.clear();
      _scrollToBottom(); // Rola para mostrar a nova mensagem
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [

            // Cabeçalho: botão voltar, nome da startup e tag "Privado"
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 22, color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.startup.nome ?? 'Chat Privado',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Canal privado com a startup',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  // Tag "Privado" com ícone de cadeado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 12, color: Color(0xFF05054F)),
                        SizedBox(width: 4),
                        Text(
                          'Privado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF05054F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEAEAEA)),

            // Lista de mensagens em tempo real via Stream do Firestore
            Expanded(
              child: StreamBuilder<List<Pergunta>>(
                stream: _service.getPerguntasPrivadasStream(
                  idStartup: _idStartup,
                  idInvestidor: _idInvestidor,
                ),
                builder: (context, snapshot) {
                  // Loading enquanto aguarda o primeiro dado
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar mensagens.',
                        style: TextStyle(fontSize: 14, color: Colors.black45),
                      ),
                    );
                  }

                  final perguntas = snapshot.data ?? [];

                  // Estado vazio: nenhuma mensagem ainda
                  if (perguntas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F5FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF05054F),
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Nenhuma mensagem ainda.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Envie sua primeira pergunta privada!',
                            style: TextStyle(fontSize: 13, color: Colors.black38),
                          ),
                        ],
                      ),
                    );
                  }

                  _scrollToBottom(); // Garante rolagem ao receber novas mensagens

                  // Para cada pergunta: bolha do investidor + bolha da startup (se houver resposta)
                  final widgets = <Widget>[];
                  for (final p in perguntas) {
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BubbleInvestidor(
                          iniciais: p.iniciaisAutor,
                          texto: p.textoPergunta,
                        ),
                      ),
                    );

                    // Bolha da startup só aparece se a pergunta foi respondida
                    if (p.textoResposta.isNotEmpty) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _BubbleStartup(
                            nomeStartup: p.nomeStartup,
                            iniciais: _iniciais(p.nomeStartup),
                            texto: p.textoResposta,
                          ),
                        ),
                      );
                    }
                  }

                  return ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: widgets,
                  );
                },
              ),
            ),

            // Campo de texto e botão de envio
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  // Avatar do usuário logado
                  _Avatar(
                    iniciais: _iniciais(
                      FirebaseAuth.instance.currentUser?.displayName ?? 'U',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(), // Envia ao pressionar Enter
                      decoration: InputDecoration(
                        hintText: 'Enviar mensagem',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        // Borda roxa ao focar no campo
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão enviar — exibe loading enquanto processa
                  ElevatedButton(
                    onPressed: _enviando ? null : _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 5, 5, 79),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      elevation: 0,
                    ),
                    child: _enviando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Enviar', style: TextStyle(fontSize: 13, color: Colors.white)),
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

// Bolha de mensagem do investidor — alinhada à direita, fundo azul escuro
class _BubbleInvestidor extends StatelessWidget {
  final String iniciais;
  final String texto;

  const _BubbleInvestidor({required this.iniciais, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF05054F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4), // canto "de cauda" à direita
              ),
            ),
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Avatar(iniciais: iniciais),
      ],
    );
  }
}

// Bolha de resposta da startup — alinhada à esquerda, fundo cinza claro
class _BubbleStartup extends StatelessWidget {
  final String nomeStartup;
  final String iniciais;
  final String texto;

  const _BubbleStartup({
    required this.nomeStartup,
    required this.iniciais,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Avatar da startup com as iniciais
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: Color(0xFFD1CEFF), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            iniciais,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome da startup acima da bolha
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4), // canto "de cauda" à esquerda
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(
                  texto,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Avatar circular reutilizável com iniciais do usuário
class _Avatar extends StatelessWidget {
  final String iniciais;

  const _Avatar({required this.iniciais});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Color(0xFFD1CEFF), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        iniciais,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)),
      ),
    );
  }
}