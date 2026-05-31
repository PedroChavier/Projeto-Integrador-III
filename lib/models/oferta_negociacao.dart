//Pedro Andre do Carmo Chavier -25018639

import 'enums.dart'; 

//Modelo que representa uma oferta de negociação de tokens entre investidores
class OfertaNegociacao {
  String? _idInvestidor;
  String? _idToken;
  TipoOferta _tipoOferta = TipoOferta.compra;
  int _quantidadeTokens = 0;
  double _valorSugerido = 0.0;
  DateTime? _dataOferta;
  StatusOferta _status = StatusOferta.aberta;

  OfertaNegociacao({
    String? idInvestidor,
    String? idToken,
    TipoOferta tipoOferta = TipoOferta.compra,
    int quantidadeTokens = 0,
    double valorSugerido = 0.0,
  }) : _idInvestidor = idInvestidor,
       _idToken = idToken,
       _tipoOferta = tipoOferta,
       _quantidadeTokens = quantidadeTokens,
       _valorSugerido = valorSugerido,
       _dataOferta = DateTime.now(); //Pega a data atual

  // Getters
  String? get idInvestidor => _idInvestidor;
  String? get idToken => _idToken;
  TipoOferta get tipoOferta => _tipoOferta;
  int get quantidadeTokens => _quantidadeTokens;
  double get valorSugerido => _valorSugerido;
  DateTime? get dataOferta => _dataOferta;
  StatusOferta get status => _status;

  // Setters
  set idInvestidor(String? value) => _idInvestidor = value;
  set idToken(String? value) => _idToken = value;
  set tipoOferta(TipoOferta value) => _tipoOferta = value;
  set quantidadeTokens(int value) => _quantidadeTokens = value;
  set valorSugerido(double value) => _valorSugerido = value;
  set dataOferta(DateTime? value) => _dataOferta = value;
  set status(StatusOferta value) => _status = value;

  /// Registra uma nova oferta
  bool registrarOferta() {
    if (_idInvestidor == null || _idToken == null) return false;
    if (_quantidadeTokens <= 0 || _valorSugerido <= 0) return false;
    _status = StatusOferta.aberta;
    _dataOferta = DateTime.now();
    return true;
  }

  /// Cancela a oferta
  void cancelarOferta() {
    _status = StatusOferta.cancelada;
  }

  /// Conclui a transação
  bool concluirTransacao() {
    if (_status != StatusOferta.aberta) return false;
    _status = StatusOferta.concluida;
    return true;
  }
}
