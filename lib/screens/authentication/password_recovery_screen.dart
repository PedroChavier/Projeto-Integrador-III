import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../authentication/reset_password.dart';

class RecuperarSenhaCodigoScreen extends StatefulWidget {
  final String email;
  const RecuperarSenhaCodigoScreen({super.key, this.email = 'ana@email.com'});

  @override
  State<RecuperarSenhaCodigoScreen> createState() =>
      _RecuperarSenhaCodigoScreenState();
}

class _RecuperarSenhaCodigoScreenState
    extends State<RecuperarSenhaCodigoScreen> {
  static const int _totalDigitos = 5;
  static const int _tempoInicial = 50;

  final List<TextEditingController> _controllers =
      List.generate(_totalDigitos, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_totalDigitos, (_) => FocusNode());

  int _segundosRestantes = _tempoInicial;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _iniciarTimer() {
    _timer?.cancel();
    setState(() => _segundosRestantes = _tempoInicial);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 1) {
        t.cancel();
        setState(() => _segundosRestantes = 0);
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _totalDigitos - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  bool get _codigoCompleto =>
      _controllers.every((c) => c.text.isNotEmpty);

  void _redefinirSenha() {
  if (!_codigoCompleto) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RedefinirNovaSenhaScreen()),
  );
}

  void _reenviar() {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    _iniciarTimer();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Status bar + gradiente + back
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradiente
                  Container(
                    height: 3,
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
                  // Seta voltar
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 22),
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  const Text(
                    'Recuperar Senha',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Verifique a sua caixa de entrada!',
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),

                  // Banner info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                              text: 'Enviamos um código de verificação para '),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                              text: '. Use-o para redefinir sua senha.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Instrução + timer
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Digite o codigo enviado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black45),
                            children: [
                              const TextSpan(text: 'o codigo expira em '),
                              TextSpan(
                                text: '${_segundosRestantes}s',
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Campos de dígito
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _totalDigitos,
                      (i) => _DigitBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Não recebeu
                  const Center(
                    child: Text(
                      'Não recebeu? Verifique sua pasta de\nspam ou aguarde alguns minutos',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: Colors.black45, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botão Redefinir Senha
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _codigoCompleto ? _redefinirSenha : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _codigoCompleto
                              ? Colors.black87
                              : Colors.black26,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Redefinir Senha',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _codigoCompleto
                              ? Colors.black87
                              : Colors.black38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reenviar Email
                  Center(
                    child: GestureDetector(
                      onTap: _reenviar,
                      child: const Text(
                        'Reenviar Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Caixa de dígito ───────────────────────────────────────────
class _DigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}