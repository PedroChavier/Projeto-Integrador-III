import 'package:cloud_firestore/cloud_firestore.dart';
import 'empresa.dart';
import 'enums.dart';

class Socio {
  final String nome;
  final String percentual;
  Socio({required this.nome, required this.percentual});

  factory Socio.fromMap(Map<String, dynamic> map) {
    String s(dynamic v) => v is String ? v : '';
    return Socio(
      nome: s(map['Nome'] ?? map['nome']),
      percentual: s(map['Percentual'] ?? map['percentual']),
    );
  }
}

class Membro {
  final String nome;
  final String cargo;
  Membro({required this.nome, required this.cargo});

  factory Membro.fromMap(Map<String, dynamic> map) {
    String s(dynamic v) => v is String ? v : '';
    return Membro(
      nome: s(map['Nome'] ?? map['nome']),
      cargo: s(map['Cargo'] ?? map['cargo']),
    );
  }
}

class Startup extends Empresa {
  String? _uid;
  String? _sigla;
  String? _descricao;
  String? _estSocietaria;
  String? _setor;
  String? _status;
  double _cptAportado = 0.0;
  double _precoToken = 0.0;
  double _precoEmissao = 0.0;
  double _capitalMeta = 0.0;
  int _totalTokensEmitidos = 0;
  int _tokensVendidos = 0;
  int _nmrInvestidores = 0;
  EstagioDesenvolvimento _estagioDesenvolvimento = EstagioDesenvolvimento.nova;
  String? _sumarioExecutivo;
  List<String> _membrosConselho = [];
  List<String> _linksVideos = [];
  List<Socio> _socios = [];
  List<Membro> _membros = [];
  List<Membro> _mentores = [];
  String? _lockupQuantidadeTipo;
  double _lockupQuantidadeValor = 0.5;
  int _lockupDiasMinimo = 30;
  DateTime? _dataLancamento;

  Startup({
    String? uid,
    String? sigla,
    super.cnpj,
    super.nome,
    super.dataCriacao,
    String? descricao,
    int totalTokensEmitidos = 0,
    int tokensVendidos = 0,
    String? estSocietaria,
    String? setor,
    String? status,
    double cptAportado = 0.0,
    double precoToken = 0.0,
    double precoEmissao = 0.0,
    double capitalMeta = 0.0,
    int nmrInvestidores = 0,
    EstagioDesenvolvimento? estagioDesenvolvimento,
    String? sumarioExecutivo,
    List<String>? membrosConselho,
    List<String>? linksVideos,
    List<Socio>? socios,
    List<Membro>? membros,
    List<Membro>? mentores,
    String? lockupQuantidadeTipo,
    double lockupQuantidadeValor = 0.5,
    int lockupDiasMinimo = 30,
    DateTime? dataLancamento,
  })  : _uid = uid,
        _sigla = sigla,
        _descricao = descricao,
        _estSocietaria = estSocietaria,
        _setor = setor,
        _status = status,
        _cptAportado = cptAportado,
        _precoToken = precoToken,
        _precoEmissao = precoEmissao,
        _capitalMeta = capitalMeta,
        _totalTokensEmitidos = totalTokensEmitidos,
        _tokensVendidos = tokensVendidos,
        _nmrInvestidores = nmrInvestidores,
        _estagioDesenvolvimento =
            estagioDesenvolvimento ?? EstagioDesenvolvimento.nova,
        _sumarioExecutivo = sumarioExecutivo,
        _membrosConselho = membrosConselho ?? [],
        _linksVideos = linksVideos ?? [],
        _socios = socios ?? [],
        _membros = membros ?? [],
        _mentores = mentores ?? [],
        _lockupQuantidadeTipo = lockupQuantidadeTipo,
        _lockupQuantidadeValor = lockupQuantidadeValor,
        _lockupDiasMinimo = lockupDiasMinimo,
        _dataLancamento = dataLancamento;

