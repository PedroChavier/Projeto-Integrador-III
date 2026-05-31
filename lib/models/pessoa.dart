//Pedro Andre do Carmo Chavier -25018639

class Pessoa {
  String? _cpf;
  String? _fullName;
  DateTime? _dataNascimento;

  Pessoa({
    String? cpf,
    String? fullName,
    DateTime? dataNascimento,
  }) : _cpf = cpf,
       _fullName = fullName,
       _dataNascimento = dataNascimento;

  //Getters -> leitura dos atributos privados
  String? get cpf => _cpf;
  String? get fullName => _fullName;
  DateTime? get dataNascimento => _dataNascimento;

  //setters -> alteração dos atributos privados
  set cpf(String? value) => _cpf = value;
  set fullName(String? value) => _fullName = value;
  set dataNascimento(DateTime? value) => _dataNascimento = value;

  String? getCpf() => _cpf;
  void setCpf(String? value) => _cpf = value;

  String? getFullName() => _fullName;
  void setFullName(String? value) => _fullName = value;

  DateTime? getDataNascimento() => _dataNascimento;
  void setDataNascimento(DateTime? value) => _dataNascimento = value;


  int calcularIdade() {
    if (_dataNascimento == null) return 0;

    final hoje = DateTime.now();
    var idade = hoje.year - _dataNascimento!.year;

    final fezAniversarioEsteAno =
        hoje.month > _dataNascimento!.month ||
        (hoje.month == _dataNascimento!.month &&
            hoje.day >= _dataNascimento!.day);

    if (!fezAniversarioEsteAno) {
      idade--;
    }

    return idade;
  }

  bool validarCpf() {
    if (_cpf == null || _cpf!.trim().isEmpty) return false;

    final cpfNormalizado = _cpf!
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9X]'), ''); //So aceita numeros

    if (cpfNormalizado.length != 11) return false;
    if (!RegExp(r'^\d{10}[\dX]$').hasMatch(cpfNormalizado)) return false; //Garante que os 10 primeiros caracteres sejam digitos e o ultimo X
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpfNormalizado)) return false; //Receita sequencia sinvalidas (000000000)

    return true;
  }
}
