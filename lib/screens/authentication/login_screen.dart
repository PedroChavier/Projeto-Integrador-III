import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'password_recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _maxTentativasSenha = 5;
  static const Duration _duracaoBloqueio = Duration(minutes: 5);

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscureSenha = true;
  bool _isLoading = false;
  int _tentativasSenhaInvalidas = 0;
  DateTime? _bloqueadoAte;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _emailController.addListener(_atualizarEstadoCampos);
    _senhaController.addListener(_atualizarEstadoCampos);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _atualizarEstadoCampos() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _loginBloqueado {
    final bloqueadoAte = _bloqueadoAte;
    if (bloqueadoAte == null) return false;

    if (DateTime.now().isAfter(bloqueadoAte)) {
      _bloqueadoAte = null;
      _tentativasSenhaInvalidas = 0;
      return false;
    }

    return true;
  }

  bool _isErroSenha(String errorCode) {
    return errorCode == 'wrong-password' ||
        errorCode == 'invalid-credential' ||
        errorCode == 'invalid-login-credentials';
  }

  void _registrarTentativaSenhaInvalida() {
    _tentativasSenhaInvalidas++;

    if (_tentativasSenhaInvalidas >= _maxTentativasSenha) {
      _bloqueadoAte = DateTime.now().add(_duracaoBloqueio);
    }
  }

  void _resetarControleTentativas() {
    _tentativasSenhaInvalidas = 0;
    _bloqueadoAte = null;
  }

  void _limparCamposLogin() {
    _emailController.clear();
    _senhaController.clear();
  }

  void _entrar() async {
    if (_loginBloqueado) {
      _mostrarErro(
        'Acesso temporariamente bloqueado por seguranca. Tente novamente mais tarde.',
      );
      return;
    }

    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      _mostrarErro('Por favor, preencha todos os campos');
      return;
    }

    if (!_isValidEmail(email)) {
      _mostrarErro('E-mail invalido');
      return;
    }

    if (senha.length < 6) {
      _mostrarErro('A senha deve ter pelo menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.login(
        email: email,
        senha: senha,
      );

      if (mounted) {
<<<<<<< HEAD
        final nomeUsuario = userCredential.user?.displayName;
=======
        setState(_resetarControleTentativas);
        final uid = userCredential.user?.uid;
        final nomeUsuario = uid == null
            ? null
            : await _authService.getUserDisplayName(uid);
>>>>>>> 3b98eff3f84c9933e747882bf8fc297bf9ecdc21

        _mostrarSucesso(
          nomeUsuario == null || nomeUsuario.isEmpty
              ? 'Bem-vindo!'
              : 'Bem-vindo, $nomeUsuario!',
        );

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao fazer login';
      final erroSenha = _isErroSenha(e.code);

      if (erroSenha) {
        setState(_registrarTentativaSenhaInvalida);
      }

      switch (e.code) {
        case 'user-not-found':
          mensagem = 'email ou senha invalidos';
          _limparCamposLogin();
          break;
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          if (_loginBloqueado) {
            mensagem =
                'Acesso temporariamente bloqueado por seguranca. Tente novamente mais tarde.';
          } else {
            mensagem = 'email ou senha invalidos';
            _limparCamposLogin();
          }
          break;
        case 'invalid-email':
          mensagem = 'E-mail invalido';
          break;
        case 'user-disabled':
          mensagem = 'Usuario desativado';
          break;
        case 'too-many-requests':
          mensagem = 'Muitas tentativas. Tente novamente mais tarde';
          break;
        default:
          mensagem = e.message ?? 'Erro desconhecido';
      }

      _mostrarErro(mensagem);
    } catch (e) {
      _mostrarErro('Erro ao fazer login: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Insira seus dados para comecar',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
              const SizedBox(height: 48),
              const Text(
                'E-mail',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: 'seu_email@dominio.com'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Senha',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _senhaController,
                obscureText: _obscureSenha,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Digite a sua senha',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSenha
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black38,
                      size: 20,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _obscureSenha = !_obscureSenha),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
<<<<<<< HEAD
=======
                          final email =
                              _emailController.text.trim().toLowerCase();

                          if (!_isValidEmail(email)) {
                            _mostrarErro(
                              'Informe um e-mail valido para recuperar a senha',
                            );
                            return;
                          }

>>>>>>> 3b98eff3f84c9933e747882bf8fc297bf9ecdc21
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecuperarSenhaScreen(),
                            ),
                          );
                        },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Esqueceu sua senha? ',
                      style: TextStyle(color: Colors.black45, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Clique aqui',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading || _loginBloqueado ? null : _entrar,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isLoading ? Colors.grey : Colors.black87,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black87,
                            ),
                          ),
                        )
                      : Text(
                          _loginBloqueado
                              ? 'Bloqueado temporariamente'
                              : 'Entrar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
