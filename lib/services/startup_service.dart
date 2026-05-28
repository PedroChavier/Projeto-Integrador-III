import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/startup.dart';

class StartupCatalogItem {
  final String uid;
  final String nome;
  final String descricao;
  final String status;
  final String tokens;
  final String capital;
  final String preco;

  const StartupCatalogItem({
    required this.uid,
    required this.nome,
    required this.descricao,
    required this.status,
    required this.tokens,
    required this.capital,
    required this.preco,
  });
}

typedef _Balcao = ({Map<String, dynamic> config, Map<String, dynamic> state});

class StartupService {
  StartupService({
    FirebaseFirestore? firestore,
    String collectionPath = 'startups',
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _collectionPath = collectionPath;

  final FirebaseFirestore _firestore;
  final String _collectionPath;

  // ── Catálogo ──────────────────────────────────────────────────
  // `balcao` é subcoleção: startups/{id}/balcao/{config|state}.
  // Pra cada startup faz raiz + config + state em paralelo.
  Future<List<StartupCatalogItem>> listarStartups() async {
    final snapshot = await _firestore.collection(_collectionPath).get();

    return Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data();
      final balcao = await _loadBalcao(doc.reference);

      final totalTokens = _readNum(balcao.config['tokens_emitidos']);
      final capitalAportado = _readNum(
        balcao.state['cptAportado'] ?? balcao.state['capitalAportado'],
      );
      final precoEmissao = _readNum(balcao.config['preco_emissao']);
      final lastPrice = _readNum(balcao.state['last_price']);
      final displayPreco = lastPrice > 0 ? lastPrice : precoEmissao;

      return StartupCatalogItem(
        uid: doc.id,
        nome: _readString(data['nome'], fallback: doc.id),
        descricao: _readString(
          data['descricao'],
          fallback: _readString(data['bio']),
        ),
        status: _normalizeStatus(
          data['status'] ?? data['estagioDesenvolvimento'] ?? data['estagio'],
        ),
        tokens: _formatCompact(totalTokens),
        capital: 'R\$ ${_formatCompact(capitalAportado)}',
        preco: 'R\$ ${displayPreco.toStringAsFixed(2).replaceAll('.', ',')}',
      );
    }));
  }

  // ── Detalhe da startup ────────────────────────────────────────
  Future<Startup?> getStartup(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection(_collectionPath).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    final data = Map<String, dynamic>.from(doc.data()!);
    final balcao = await _loadBalcao(doc.reference);

    // Mescla balcao/config|state em chaves raiz pra Startup.fromFirestore.
    if (balcao.config['preco_emissao'] != null) {
      data['precoToken'] = balcao.config['preco_emissao'];
      data['precoEmissao'] = balcao.config['preco_emissao'];
    }
    if (balcao.config['tokens_emitidos'] != null) {
      data['totalTokensEmitidos'] = balcao.config['tokens_emitidos'];
    }
    if (balcao.config['capitalMeta'] != null) {
      data['capitalMeta'] = balcao.config['capitalMeta'];
    }
    if (balcao.config['lockup_quantidade_tipo'] != null) {
      data['lockupQuantidadeTipo'] = balcao.config['lockup_quantidade_tipo'];
    }
    if (balcao.config['lockup_quantidade_valor'] != null) {
      data['lockupQuantidadeValor'] = balcao.config['lockup_quantidade_valor'];
    }
    if (balcao.config['lockup_dias_minimo'] != null) {
      data['lockupDiasMinimo'] = balcao.config['lockup_dias_minimo'];
    }
    if (balcao.state['cptAportado'] != null) {
      data['cptAportado'] = balcao.state['cptAportado'];
    }
    if (balcao.state['nmrInvestidores'] != null) {
      data['nmrInvestidores'] = balcao.state['nmrInvestidores'];
    }
    if (balcao.state['tokens_vendidos_startup'] != null) {
      data['tokensVendidos'] = balcao.state['tokens_vendidos_startup'];
    }

    final lastPrice = _readNum(balcao.state['last_price']);
    if (lastPrice > 0) data['precoToken'] = lastPrice;

    return Startup.fromFirestore(doc.id, data);
  }

  Future<_Balcao> _loadBalcao(DocumentReference docRef) async {
    final col = docRef.collection('balcao');
    final snaps = await Future.wait([
      col.doc('config').get(),
      col.doc('state').get(),
    ]);
    return (
      config: snaps[0].exists ? _toMap(snaps[0].data()) : <String, dynamic>{},
      state:  snaps[1].exists ? _toMap(snaps[1].data()) : <String, dynamic>{},
    );
  }
}

// ── Funções auxiliares ───────────────────────────────────────────
Map<String, dynamic> _toMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try { return Map<String, dynamic>.from(value); } catch (_) {}
  }
  return {};
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return fallback;
}

double _readNum(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.').trim()) ?? fallback;
  }
  return fallback;
}

String _normalizeStatus(Object? value) {
  final raw = _readString(value).toLowerCase();
  final normalized = raw
      .replaceAll('ã', 'a').replaceAll('á', 'a').replaceAll('à', 'a')
      .replaceAll('â', 'a').replaceAll('ç', 'c').replaceAll('é', 'e')
      .replaceAll('ê', 'e').replaceAll('í', 'i').replaceAll('ó', 'o')
      .replaceAll('ô', 'o').replaceAll('õ', 'o').replaceAll('ú', 'u')
      .replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');

  if (normalized.contains('operacao')) return 'Em operação';
  if (normalized.contains('expansao')) return 'Em expansão';
  return 'Nova';
}

String _formatCompact(double value) {
  final abs = value.abs();
  if (abs >= 1000000000) return '${(value / 1000000000).round()}B';
  if (abs >= 1000000) return '${(value / 1000000).round()}M';
  if (abs >= 1000) return '${(value / 1000).round()}k';
  return value.round().toString();
}
