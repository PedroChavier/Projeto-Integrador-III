import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/registration_service.dart';
import 'setup_2fa_screen.dart';

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
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  bool _obscureSenha = true;
  bool _obscureConfirmarSenha = true;
  bool _isLoading = false;

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

  Future<void> _criarConta() async {
    FocusScope.of(context).unfocus();

    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final cpf = _somenteDigitos(_cpfController.text);
    final telefone = _somenteDigitos(_telefoneController.text);
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;
    final dataNascimento = _parseDataNascimento(
      _dataNascimentoController.text.trim(),
    );

    if (nome.isEmpty ||
        email.isEmpty ||
        cpf.isEmpty ||
        telefone.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty ||
        dataNascimento == null) {
      _mostrarMensagem(
        'Preencha todos os campos obrigatorios corretamente.',
        isError: true,
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _mostrarMensagem('Informe um e-mail valido.', isError: true);
      return;
    }

    if (cpf.length != 11) {
      _mostrarMensagem('Informe um CPF com 11 digitos.', isError: true);
      return;
    }

    if (telefone.length < 10 || telefone.length > 11) {
      _mostrarMensagem('Informe um telefone valido.', isError: true);
      return;
    }

    if (senha.length < 6) {
      _mostrarMensagem(
        'A senha deve ter pelo menos 6 caracteres.',
        isError: true,
      );
      return;
    }

    if (senha != confirmarSenha) {
      _mostrarMensagem('As senhas nao coincidem.', isError: true);
      return;
    }

    if (!_isMaiorDeIdade(dataNascimento)) {
      _mostrarMensagem(
        'Voce precisa ter pelo menos 18 anos para criar uma conta.',
        isError: true,
      );
      return;
    }

    final usuario = Usuario(
      cpf: cpf,
      fullName: nome,
      dataNascimento: dataNascimento,
      email: email,
      senha: senha,
      telefone: telefone,
      mfaHabilitado: false,
      userActive: true,
      userloggedIn: false,
    );

    if (!usuario.cadastrarUsuario()) {
      _mostrarMensagem(
        'Os dados informados nao passaram na validacao do modelo.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _registrationService.registerUser(usuario);
      final newUser = _authService.currentUser;

      if (!mounted) return;

      // Oferecer ativar 2FA após o registro
      if (newUser != null) {
        final ativar2FA = await _showDialogAtivar2FA();
        if (ativar2FA && mounted) {
          // Navegar para setup de 2FA com telefone do registro
          try {
            // Enviar código para o telefone registrado
            debugPrint('[2FA] Tentando enviar código para +55$telefone');
            final verificationId = await _authService.sendMFACode(
              phoneNumber: '+55$telefone',
            );
            debugPrint('[2FA] Código enviado com sucesso. VerificationId: $verificationId');

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => Setup2FAScreen(
                    verificationId: verificationId,
                    phoneNumber: '+55$telefone',
                    isFromRegistration: true,
                  ),
                ),
              );
            }
            return;
          } on FirebaseAuthException catch (e) {
            debugPrint('[2FA] FirebaseAuthException: code=${e.code}, message=${e.message}');
            _mostrarMensagem(
              'Erro Firebase: ${e.message ?? e.code}',
              isError: true,
            );
          } catch (e) {
            debugPrint('[2FA] Erro geral: ${e.toString()}');
            _mostrarMensagem(
              'Erro ao enviar código 2FA: ${e.toString()}',
              isError: true,
            );
          }
        }
      }

      // Fazer logout após oferecer 2FA
      try {
        await _authService.signOut();
      } catch (error) {
        debugPrint('Falha ao sair apos o cadastro: $error');
      }

      if (!mounted) return;
      _limparCampos();
      _mostrarMensagem('Conta criada com sucesso. Agora voce ja pode entrar.');
      Navigator.of(context).maybePop();
    } on FirebaseAuthException catch (error) {
      _mostrarMensagem(_mensagemAuth(error), isError: true);
    } catch (error) {
      debugPrint('Erro inesperado no cadastro: $error');
      _mostrarMensagem(
        'Nao foi possivel concluir o cadastro agora.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _limparCampos() {
    _nomeController.clear();
    _emailController.clear();
    _cpfController.clear();
    _dataNascimentoController.clear();
    _telefoneController.clear();
    _senhaController.clear();
    _confirmarSenhaController.clear();
  }

  void _mostrarMensagem(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.red[400] : Colors.green[400],
      ),
    );
  }

  String _mensagemAuth(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Ja existe uma conta com este e-mail.';
      case 'invalid-email':
        return 'O e-mail informado e invalido.';
      case 'weak-password':
        return 'Escolha uma senha mais forte.';
      case 'operation-not-allowed':
        return 'Cadastro por e-mail e senha nao esta habilitado.';
      case 'cpf-already-in-use':
        return 'Ja existe uma conta com este CPF.';
      case 'invalid-cpf':
        return 'Informe um CPF valido.';
      default:
        return error.message ?? 'Erro ao criar a conta.';
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  String _somenteDigitos(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  DateTime? _parseDataNascimento(String value) {
    final partes = value.split('/');
    if (partes.length != 3) return null;

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);

    if (dia == null || mes == null || ano == null) return null;

    final data = DateTime.tryParse(
      '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}',
    );

    if (data == null) return null;
    if (data.year != ano || data.month != mes || data.day != dia) return null;
    if (data.isAfter(DateTime.now())) return null;

    return data;
  }

  bool _isMaiorDeIdade(DateTime dataNascimento) {
    final hoje = DateTime.now();
    var idade = hoje.year - dataNascimento.year;

    final aindaNaoFezAniversario =
        hoje.month < dataNascimento.month ||
        (hoje.month == dataNascimento.month && hoje.day < dataNascimento.day);

    if (aindaNaoFezAniversario) {
      idade--;
    }

    return idade >= 18;
  }

  Future<bool> _showDialogAtivar2FA() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Ativar Autenticação de Dois Fatores?'),
            content: const Text(
              'Proteja sua conta com autenticação de dois fatores. '
              'Você receberá um código por SMS para verificar seu login.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Depois'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Ativar Agora',
                  style: TextStyle(color: Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
        ) ??
        false;
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
          onPressed: _isLoading ? null : () => Navigator.maybePop(context),
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
                'Criar Conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Preencha seus dados para comecar',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
              const SizedBox(height: 32),
              _label('Nome completo'),
              TextField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: 'Ex: Joao Pedro de Souza'),
              ),
              const SizedBox(height: 20),
              _label('E-mail'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: 'Digite seu e-mail'),
              ),
              const SizedBox(height: 20),
              _label('CPF'),
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CpfInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: '000.000.000-00'),
              ),
              const SizedBox(height: 20),
              _label('Data de nascimento'),
              TextField(
                controller: _dataNascimentoController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _DataInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: '01/01/1900'),
              ),
              const SizedBox(height: 20),
              _label('Telefone'),
              TextField(
                controller: _telefoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _TelefoneInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(hint: '(00) 00000-0000'),
              ),
              const SizedBox(height: 20),
              _label('Senha'),
              TextField(
                controller: _senhaController,
                obscureText: _obscureSenha,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Digite sua senha',
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
              const SizedBox(height: 20),
              _label('Confirme sua senha'),
              TextField(
                controller: _confirmarSenhaController,
                obscureText: _obscureConfirmarSenha,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Repita sua senha',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmarSenha
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black38,
                      size: 20,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => setState(
                            () => _obscureConfirmarSenha =
                                !_obscureConfirmarSenha,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _criarConta,
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
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black87,
                            ),
                          ),
                        )
                      : const Text(
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
