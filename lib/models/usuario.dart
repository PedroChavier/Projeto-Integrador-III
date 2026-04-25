import 'pessoa.dart';

class Usuario extends Pessoa {
  String? _email;
  String? _senha;
  String? _telefone;
  bool _mfaHabilitado = false;

  Usuario({
    super.cpf,
    super.firstName,
    super.lastName,
    super.dataNascimento,
    String? email,
    String? senha,
    String? telefone,
    bool mfaHabilitado = false,
  }) : _email = email,
       _senha = senha,
       _telefone = telefone,
       _mfaHabilitado = mfaHabilitado;

  // Getters
  String? get email => _email;
  String? get senha => _senha;
  String? get telefone => _telefone;
  bool get mfaHabilitado => _mfaHabilitado;

  // Setters
  set email(String? value) => _email = value;
  set senha(String? value) => _senha = value;
  set telefone(String? value) => _telefone = value;
  set mfaHabilitado(bool value) => _mfaHabilitado = value;

  /// Cadastra um novo usuário
  bool cadastrarUsuario() {
    if (_email == null || _senha == null) return false;
    if (!validarCpf()) return false;
    // Lógica de cadastro seria implementada aqui
    return true;
  }

  /// Autentica o usuário
  bool autenticar(String senhaInformada) {
    if (_senha == null) return false;
    return _senha == senhaInformada;
  }

  /// Recupera a senha do usuário
  bool recuperarSenha(String novaSenha) {
    if (novaSenha.isEmpty) return false;
    _senha = novaSenha;
    return true;
  }

  /// Habilita MFA para o usuário
  void habilitarMFA() {
    _mfaHabilitado = true;
  }
}
