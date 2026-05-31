//Giovana Uchelli - 25008818

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/documento.dart';

class DocumentoService {
  final _db = FirebaseFirestore.instance;

  /// Busca os documentos públicos de uma startup.
  Future<List<Documento>> getDocumentos(String startupId) async {
    final startupSnap = await _db.collection('startups').doc(startupId).get();

    final docMap = startupSnap.data()?['documentos'];
    if (docMap is Map && docMap.isNotEmpty) {
      return docMap.entries
          .where((e) => e.value is Map)
          .map((e) => Documento.fromFirestore(
                e.key.toString(),
                Map<String, dynamic>.from(e.value as Map),
              ))
          .toList();
    }

    // Fallback: sub-collection
    final snap = await _db
        .collection('startups')
        .doc(startupId)
        .collection('documentos')
        .get();

    return snap.docs
        .map((doc) => Documento.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Retorna true se o usuário tem tokens nesta startup específica.
  Future<bool> isInvestidor(String startupId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final snap = await _db
        .collection('usuarios')
        .doc(uid)
        .collection('positions')
        .doc(startupId)
        .get();

    if (!snap.exists) return false;

    final data = snap.data()!;
    final livres = (data['tokens_livres'] as num?)?.toInt() ?? 0;
    final reservados = (data['tokens_reservados'] as num?)?.toInt() ?? 0;

    return (livres + reservados) > 0;
  }

  /// Busca o documento exclusivo da startup (tipo: relatorio_financeiro).
  Future<Documento?> getDocumentoExclusivo(String startupId) async {
  // Tenta primeiro no mapa embutido
  final snap = await _db.collection('startups').doc(startupId).get();
  final docMap = snap.data()?['documentos'];

  if (docMap is Map) {
    //percorre cada chave + valor do mapa vindo do Firestore
    for (final e in docMap.entries.cast<MapEntry<dynamic, dynamic>>()) {
      if (e.key == 'relatorio_financeiro' && e.value is Map) {
        return Documento.fromFirestore(
          e.key.toString(),
          Map<String, dynamic>.from(e.value as Map),
        );
      }
    }
  }

  // Fallback: busca na sub-coleção pelo campo 'tipo'
  final subSnap = await _db
      .collection('startups')
      .doc(startupId)
      .collection('documentos')
      .where('tipo', isEqualTo: 'relatorio_financeiro')
      .limit(1)
      .get();

  if (subSnap.docs.isEmpty) return null;
  final doc = subSnap.docs.first;
  return Documento.fromFirestore(doc.id, doc.data());
}
}