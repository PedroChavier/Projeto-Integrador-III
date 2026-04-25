class Pergunta {
  String? _idAutor;
  String? _idStartupDestino;
  String? _textoPergunta;
  String? _textoResposta;
  bool _isPrivada = false;
  DateTime? _dataEnvio;

  Pergunta({
    String? idAutor,
    String? idStartupDestino,
    String? textoPergunta,
    bool isPrivada = false,
  }) : _idAutor = idAutor,
       _idStartupDestino = idStartupDestino,
       _textoPergunta = textoPergunta,
       _isPrivada = isPrivada,
       _dataEnvio = DateTime.now();

  // Getters
  String? get idAutor => _idAutor;
  String? get idStartupDestino => _idStartupDestino;
  String? get textoPergunta => _textoPergunta;
  String? get textoResposta => _textoResposta;
  bool get isPrivada => _isPrivada;
  DateTime? get dataEnvio => _dataEnvio;

  // Setters
  set idAutor(String? value) => _idAutor = value;
  set idStartupDestino(String? value) => _idStartupDestino = value;
  set textoPergunta(String? value) => _textoPergunta = value;
  set textoResposta(String? value) => _textoResposta = value;
  set isPrivada(bool value) => _isPrivada = value;
  set dataEnvio(DateTime? value) => _dataEnvio = value;

  /// Envia uma pergunta
  bool enviarPergunta() {
    if (_idAutor == null ||
        _idStartupDestino == null ||
        _textoPergunta == null) {
      return false;
    }
    _dataEnvio = DateTime.now();
    return true;
  }

  /// Responde a pergunta
  bool responderPergunta(String resposta) {
    if (resposta.isEmpty) return false;
    _textoResposta = resposta;
    return true;
  }

  /// Lista perguntas públicas (simplificado)
  static List<Pergunta> listarPerguntasPublicas(List<Pergunta> perguntas) {
    return perguntas.where((p) => !p.isPrivada).toList();
  }

  /// Lista perguntas privadas (simplificado)
  static List<Pergunta> listarPerguntasPrivadas(List<Pergunta> perguntas) {
    return perguntas.where((p) => p.isPrivada).toList();
  }
}
