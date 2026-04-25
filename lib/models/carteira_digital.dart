class CarteiraDigital {
  String? _idTitular;
  double _saldoFicticio = 0.0;

  CarteiraDigital({String? idTitular, double saldoFicticio = 0.0})
    : _idTitular = idTitular,
      _saldoFicticio = saldoFicticio;

  // Getters
  String? get idTitular => _idTitular;
  double get saldoFicticio => _saldoFicticio;

  // Setters
  set idTitular(String? value) => _idTitular = value;
  set saldoFicticio(double value) => _saldoFicticio = value;

  /// Carrega saldo na carteira
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

  /// Credita saldo na carteira
  bool creditarSaldo(double valor) {
    if (valor <= 0) return false;
    _saldoFicticio += valor;
    return true;
  }
}
