class Token {
  String? _idToken;
  String? _idStartup;
  double _valorAtual = 0.0;
  double _valorAnterior = 0.0;

  Token({String? idToken, String? idStartup, double valorAtual = 0.0})
    : _idToken = idToken,
      _idStartup = idStartup,
      _valorAtual = valorAtual,
      _valorAnterior = valorAtual;

  // Getters
  String? get idToken => _idToken;
  String? get idStartup => _idStartup;
  double get valorAtual => _valorAtual;

  // Setters
  set idToken(String? value) => _idToken = value;
  set idStartup(String? value) => _idStartup = value;
  set valorAtual(double value) {
    _valorAnterior = _valorAtual;
    _valorAtual = value;
  }

  /// Calcula variação diária (simplificado)
  double calcularVariacaoDiaria() {
    if (_valorAnterior == 0) return 0.0;
    return ((_valorAtual - _valorAnterior) / _valorAnterior) * 100;
  }

  /// Calcula variação semanal (simplificado)
  double calcularVariacaoSemanal() {
    // Em uma implementação real, seria comparado com valor de 7 dias atrás
    return calcularVariacaoDiaria();
  }

  /// Calcula variação mensal (simplificado)
  double calcularVariacaoMensal() {
    // Em uma implementação real, seria comparado com valor de 30 dias atrás
    return calcularVariacaoDiaria();
  }

  /// Calcula variação semestral (simplificado)
  double calcularVariacaoSemestral() {
    // Em uma implementação real, seria comparado com valor de 6 meses atrás
    return calcularVariacaoDiaria();
  }

  /// Calcula variação YTD (Year to Date)
  double calcularVariacaoYTD() {
    // Em uma implementação real, seria comparado com valor do início do ano
    return calcularVariacaoDiaria();
  }
}
