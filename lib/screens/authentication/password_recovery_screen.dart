//Giovana Uchelli - 25008818

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/password_recovery_service.dart';

class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _emailController = TextEditingController();
  final _service = PasswordRecoveryService();

  bool _isLoading = false;
  bool _emailEnviado = false;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  //AppBar extraido em metodo para nao poluir o build
  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () {

          //se ja enviou, mostra o form novamente, se nao, sai da tela
          if (_emailEnviado) {
            setState(() => _emailEnviado = false);
          } else {
            Navigator.maybePop(context);
          }
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
            ),
          ),
        ),
      ),
    );
  }

  //Envia o email e inicia o contador para reenvio
  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _mostrarErro('Por favor, informe seu e-mail');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _emailEnviado = true;
          _resendCountdown = 60;
        });
        _iniciarContagem();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        switch (e.code) {
          case 'user-not-found':
            _mostrarErro('Nenhuma conta encontrada com este e-mail');
            break;
          case 'invalid-email':
            _mostrarErro('E-mail inválido');
            break;
          case 'too-many-requests':
            _mostrarErro('Muitas tentativas. Tente novamente mais tarde');
            break;
          default:
            _mostrarErro(e.message ?? 'Erro ao enviar e-mail');
        }
      }
    } catch (_) {
      if (mounted) _mostrarErro('Erro inesperado. Tente novamente');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //reenvia o email - so executa se o contador ja zerou
  Future<void> _reenviar() async {
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);

    try {
      await _service.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        setState(() => _resendCountdown = 60);
        _iniciarContagem();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-mail reenviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) _mostrarErro('Erro ao reenviar e-mail');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //Decrementa o contador a cada segundo
  void _iniciarContagem() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _iniciarContagem();
      }
    });
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

  //Decoração reutilizada nos campos de texto
  InputDecoration _inputDecoration({required String hint}) {
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
    );
  }

  //Botao reutilizado nas duas telas
  Widget _botao({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onPressed == null ? Colors.grey : Colors.black87,
            width: 1.5,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  //Tela 1 - formulario para digitar o email
  Widget _telaEmail() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recuperar Senha',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87),
        ),
        const SizedBox(height: 6),
        const Text(
          'Digite seu e-mail para recuperação',
          style: TextStyle(fontSize: 14, color: Colors.black45),
        ),
        const SizedBox(height: 48),
        const Text(
          'E-mail',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: _inputDecoration(hint: 'seu_email@dominio.com'),
        ),
        const SizedBox(height: 32),
        _botao(
          label: 'Prosseguir',
          onPressed: _isLoading ? null : _enviar,
        ),
      ],
    );
  }

  //Tela 2 - confirmação apos envio do email
  Widget _telaConfirmacao() {
    return Column(
      key: const ValueKey('confirmacao'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recuperar Senha',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87),
        ),
        const SizedBox(height: 6),
        const Text(
          'Verifique a sua caixa de entrada!',
          style: TextStyle(fontSize: 14, color: Colors.black45),
        ),
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              const Text(
                'Instruções Enviadas!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black54, height: 1.5),
                  children: [
                    const TextSpan(text: 'Enviamos um link para '),
                    TextSpan(
                      text: _emailController.text.trim(),
                      style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(
                        text:
                            '.\nClique no link para redefinir sua senha.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
        const Center(
          child: Text(
            'Não recebeu? Verifique sua pasta de\nspam ou aguarde alguns minutos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ),
        const SizedBox(height: 20),
        _botao(
          label: 'Voltar ao Login',
          onPressed: _isLoading ? null : () => Navigator.maybePop(context),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _resendCountdown > 0 || _isLoading ? null : _reenviar,
            child: Text(
              _resendCountdown > 0
                  ? 'Reenviar em $_resendCountdown s'
                  : 'Reenviar e-mail',
              style: TextStyle(
                fontSize: 14,
                color: _resendCountdown > 0 || _isLoading
                    ? Colors.grey
                    : const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          //Anima a troca entre as telas
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _emailEnviado ? _telaConfirmacao() : _telaEmail(),
          ),
        ),
      ),
    );
  }
}