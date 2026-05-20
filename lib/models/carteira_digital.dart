class CarteiraDigital {
  String? _idTitular;
  double _saldoFicticio = 0.0;

  //construtor da classe
  CarteiraDigital({String? idTitular, double saldoFicticio = 0.0})
  //Lista de inicialização: inicializa os atributos antes dos objetos terminarem de serem criados
    : _idTitular = idTitular,
      _saldoFicticio = saldoFicticio;

  // Getters para ler os valores privados
  // => Sintazxe reduzida
  String? get idTitular => _idTitular;
  double get saldoFicticio => _saldoFicticio;

  // Setters para alterar valores privados
  set idTitular(String? value) => _idTitular = value;
  set saldoFicticio(double value) => _saldoFicticio = value;

  /// Carrega saldo na carteira (saldo add pelo proprio user)
  bool carregarSaldo(double valor) {
    if (valor <= 0) return false;
    _saldoFicticio += valor;
    return true;
  }

  /// Debita saldo da carteira
  bool debitarSaldo(double valor) {
    if (valor <= 0) return false;
    if (_saldoFicticio < valor) return false;
    _saldoFicticio -= valor;
    return true;
  }

  /// Credita saldo na carteira (saldo adiciono pelo sistema)
  bool creditarSaldo(double valor) {
    if (valor <= 0) return false;
    _saldoFicticio += valor;
    return true;
  }
}
