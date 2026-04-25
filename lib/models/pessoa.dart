class Pessoa {
  String? _cpf;
  String? _firstName;
  String? _lastName;
  DateTime? _dataNascimento;

  Pessoa({
    String? cpf,
    String? firstName,
    String? lastName,
    DateTime? dataNascimento,
  }) : _cpf = cpf,
       _firstName = firstName,
       _lastName = lastName,
       _dataNascimento = dataNascimento;

  // Getters
  String? get cpf => _cpf;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  DateTime? get dataNascimento => _dataNascimento;

  // Setters
  set cpf(String? value) => _cpf = value;
  set firstName(String? value) => _firstName = value;
  set lastName(String? value) => _lastName = value;
  set dataNascimento(DateTime? value) => _dataNascimento = value;

  /// Calcula a idade based on data de nascimento
  int calcularIdade() {
    if (_dataNascimento == null) return 0;
    final hoje = DateTime.now();
    int idade = hoje.year - _dataNascimento!.year;
    if (hoje.month < _dataNascimento!.month ||
        (hoje.month == _dataNascimento!.month &&
            hoje.day < _dataNascimento!.day)) {
      idade--;
    }
    return idade;
  }

  /// Retorna o nome completo
  String getNomeCompleto() {
    return '${_firstName ?? ''} ${_lastName ?? ''}'.trim();
  }

  /// Valida CPF (simplificado - apenas verifica se tem 11 dígitos)
  bool validarCpf() {
    if (_cpf == null || _cpf!.isEmpty) return false;
    // Remove caracteres não numéricos
    final cpfNumeros = _cpf!.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpfNumeros.length != 11) return false;
    // Verifica se todos os dígitos são iguais (CPF inválido)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpfNumeros)) return false;
    return true;
  }
}
