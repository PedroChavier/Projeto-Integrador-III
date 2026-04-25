import 'empresa.dart';
import 'enums.dart';

class Startup extends Empresa {
  String? _descricao;
  String? _estSocietaria;
  double _cptAportado = 0.0;
  int _totalTokensEmitidos = 0;
  EstagioDesenvolvimento _estagioDesenvolvimento = EstagioDesenvolvimento.nova;
  String? _sumarioExecutivo;
  List<String> _membrosConselho = [];
  List<String> _linksVideos = [];

  Startup({
    super.cnpj,
    super.nome,
    super.dataCriacao,
    String? descricao,
    int totalTokensEmitidos = 0,
    String? estSocietaria,
    double cptAportado = 0.0,
    EstagioDesenvolvimento? estagioDesenvolvimento,
    String? sumarioExecutivo,
    List<String>? membrosConselho,
    List<String>? linksVideos,
  }) : _descricao = descricao,
       _estSocietaria = estSocietaria,
       _cptAportado = cptAportado,
       _totalTokensEmitidos = totalTokensEmitidos,
       _estagioDesenvolvimento =
           estagioDesenvolvimento ?? EstagioDesenvolvimento.nova,
       _sumarioExecutivo = sumarioExecutivo,
       _membrosConselho = membrosConselho ?? [],
       _linksVideos = linksVideos ?? [];

  // Getters
  String? get descricao => _descricao;
  String? get estSocietaria => _estSocietaria;
  double get cptAportado => _cptAportado;
  int get totalTokensEmitidos => _totalTokensEmitidos;
  EstagioDesenvolvimento get estagioDesenvolvimento => _estagioDesenvolvimento;
  String? get sumarioExecutivo => _sumarioExecutivo;
  List<String> get membrosConselho => _membrosConselho;
  List<String> get linksVideos => _linksVideos;

  // Setters
  set descricao(String? value) => _descricao = value;
  set estSocietaria(String? value) => _estSocietaria = value;
  set cptAportado(double value) => _cptAportado = value;
  set totalTokensEmitidos(int value) => _totalTokensEmitidos = value;
  set estagioDesenvolvimento(EstagioDesenvolvimento value) =>
      _estagioDesenvolvimento = value;
  set sumarioExecutivo(String? value) => _sumarioExecutivo = value;
  set membrosConselho(List<String> value) => _membrosConselho = value;
  set linksVideos(List<String> value) => _linksVideos = value;

  /// Calcula a participação dos sócios
  double calcularParticipacaoSocios() {
    if (_totalTokensEmitidos == 0) return 0.0;
    return (_cptAportado / _totalTokensEmitidos) * 100;
  }
}
