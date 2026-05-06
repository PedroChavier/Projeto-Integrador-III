import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const VerifyOTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _secondsRemaining = 120;
  late Future _initFuture;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _initFuture = Future.value();
    _iniciarTemporizador();
  }

  void _iniciarTemporizador() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            _iniciarTemporizador();
          }
        });
      }
    });
  }

  Future<void> _verificarCodigo() async {
    final codigo = _codeController.text.trim();

    if (codigo.isEmpty) {
      _mostrarErro('Por favor, digite o código OTP');
      return;
    }

    if (codigo.length < 6) {
      _mostrarErro('O código deve ter 6 dígitos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final _ = await _authService.verifyMFACode(
        verificationId: widget.verificationId,
        smsCode: codigo,
      );

      if (mounted) {
        _mostrarSucesso('Autenticação bem-sucedida!');

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao verificar código';

      switch (e.code) {
        case 'invalid-verification-code':
          mensagem = 'Código de verificação inválido';
          break;
        case 'session-expired':
          mensagem = 'Sessão expirada. Tente novamente';
          break;
        default:
          mensagem = e.message ?? 'Erro desconhecido';
      }

      _mostrarErro(mensagem);
    } catch (e) {
      _mostrarErro('Erro: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reenviarCodigo() async {
    setState(() {
      _secondsRemaining = 120;
      _codeController.clear();
    });

    _iniciarTemporizador();
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green[400],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatarTempo() {
    int minutos = _secondsRemaining ~/ 60;
    int segundos = _secondsRemaining % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
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
        ),
      ),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ícone de segurança
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(108, 99, 255, 0.1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Color(0xFF6C63FF),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Título
                  const Text(
                    'Verificação de Dois Fatores',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descrição
                  Text(
                    'Digite o código de 6 dígitos enviado para ${widget.phoneNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Campo OTP
                  const Text(
                    'Código OTP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(
                        color: Colors.black26,
                        fontSize: 32,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF6C63FF),
                          width: 2,
                        ),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Temporizador e opção de reenviar
                  Center(
                    child: Column(
                      children: [
                        if (_secondsRemaining > 0)
                          Text(
                            'Código expira em ${_formatarTempo()}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _secondsRemaining < 30
                                  ? Colors.red[400]
                                  : Colors.black54,
                              fontWeight: _secondsRemaining < 30
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          )
                        else
                          const Text(
                            'Código expirado',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _secondsRemaining > 0
                              ? null
                              : (_isLoading ? null : _reenviarCodigo),
                          child: Text(
                            'Reenviar código',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _secondsRemaining > 0
                                  ? Colors.black26
                                  : const Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Botão Verificar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verificarCodigo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        disabledBackgroundColor: Colors.black12,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Verificar Código',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link voltar ao login
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading ? null : () => Navigator.pop(context),
                      child: RichText(
                        text: const TextSpan(
                          text: 'Voltar ao ',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
