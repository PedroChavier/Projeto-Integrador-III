import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _obscureSenha = true;
  bool _obscureConfirmarSenha = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _criarConta() async {
    // Validações básicas
    if (_nomeController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _cpfController.text.trim().isEmpty ||
        _senhaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios')),
      );
      return;
    }

    if (_senhaController.text != _confirmarSenhaController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('As senhas não coincidem')));
      return;
    }

    // Mostrar indicador de carregamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Criar usuário no Firestore
      await FirebaseFirestore.instance.collection('usuarios').add({
        'nome': _nomeController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'cpf': _cpfController.text.trim(),
        'dataNascimento': _dataNascimentoController.text.trim(),
        'telefone': _telefoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'perfil': 'usuario', // perfil padrão
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      // Limpar campos
      _nomeController.clear();
      _emailController.clear();
      _cpfController.clear();
      _dataNascimentoController.clear();
      _telefoneController.clear();
      _senhaController.clear();
      _confirmarSenhaController.clear();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar conta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
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
              // Título
              const Text(
                'Criar Conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Preencha seus dados para começar',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
              const SizedBox(height: 32),

              // Nome completo
              _label('Nome completo'),
              TextField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: 'Ex: João Pedro de Souza'),
              ),
              const SizedBox(height: 20),

              // E-mail
              _label('E-mail'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: 'Digite seu e-mail'),
              ),
              const SizedBox(height: 20),

              // CPF
              _label('CPF'),
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CpfInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: '000.000.000-00'),
              ),
              const SizedBox(height: 20),

              // Data de Nascimento
              _label('Data de Nascimento'),
              TextField(
                controller: _dataNascimentoController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _DataInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: '01/01/1900'),
              ),
              const SizedBox(height: 20),

              // Telefone
              _label('Telefone'),
              TextField(
                controller: _telefoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _TelefoneInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: '(00) 00000-0000'),
              ),
              const SizedBox(height: 20),

              // Senha
              _label('Senha'),
              TextField(
                controller: _senhaController,
                obscureText: _obscureSenha,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSenha
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black38,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureSenha = !_obscureSenha),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirmar senha
              _label('Confirme sua senha'),
              TextField(
                controller: _confirmarSenhaController,
                obscureText: _obscureConfirmarSenha,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmarSenha
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black38,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmarSenha = !_obscureConfirmarSenha,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Botão Criar Conta
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _criarConta,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black87, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Criar Conta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Formatador de CPF: 000.000.000-00
class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// Formatador de Data: 00/00/0000
class _DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// Formatador de Telefone: (00) 00000-0000
class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
