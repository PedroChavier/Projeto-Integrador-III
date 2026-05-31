//Pedro Andre do Carmo Chavier -25018639

import 'dart:math'; //Randon.secure() para a geraçãi de senha aleatoria

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; //TextInputFormatter para mascaras de CPF, data e telefone

import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/registration_service.dart';

//Regras de senha
const int _senhaMinLength = 8;
const int _senhaMaxLength = 20;
final RegExp _senhaUppercaseRegex = RegExp(r'[A-Z]'); //Pelo menos uma maiuscula
final RegExp _senhaLowercaseRegex = RegExp(r'[a-z]'); //Pelo menos uma minuscula
final RegExp _senhaNumberRegex = RegExp(r'[0-9]'); // pelo menos um numero
final RegExp _senhaSpecialRegex = RegExp(r'[^A-Za-z0-9]'); // pelo menos um especial

//Caracteres usados na geraçãi de senha aletoria
const String _caracteresMaiusculos = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const String _caracteresMinusculos = 'abcdefghijklmnopqrstuvwxyz';
const String _caracteresNumericos = '0123456789';
const String _caracteresEspeciais = '!@#\$%^&*()-_=+[]{};:,.?';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final Random _random = Random.secure(); //gerados criptograficamente seguro

  //controllers para cada campo do formulario
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _senhaFocusNode = FocusNode();
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  bool _obscureSenha = true;
  bool _obscureConfirmarSenha = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    //ouve mudanças nos campos para atualizar as cores de bordas e requisitos de senha
    _nomeController.addListener(_atualizarEstadoCampos);
    _emailController.addListener(_atualizarEstadoCampos);
    _cpfController.addListener(_atualizarEstadoCampos);
    _dataNascimentoController.addListener(_atualizarEstadoCampos);
    _senhaController.addListener(_atualizarEstadoSenhas);
    _confirmarSenhaController.addListener(_atualizarEstadoSenhas);
    _senhaFocusNode.addListener(_atualizarEstadoCampos);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _senhaFocusNode.dispose();
    super.dispose();
  }

  //força a reconstrução da tela para atualizar cores de borda e outros estados visuais
  void _atualizarEstadoCampos() {
    if (mounted) {
      setState(() {});
    }
  }

  //Limpa a confirmação de senha se a senha for apagasa
  void _atualizarEstadoSenhas() {
    if (_senhaController.text.isEmpty && _confirmarSenhaController.text.isNotEmpty) {
      _confirmarSenhaController.clear();
    }

    if (mounted) {
      setState(() {});
    }
  }

  //Valida todos os campos e cria a conta no Firebase
  Future<void> _criarConta() async {
    FocusScope.of(context).unfocus(); //fecha o teclado antes de começar

    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final cpf = _normalizarCpf(_cpfController.text);
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
      _mostrarMensagem('Informe um CPF com 11 caracteres.', isError: true);
      return;
    }

    if (telefone.length < 10 || telefone.length > 11) {
      _mostrarMensagem('Informe um telefone valido.', isError: true);
      return;
    }

    final senhaErro = _validarSenha(senha);
    if (senhaErro != null) {
      _mostrarMensagem(senhaErro, isError: true);
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
      telefone: telefone,
      mfaHabilitado: false,
      userActive: true,
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
      await _registrationService.registerUser(usuario, senha: senha);

      if (!mounted) return;

      // Desloga imediatmente após o cadastro
      try {
        await _authService.signOut();
      } catch (error) {
        debugPrint('Falha ao sair apos o cadastro: $error');
      }

      if (!mounted) return;
      _limparCampos();
      _mostrarMensagem('Conta criada com sucesso. Agora voce ja pode entrar.');
      Navigator.of(context).maybePop(); // volta a tela

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

  //Limpa todos os campos do formulario
  void _limparCampos() {
    _nomeController.clear();
    _emailController.clear();
    _cpfController.clear();
    _dataNascimentoController.clear();
    _telefoneController.clear();
    _senhaController.clear();
    _confirmarSenhaController.clear();
  }

  //Limpa apenas os campos de senha
  void _limparSenhas() {
    _senhaController.clear();
    _confirmarSenhaController.clear();
    _mostrarMensagem('Campos de senha limpos.');
  }

  //Gera uma senha aleatoria que preenche todos os requisitos e preenche os dois campos
  void _gerarSenhaAleatoria() {
    final comprimento =
        _senhaMinLength + 7 + _random.nextInt(_senhaMaxLength - 14);

    final caracteresObrigatorios = [
      _sortearCaractere(_caracteresMaiusculos),
      _sortearCaractere(_caracteresMinusculos),
      _sortearCaractere(_caracteresNumericos),
      _sortearCaractere(_caracteresEspeciais),
    ];

    final todosCaracteres =
        '$_caracteresMaiusculos$_caracteresMinusculos$_caracteresNumericos$_caracteresEspeciais';
    
    //completa o restante com caracteres aleatorios e embaralha
    final senha = <String>[
      ...caracteresObrigatorios,

      for (int i = caracteresObrigatorios.length; i < comprimento; i++)
        _sortearCaractere(todosCaracteres),
    ]..shuffle(_random); //suffle: embaralha os elementos da lista

    final senhaGerada = senha.join();
    _senhaController.text = senhaGerada;
    _confirmarSenhaController.text = senhaGerada;
    _mostrarMensagem('Senha aleatoria gerada e preenchida.');
  }

  //sorteia um caractere aleatorio de uma string
  String _sortearCaractere(String caracteres) {
    return caracteres[_random.nextInt(caracteres.length)];
  }

  //snackbar verde (sucesso) ou vermelha (erro)
  void _mostrarMensagem(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.red[400] : Colors.green[400],
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  //traduz codigos de erro do firebase para mensagens amigaveis
  String _mensagemAuth(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Ja existe uma conta com este e-mail.';
      case 'invalid-email':
        return 'O e-mail informado e invalido.';
      case 'weak-password':
        return 'A senha deve ter entre 8 e 20 caracteres, com maiuscula, minuscula, numero e caractere especial.';
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

  //valida formato de email com regex
  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  //valida cpf verificando formato e digitos verificadores
  bool _isValidCpf(String value) {
    final cpf = _normalizarCpf(value);

    if (cpf.length != 11) return false;
    if (!RegExp(r'^\d{10}[\dX]$').hasMatch(cpf)) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false; //rejeita todos iguals (0000000)

    if (cpf.endsWith('X')) { //cpfs terminados em x sao validos
      return true;
    }

    //calcula e verifica os dois digitos verificadores
    int calcularDigito(int length) {
      var soma = 0;
      //soma os digitos multiplicados pelos seus respectivos pesos
      for (int i = 0; i < length; i++) {
        soma += int.parse(cpf[i]) * ((length + 1) - i);
      }

      final resto = soma % 11;

      //se resto for menor que 2, o digito é 0
      //caso contario, o digito é 11 menos o resto
      return resto < 2 ? 0 : 11 - resto;
    }

    final primeiroDigito = calcularDigito(9);
    final segundoDigito = calcularDigito(10);


    //confere se os digitos verficadores calculados sao iguais aos dois ultimos digitos informados no cpf
    return cpf[9] == primeiroDigito.toString() &&
        cpf[10] == segundoDigito.toString();
  }


  //remove tudo que nao for digito
  String _somenteDigitos(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  //remove a formatação do cpf, mantendo apenas digitos e X
  String _normalizarCpf(String value) {
    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9X]'), '');
  }

  //converte string para DateTime
  DateTime? _parseDataNascimento(String value) {
    final partes = value.split('/');
    if (partes.length != 3) return null;

    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);

    if (dia == null || mes == null || ano == null) return null;

    //Monta a data no formato ISO
    final data = DateTime.tryParse(
      '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}',
    );

    if (data == null) return null;
    if (data.year != ano || data.month != mes || data.day != dia) return null;
    if (data.isAfter(DateTime.now())) return null; //data no futuro é invalida

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


  //Getters para ler os atributos privados
  bool get _senhaFoiPreenchida => _senhaController.text.isNotEmpty;
  bool get _senhaEstaEmFoco => _senhaFocusNode.hasFocus;
  bool get _mostrarRequisitosSenha =>
      _senhaFoiPreenchida || _senhaEstaEmFoco;
  bool get _senhaTemMaiuscula =>
      _senhaUppercaseRegex.hasMatch(_senhaController.text);
  bool get _senhaTemMinuscula =>
      _senhaLowercaseRegex.hasMatch(_senhaController.text);
  bool get _senhaTemNumero => _senhaNumberRegex.hasMatch(_senhaController.text);
  bool get _senhaTemEspecial =>
      _senhaSpecialRegex.hasMatch(_senhaController.text);
  bool get _senhaTemTamanhoValido {
    final senha = _senhaController.text;
    return senha.length >= _senhaMinLength && senha.length <= _senhaMaxLength;
  }
  //somente se todos os requisitos foram atendudos simultaneamente
  bool get _senhaAtendePolitica =>
      _senhaTemTamanhoValido &&
      _senhaTemMaiuscula &&
      _senhaTemMinuscula &&
      _senhaTemNumero &&
      _senhaTemEspecial;

  //Getters de cor de borda: verde = valido, vermelho: invalido, null = neutro
  Color? get _corBordaNome {
    if (_nomeController.text.trim().isEmpty) return null;
    return Colors.green;
  }

  Color? get _corBordaEmail {
    final email = _emailController.text.trim();
    if (email.isEmpty) return null;
    return _isValidEmail(email) ? Colors.green : Colors.red;
  }

  Color? get _corBordaCpf {
    if (_cpfController.text.trim().isEmpty) return null;
    return _isValidCpf(_cpfController.text) ? Colors.green : Colors.red;
  }

  Color? get _corBordaDataNascimento {
    final textoData = _dataNascimentoController.text.trim();
    if (textoData.isEmpty) return null;

    final data = _parseDataNascimento(textoData);
    if (data == null) return Colors.red;

    return _isMaiorDeIdade(data) ? Colors.green : Colors.red;
  }

  Color? get _corBordaSenhas {
    if (_senhaFoiPreenchida && !_senhaAtendePolitica) {
      return Colors.red;
    }

    if (_confirmarSenhaController.text.isEmpty) {
      return null;
    }

    return _senhaController.text == _confirmarSenhaController.text &&
            _senhaAtendePolitica
        ? Colors.green
        : Colors.red;
  }

  String? _validarSenha(String senha) {
    if (senha.length < _senhaMinLength || senha.length > _senhaMaxLength) {
      return 'A senha deve ter entre $_senhaMinLength e $_senhaMaxLength caracteres.';
    }

    if (!_senhaUppercaseRegex.hasMatch(senha)) {
      return 'A senha deve conter pelo menos uma letra maiuscula.';
    }

    if (!_senhaLowercaseRegex.hasMatch(senha)) {
      return 'A senha deve conter pelo menos uma letra minuscula.';
    }

    if (!_senhaNumberRegex.hasMatch(senha)) {
      return 'A senha deve conter pelo menos um numero.';
    }

    if (!_senhaSpecialRegex.hasMatch(senha)) {
      return 'A senha deve conter pelo menos um caractere especial.';
    }

    return null;
  }

  //Linha de requisito de senha: icone de checkbox + texto verde se atendido
  Widget _itemRegraSenha({
    required bool atendida,
    required String texto,
  }) {
    final color = atendida ? Colors.green : Colors.black45;

    return Row(
      children: [
        Icon(
          atendida ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18,
          color: atendida ? Colors.green : Colors.black38,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: atendida ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  //Decoração reutilizada em todos os campos
  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
    Color? enabledBorderColor,
    Color? focusedBorderColor,
  }) {
    final borderColor = enabledBorderColor ?? const Color(0xFFE0E0E0);
    final activeBorderColor = focusedBorderColor ?? enabledBorderColor ?? const Color(0xFF6C63FF);

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: activeBorderColor, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  //Label reutilizado acima de cada campo
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

              _label('Nome completo*'),
              TextField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words, //Capitalizar cada palavra
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Ex: Joao Pedro de Souza',
                  enabledBorderColor: _corBordaNome,
                  focusedBorderColor: _corBordaNome,
                ),
              ),
              const SizedBox(height: 20),

              _label('E-mail'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Digite seu e-mail',
                  enabledBorderColor: _corBordaEmail,
                  focusedBorderColor: _corBordaEmail,
                ),
              ),
              const SizedBox(height: 20),

              _label('CPF*'),
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                enabled: !_isLoading,
                inputFormatters: [
                  _CpfInputFormatter(),
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: '000.000.000-0X',
                  enabledBorderColor: _corBordaCpf,
                  focusedBorderColor: _corBordaCpf,
                ),
              ),
              const SizedBox(height: 20),
              _label('Data de nascimento*'),
              TextField(
                controller: _dataNascimentoController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, //Bloqueia letras
                  _DataInputFormatter(), // aplica mascara DD/MM/AAAA
                ],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: '01/01/1900',
                  enabledBorderColor: _corBordaDataNascimento,
                  focusedBorderColor: _corBordaDataNascimento,
                ),
              ),

              const SizedBox(height: 20),

              _label('Telefone*'),
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

              _label('Senha*'),
              TextField(
                controller: _senhaController,
                focusNode: _senhaFocusNode,
                obscureText: _obscureSenha,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Digite sua senha',
                  enabledBorderColor: _corBordaSenhas,
                  focusedBorderColor: _corBordaSenhas,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      IconButton(
                        tooltip: 'Limpar senhas',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints( //Define altura e largura minima que widget pode ter
                          minWidth: 36,
                          minHeight: 36,
                        ),

                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.cleaning_services_outlined,
                          color: Colors.black38,
                          size: 20,
                        ),

                        onPressed: _isLoading ? null : _limparSenhas,
                      ),
                      IconButton(
                        tooltip: 'Gerar senha segura',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.password_outlined,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: _isLoading ? null : _gerarSenhaAleatoria,
                      ),
                      IconButton(
                        tooltip: _obscureSenha
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),

                        //reduz o espaçamento interno do widget, deixando mais compacto
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _obscureSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _obscureSenha = !_obscureSenha,
                              ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              if (_mostrarRequisitosSenha) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _senhaFoiPreenchida && !_senhaAtendePolitica
                          ? Colors.red.shade200
                          : const Color(0xFFE6E8EC),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requisitos da senha',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _itemRegraSenha(
                        atendida: _senhaTemMaiuscula,
                        texto: 'Exigir caractere maiusculo',
                      ),
                      const SizedBox(height: 8),
                      _itemRegraSenha(
                        atendida: _senhaTemMinuscula,
                        texto: 'Exigir caractere minusculo',
                      ),
                      const SizedBox(height: 8),
                      _itemRegraSenha(
                        atendida: _senhaTemEspecial,
                        texto: 'Exigir caractere especial',
                      ),
                      const SizedBox(height: 8),
                      _itemRegraSenha(
                        atendida: _senhaTemNumero,
                        texto: 'Exigir caractere numerico',
                      ),
                      const SizedBox(height: 8),
                      _itemRegraSenha(
                        atendida: _senhaTemTamanhoValido,
                        texto:
                            'Tamanho entre $_senhaMinLength e $_senhaMaxLength caracteres',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _label('Confirme sua senha*'),
              TextField(
                controller: _confirmarSenhaController,
                obscureText: _obscureConfirmarSenha,
                enabled: !_isLoading,
                //impede a edição do campo (true)
                readOnly: !_senhaFoiPreenchida,
                onTap: () {
                  if (_senhaFoiPreenchida || _isLoading) return;

                  _mostrarMensagem(
                    'Preencha a senha antes de confirmar.',
                    isError: true,
                  );
                },
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  hint: 'Repita sua senha',
                  enabledBorderColor: _corBordaSenhas,
                  focusedBorderColor: _corBordaSenhas,
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

// ── Formatadores de entrada (máscaras aplicadas enquanto o usuário digita) ────

// Formata CPF como 000.000.000-0X em tempo real

class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {

    final rawValue = newValue.text.toUpperCase();
    //Armazena o CPF formatado
    final buffer = StringBuffer();
    var count = 0;

    for (final char in rawValue.characters) {
      if (count >= 11) break;
      
      //verifica se o caractere é um numero
      final isDigit = RegExp(r'\d').hasMatch(char);
      //Permite X apenas na ultima posição
      final isFinalX = char == 'X' && count == 10;

      if (!isDigit && !isFinalX) continue;

      //Adiciona os separadores da mascara do CPF
      if (count == 3 || count == 6) buffer.write('.');
      if (count == 9) buffer.write('-');

      //Add o Caractere valido
      buffer.write(char);
      count++;
    }

    //Converte o conteudo acumulado no buffer para uma string
    final str = buffer.toString();

    //retorna o texto formatado e posiciona o cursor no final
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

//Formata data com DD/MM/AAAA
class _DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {

    final digits = newValue.text.replaceAll(RegExp(r'\D'), ''); //so aceita digitos
    final buffer = StringBuffer(); //Buffer monta uma string aos poucos

    //Adiciona os digitos e insere as barras nas posições corretas
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();

    //Atualiza o texto formatado e adiciona o cursor no final
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

//Formata o telefone no padrao (xx) xxxxx-xxxx
class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {

    //Remove qualquer caractere que nao seja numero
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    //Monta o telefone formato aos poucos
    final buffer = StringBuffer();

    //Adiciona os digitos e insere os caracteres da mascara
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
