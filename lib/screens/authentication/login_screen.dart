//Giovana Uchelli - 25008818

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'password_recovery_screen.dart';
import 'sms_email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscureSenha = true;
  bool _isLoading = false;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(); //inicializa o serviço de autenticação
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _entrar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    
    if (email.isEmpty || senha.isEmpty) {
      _mostrarErro('Por favor, preencha todos os campos');
      return;
    }

    if (!email.contains('@')) {
      _mostrarErro('E-mail invalido');
      return;
    }

    if (senha.length < 6) {
      _mostrarErro('A senha deve ter pelo menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      //tenta fazer login no firebase auth
      final userCredential = await _authService.login(
        email: email,
        senha: senha,
      );

      final user = userCredential.user;
      UserProfile? profile;

      if (user != null) {
        await user.getIdToken(true);

        profile = await _authService.ensureCurrentUserProfile();

        //bloqueia o login se a conta estiver desativada
        if (!profile.userActive) {
          await _authService.signOut();
          _mostrarErro(
            'Sua conta esta desativada. Fale com um administrador.',
          );
          return;
        }

        if (mounted) {
          if (profile.mfaHabilitado) {
            _mostrarSucesso('Login validado. Escolha como receber o codigo.');

            await Future.delayed(const Duration(milliseconds: 600));
            if (!mounted) return;

            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SmsEmailVerificationScreen(profile: profile!),
              ),
            );
            return;
          }

          //Monta a saudação com o nome do usuario
          final displayName =_authService.formatDisplayName(profile.fullName);
          final saudacao = displayName != null
              ? 'Bem-vindo, $displayName${profile.isAdmin ? ' (admin)' : ''}!'
              : 'Bem-vindo, ${userCredential.user?.email}!';
          _mostrarSucesso(saudacao);

          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false, //remove todas a rotas anteriores da pilha
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao fazer login';

      switch (e.code) {
        case 'user-not-found':
          mensagem = 'Usuario nao encontrado';
          break;
        case 'wrong-password':
          mensagem = 'Senha incorreta';
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
        case 'multi-factor-auth-required':
          mensagem = 'Verificacao de dois fatores necessaria';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context), //Volta so se houver tela anterior
        ),
        bottom: PreferredSize( //PreferedSize informa a altura do bottom
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
            crossAxisAlignment: CrossAxisAlignment.start, //alinha a esquerda
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
                keyboardType: TextInputType.emailAddress, //Abre o teclado com @ em destaque
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'seu_email@dominio.com',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
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
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Digite a sua senha',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSenha
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black38,
                      size: 20,
                    ),

                    //alterna a visibiltade da senha
                    onPressed: () =>
                        setState(() => _obscureSenha = !_obscureSenha),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecuperarSenhaScreen(),
                            ),
                          );
                        },
                  child: RichText( //permite misturar estilos diferentes dentro do mesmo pagrafo
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
                  onPressed: _isLoading ? null : _entrar,
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
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black87,
                            ),
                          ),
                        )
                      : const Text(
                          'Entrar',
                          style: TextStyle(
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
