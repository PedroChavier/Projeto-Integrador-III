class Empresa {
  String? _cnpj;
  String? _nome;
  DateTime? _dataCriacao;

  Empresa({String? cnpj, String? nome, DateTime? dataCriacao})
    : _cnpj = cnpj,
      _nome = nome,
      _dataCriacao = dataCriacao;

  // Getters
  String? get cnpj => _cnpj;
  String? get nome => _nome;
  DateTime? get dataCriacao => _dataCriacao;

  // Setters
  set cnpj(String? value) => _cnpj = value;
  set nome(String? value) => _nome = value;
  set dataCriacao(DateTime? value) => _dataCriacao = value;
}
