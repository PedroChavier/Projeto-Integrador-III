import 'package:cloud_firestore/cloud_firestore.dart';
import 'empresa.dart';
import 'enums.dart';

class Socio {
  final String nome;
  final String percentual;
  Socio({required this.nome, required this.percentual});

  factory Socio.fromMap(Map<String, dynamic> map) {
    return Socio(
      nome: (map['Nome'] ?? map['nome'] ?? '') as String,
      percentual: (map['Percentual'] ?? map['percentual'] ?? '') as String,
    );
  }
}

class Membro {
  final String nome;
  final String cargo;
  Membro({required this.nome, required this.cargo});

  factory Membro.fromMap(Map<String, dynamic> map) {
    return Membro(
      nome: (map['Nome'] ?? map['nome'] ?? '') as String,
      cargo: (map['Cargo'] ?? map['cargo'] ?? '') as String,
    );
  }
}

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
  List<Socio> _socios = [];
  List<Membro> _membros = [];
  List<Membro> _mentores = [];

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
    List<Socio>? socios,
    List<Membro>? membros,
    List<Membro>? mentores,
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
        _linksVideos = linksVideos ?? [],
        _socios = socios ?? [],
        _membros = membros ?? [],
        _mentores = mentores ?? [];

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
  List<Socio> get socios => _socios;
  List<Membro> get membros => _membros;
  List<Membro> get mentores => _mentores;

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
  set socios(List<Socio> value) => _socios = value;
  set membros(List<Membro> value) => _membros = value;
  set mentores(List<Membro> value) => _mentores = value;

  // ── fromFirestore ─────────────────────────────────────────────
  factory Startup.fromFirestore(String uid, Map<String, dynamic> data) {
    List<Socio> parseSocios(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => Socio.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    List<Membro> parseMembros(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => Membro.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

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
      dataCriacao: (data['createdAt'] as Timestamp?)?.toDate(),
      socios: parseSocios(data['Socios'] ?? data['socios']),
      membros: parseMembros(data['Membros'] ?? data['membros']),
      mentores: parseMembros(data['Mentores'] ?? data['mentores']),
      linksVideos: List<String>.from(
          data['linksVideos'] ?? data['LinksVideos'] ?? []),
      membrosConselho: List<String>.from(
          data['membrosConselho'] ?? data['MembrosConselho'] ?? []),
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