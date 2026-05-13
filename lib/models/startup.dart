import 'package:cloud_firestore/cloud_firestore.dart';
import 'empresa.dart';
import 'enums.dart';

class Startup extends Empresa {
  String? _uid;
  String? _descricao;
  String? _estSocietaria;
  String? _setor;
  String? _status;
  double _cptAportado = 0.0;
  double _precoToken = 0.0;
  double _capitalMeta = 0.0;
  int _totalTokensEmitidos = 0;
  int _nmrInvestidores = 0;
  EstagioDesenvolvimento _estagioDesenvolvimento = EstagioDesenvolvimento.nova;
  String? _sumarioExecutivo;
  List<String> _membrosConselho = [];
  List<String> _linksVideos = [];

  Startup({
    String? uid,
    super.cnpj,
    super.nome,
    super.dataCriacao,
    String? descricao,
    int totalTokensEmitidos = 0,
    String? estSocietaria,
    String? setor,
    String? status,
    double cptAportado = 0.0,
    double precoToken = 0.0,
    double capitalMeta = 0.0,
    int nmrInvestidores = 0,
    EstagioDesenvolvimento? estagioDesenvolvimento,
    String? sumarioExecutivo,
    List<String>? membrosConselho,
    List<String>? linksVideos,
  })  : _uid = uid,
        _descricao = descricao,
        _estSocietaria = estSocietaria,
        _setor = setor,
        _status = status,
        _cptAportado = cptAportado,
        _precoToken = precoToken,
        _capitalMeta = capitalMeta,
        _totalTokensEmitidos = totalTokensEmitidos,
        _nmrInvestidores = nmrInvestidores,
        _estagioDesenvolvimento =
            estagioDesenvolvimento ?? EstagioDesenvolvimento.nova,
        _sumarioExecutivo = sumarioExecutivo,
        _membrosConselho = membrosConselho ?? [],
        _linksVideos = linksVideos ?? [];

  // ── Getters ───────────────────────────────────────────────────
  String? get uid => _uid;
  String? get descricao => _descricao;
  String? get estSocietaria => _estSocietaria;
  String? get setor => _setor;
  String? get status => _status;
  double get cptAportado => _cptAportado;
  double get precoToken => _precoToken;
  double get capitalMeta => _capitalMeta;
  int get totalTokensEmitidos => _totalTokensEmitidos;
  int get nmrInvestidores => _nmrInvestidores;
  EstagioDesenvolvimento get estagioDesenvolvimento => _estagioDesenvolvimento;
  String? get sumarioExecutivo => _sumarioExecutivo;
  List<String> get membrosConselho => _membrosConselho;
  List<String> get linksVideos => _linksVideos;

  // ── Setters ───────────────────────────────────────────────────
  set uid(String? value) => _uid = value;
  set descricao(String? value) => _descricao = value;
  set estSocietaria(String? value) => _estSocietaria = value;
  set setor(String? value) => _setor = value;
  set status(String? value) => _status = value;
  set cptAportado(double value) => _cptAportado = value;
  set precoToken(double value) => _precoToken = value;
  set capitalMeta(double value) => _capitalMeta = value;
  set totalTokensEmitidos(int value) => _totalTokensEmitidos = value;
  set nmrInvestidores(int value) => _nmrInvestidores = value;
  set estagioDesenvolvimento(EstagioDesenvolvimento value) =>
      _estagioDesenvolvimento = value;
  set sumarioExecutivo(String? value) => _sumarioExecutivo = value;
  set membrosConselho(List<String> value) => _membrosConselho = value;
  set linksVideos(List<String> value) => _linksVideos = value;

  // ── fromFirestore ─────────────────────────────────────────────
  factory Startup.fromFirestore(String uid, Map<String, dynamic> data) {
    return Startup(
      uid: uid,
      nome: data['nome'] as String?,
      descricao: data['descricao'] as String? ?? data['bio'] as String?,
      setor: data['setor'] as String?,
      status: data['status'] as String?,
      precoToken: (data['precoToken'] ?? data['preco_token'] ?? 0).toDouble(),
      totalTokensEmitidos:
          (data['tokensEmitidos'] ?? data['totalTokensEmitidos'] ?? 0) as int,
      nmrInvestidores: (data['nmrInvestidores'] ?? 0) as int,
      cptAportado:
          (data['cptAportado'] ?? data['capitalAportado'] ?? 0).toDouble(),
      capitalMeta: (data['capitalMeta'] ?? 0).toDouble(),
      estagioDesenvolvimento:
          _parseEstagio(data['estagioDesenvolvimento'] as String?),
      linksVideos: List<String>.from(data['linksVideos'] ?? []),
      membrosConselho: List<String>.from(data['membrosConselho'] ?? []),
      dataCriacao: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static EstagioDesenvolvimento _parseEstagio(String? valor) {
    switch (valor) {
      case 'emOperacao':
        return EstagioDesenvolvimento.emOperacao;
      case 'emExpansao':
        return EstagioDesenvolvimento.emExpansao;
      default:
        return EstagioDesenvolvimento.nova;
    }
  }

  // ── Métodos ───────────────────────────────────────────────────
  double calcularParticipacaoSocios() {
    if (_totalTokensEmitidos == 0) return 0.0;
    return (_cptAportado / _totalTokensEmitidos) * 100;
  }

  double get metaCapital =>
      _capitalMeta > 0 ? _capitalMeta : _totalTokensEmitidos * _precoToken;

  double get progressoCapital {
    if (metaCapital == 0) return 0;
    return (_cptAportado / metaCapital).clamp(0.0, 1.0);
  }
}