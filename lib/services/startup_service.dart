import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class StartupCatalogItem {
  final String nome;
  final String descricao;
  final String status;
  final String tokens;
  final String capital;
  final String preco;

  const StartupCatalogItem({
    required this.nome,
    required this.descricao,
    required this.status,
    required this.tokens,
    required this.capital,
    required this.preco,
  });

  factory StartupCatalogItem.fromMap(Map<String, dynamic> map) {
    return StartupCatalogItem(
      nome: _readString(map['nome']),
      descricao: _readString(map['descricao']),
      status: _readString(map['status']),
      tokens: _readString(map['tokens']),
      capital: _readString(map['capital']),
      preco: _readString(map['preco']),
    );
  }
}

class StartupService {
  StartupService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    String collectionPath = 'startups',
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _collectionPath = collectionPath;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final String _collectionPath;

  Future<List<StartupCatalogItem>> listarStartups() async {
    try {
      return await _listarViaCallable();
    } on FirebaseFunctionsException {
      return _listarDiretoFirestore();
    } catch (_) {
      return _listarDiretoFirestore();
    }
  }

  Future<List<StartupCatalogItem>> _listarViaCallable() async {
    final callable = _functions.httpsCallable('listarStartups');
    final result = await callable.call(<String, dynamic>{});
    final data = result.data as Object?;

    if (data is! Map<Object?, Object?>) {
      return const [];
    }

    final startups = data['startups'];
    if (startups is! List<Object?>) {
      return const [];
    }

    return startups
        .whereType<Map<Object?, Object?>>()
        .map((item) => StartupCatalogItem.fromMap(_toStringDynamicMap(item)))
        .toList();
  }

  Future<List<StartupCatalogItem>> _listarDiretoFirestore() async {
    final snapshot = await _firestore.collection(_collectionPath).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      final totalTokens = _readNum(
        data['totalTokensEmitidos'] ?? data['tokensEmitidos'],
      );
      final capitalAportado = _readNum(
        data['cptAportado'] ?? data['capitalAportado'],
      );
      final precoToken = _readNum(data['precoToken'] ?? data['preco_token']);

      return StartupCatalogItem(
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
        preco: 'R\$ ${precoToken.toStringAsFixed(2).replaceAll('.', ',')}',
      );
    }).toList();
  }
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

Map<String, dynamic> _toStringDynamicMap(Map<Object?, Object?> source) {
  return source.map((key, value) => MapEntry(key.toString(), value));
}

String _normalizeStatus(Object? value) {
  final raw = _readString(value).toLowerCase();
  final normalized = raw
      .replaceAll('ã', 'a')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('-', '')
      .replaceAll('_', '')
      .replaceAll(' ', '');

  if (normalized.contains('operacao')) return 'Em operação';
  if (normalized.contains('expansao')) return 'Em expansão';
  return 'Nova';
}

String _formatCompact(double value) {
  final abs = value.abs();

  if (abs >= 1000000000) {
    return '${(value / 1000000000).round()}B';
  }

  if (abs >= 1000000) {
    return '${(value / 1000000).round()}M';
  }

  if (abs >= 1000) {
    return '${(value / 1000).round()}k';
  }

  return value.round().toString();
}
