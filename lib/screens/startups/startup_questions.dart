import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/pergunta.dart';
import '../../models/startup.dart';
import '../../services/questions_service.dart';
import '../../services/auth_service.dart';
import '../../services/chatPrivado_service.dart';
import '../startups/startup_private_questions.dart';

class PerguntasTab extends StatefulWidget {
  final Startup? startup;

  const PerguntasTab({super.key, this.startup});

  @override
  State<PerguntasTab> createState() => _PerguntasTabState();
}

class _PerguntasTabState extends State<PerguntasTab> {
  final TextEditingController _msgController = TextEditingController();

  late final PerguntaService _service;
  late final AuthService _authService;
  late final ChatPrivadoService _chatPrivadoService;

  int? _respostaAberta;
  bool _enviando = false;
  bool _verificandoAcesso = false;
  bool? _ehInvestidor;

  @override
  void initState() {
    super.initState();
    _service = PerguntaService();
    _authService = AuthService();
    _chatPrivadoService = ChatPrivadoService();
    _verificarSeInvestidor();
  }

  Future<void> _verificarSeInvestidor() async {
    if (widget.startup == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final result = await _chatPrivadoService.isInvestidor(
      idStartup: widget.startup!.uid ?? '',
      idUsuario: user.uid,
    );
    if (mounted) setState(() => _ehInvestidor = result);
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  String _iniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }

    if (partes.length == 1) {
      return partes[0][0].toUpperCase();
    }

    return '?';
  }

  Future<void> _enviarPergunta() async {
    final texto = _msgController.text.trim();

    if (texto.isEmpty || widget.startup == null) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => _enviando = true);

    try {
      final nomeCompleto =
          await _authService.getUserFullName(user.uid) ?? 'Usuário';

      final iniciais = _iniciais(nomeCompleto);

      final pergunta = Pergunta(
        id: '',
        idAutor: user.uid,
        nomeAutor: nomeCompleto,
        iniciaisAutor: iniciais,
        idStartup: widget.startup!.uid ?? '',
        nomeStartup: widget.startup!.nome ?? '',
        textoPergunta: texto,
        dataEnvio: DateTime.now(),
      );

      await _service.enviarPergunta(pergunta);

      _msgController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar pergunta: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  Future<void> _abrirChatPrivado() async {
    if (widget.startup == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _verificandoAcesso = true);

    try {
      final isInvestidor = await _chatPrivadoService.isInvestidor(
        idStartup: widget.startup!.uid ?? '',
        idUsuario: user.uid,
      );

      if (!mounted) return;

      if (isInvestidor) {
        ChatPrivadoScreen.push(context, widget.startup!);
      } else {
        _mostrarModalBloqueio();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao verificar acesso: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _verificandoAcesso = false);
      }
    }
  }

  void _mostrarModalBloqueio() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
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
                Icons.lock_rounded,
                color: Color(0xFF05054F),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Canal Exclusivo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O chat privado é exclusivo para investidores desta startup. Invista para desbloquear esse canal de comunicação.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF05054F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'Entendi',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startup = widget.startup;

    return Column(
      children: [
        Expanded(
          child: startup == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : StreamBuilder<List<Pergunta>>(
                  stream: _service.getPerguntasStream(
                    startup.uid ?? '',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Erro ao carregar perguntas.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black45,
                          ),
                        ),
                      );
                    }

                    final perguntas = snapshot.data ?? [];

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: perguntas.length + 1,
                      itemBuilder: (context, i) {

                        // CARD CHAT PRIVADO
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _verificandoAcesso ? null : _abrirChatPrivado,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _ehInvestidor == true
                                        ? const Color.fromARGB(255, 0, 14, 64)
                                        : const Color(0xFFE8E8E8),
                                  ),
                                ),
                                child: Row(
                                  children: [

                                    // ÍCONE
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: _ehInvestidor == true
                                        ? const Color(0xFF05054F)   // era 0xFF1A7A4A
                                        : const Color.fromARGB(255, 0, 6, 93),
                                        shape: BoxShape.circle,
                                      ),
                                      child: _verificandoAcesso
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF05054F),
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              _ehInvestidor == true
                                                  ? Icons.lock_open_rounded
                                                  : Icons.lock_outline_rounded,
                                              color: _ehInvestidor == true
                                            ? const Color(0xFFF3F5FF)   // era 0xFFEAF5EE
                                            : const Color(0xFFF3F5FF),
                                            ),
                                    ),

                                    const SizedBox(width: 12),

                                    // TEXTOS
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Chat privado',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Converse de forma privada com a startup',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _ehInvestidor == true
                                                ? 'Você já é investidor — toque para entrar'
                                                : 'Invista para desbloquear esse canal',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _ehInvestidor == true
                                              ? const Color(0xFF05054F)   // era 0xFF1A7A4A
                                              : const Color(0xFF05054F),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.black26,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final p = perguntas[i - 1];
                        final aberta = _respostaAberta == (i - 1);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  _Avatar(iniciais: p.iniciaisAutor),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [

                                        Text(
                                          p.nomeAutor,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),

                                        const SizedBox(height: 2),

                                        Text(
                                          p.textoPergunta,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),

                                        const SizedBox(height: 6),

                                        Row(
                                          children: [

                                            const Expanded(
                                              child: Divider(
                                                height: 1,
                                                color: Color(0xFFDDDDDD),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            if (p.textoResposta.isNotEmpty)
                                              GestureDetector(
                                                onTap: () => setState(() {
                                                  _respostaAberta =
                                                      aberta ? null : (i - 1);
                                                }),
                                                child: Text(
                                                  aberta
                                                      ? 'Ocultar Resposta'
                                                      : 'Ver resposta de ${p.nomeStartup}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF9E9E9E),
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              )
                                            else
                                              const Text(
                                                'Aguardando resposta...',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF9E9E9E),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              if (aberta && p.textoResposta.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 44,
                                    top: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      Text(
                                        p.nomeStartup,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        p.textoResposta,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                          height: 1.5,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _respostaAberta = null,
                                          ),
                                          child: const Text(
                                            'Ocultar Resposta',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF9E9E9E),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),

        // INPUT
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [

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
                  onSubmitted: (_) => _enviando ? null : _enviarPergunta(),
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
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
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
                onPressed: _enviando ? null : _enviarPergunta,
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
                child: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Enviar',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
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