  // ── Getters ───────────────────────────────────────────────────
  String? get uid => _uid;
  String get sigla => _sigla ?? _fallbackSigla();
  String? get descricao => _descricao;
  String? get estSocietaria => _estSocietaria;
  String? get setor => _setor;
  String? get status => _status;
  double get cptAportado => _cptAportado;
  double get precoToken => _precoToken;
  double get precoEmissao => _precoEmissao;
  double get capitalMeta => _capitalMeta;
  int get totalTokensEmitidos => _totalTokensEmitidos;
  int get tokensVendidos => _tokensVendidos;
  int get nmrInvestidores => _nmrInvestidores;
  EstagioDesenvolvimento get estagioDesenvolvimento => _estagioDesenvolvimento;
  String? get sumarioExecutivo => _sumarioExecutivo;
  List<String> get membrosConselho => _membrosConselho;
  List<String> get linksVideos => _linksVideos;
  List<Socio> get socios => _socios;
  List<Membro> get membros => _membros;
  List<Membro> get mentores => _mentores;
  String? get lockupQuantidadeTipo => _lockupQuantidadeTipo;
  double get lockupQuantidadeValor => _lockupQuantidadeValor;
  int get lockupDiasMinimo => _lockupDiasMinimo;
  DateTime? get dataLancamento => _dataLancamento;

  String _fallbackSigla() {
    final clean = (nome ?? '').replaceAll(' ', '');
    return clean.substring(0, clean.length.clamp(0, 4)).toUpperCase();
  }

  // ── Setters ───────────────────────────────────────────────────
  set uid(String? value) => _uid = value;
  set sigla(String? value) => _sigla = value;
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
    String? str(dynamic v) => v is String ? v : null;
    num toNum(dynamic v) => v is num ? v : 0;

    List<Socio> parseSocios(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) {
            try { return Socio.fromMap(Map<String, dynamic>.from(e)); }
            catch (_) { return null; }
          })
          .whereType<Socio>()
          .toList();
    }

    List<Membro> parseMembros(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) {
            try { return Membro.fromMap(Map<String, dynamic>.from(e)); }
            catch (_) { return null; }
          })
          .whereType<Membro>()
          .toList();
    }

    DateTime? createdAt;
    try {
      final ts = data['createdAt'];
      if (ts is Timestamp) createdAt = ts.toDate();
    } catch (_) {}

    DateTime? dataLancamento;
    try {
      final ts = data['data_lancamento'] ?? data['dataLancamento'];
      if (ts is Timestamp) dataLancamento = ts.toDate();
    } catch (_) {}

    return Startup(
      uid: uid,
      sigla: str(data['sigla']),
      nome: str(data['nome']),
      descricao: str(data['descricao']) ?? str(data['bio']),
      setor: str(data['setor']),
      status: str(data['status']),
      precoToken: toNum(data['precoToken'] ?? data['preco_token']).toDouble(),
      precoEmissao: toNum(data['precoEmissao'] ?? data['preco_emissao']).toDouble(),
      totalTokensEmitidos:
          toNum(data['tokensEmitidos'] ?? data['totalTokensEmitidos']).toInt(),
      tokensVendidos: toNum(data['tokensVendidos'] ?? data['tokens_vendidos_startup']).toInt(),
      nmrInvestidores: toNum(data['nmrInvestidores']).toInt(),
      cptAportado: toNum(data['cptAportado'] ?? data['capitalAportado']).toDouble(),
      capitalMeta: toNum(data['capitalMeta']).toDouble(),
      estagioDesenvolvimento:
          _parseEstagio(str(data['estagioDesenvolvimento'])),
      dataCriacao: createdAt,
      socios: parseSocios(data['Socios'] ?? data['socios']),
      membros: parseMembros(data['Membros'] ?? data['membros']),
      mentores: parseMembros(data['Mentores'] ?? data['mentores']),
      linksVideos: _parseStringList(data['linksVideos'] ?? data['LinksVideos']),
      membrosConselho: _parseStringList(data['membrosConselho'] ?? data['MembrosConselho']),
      lockupQuantidadeTipo:
          (str(data['lockupQuantidadeTipo'] ?? data['lockup_quantidade_tipo'])) ?? 'percentual',
      lockupQuantidadeValor:
          toNum(data['lockupQuantidadeValor'] ?? data['lockup_quantidade_valor'] ?? 0.5).toDouble(),
      lockupDiasMinimo:
          toNum(data['lockupDiasMinimo'] ?? data['lockup_dias_minimo'] ?? 30).toInt(),
      dataLancamento: dataLancamento,
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<String>().toList();
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