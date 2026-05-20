import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/documento.dart';

class DocumentoService {
  final _db = FirebaseFirestore.instance;

  /// Busca os documentos públicos de uma startup
  Future<List<Documento>> getDocumentos(String startupId) async {
  final snap = await _db
      .collection('startups')
      .doc(startupId)
      .collection('documentos')
      .get();

  

  return snap.docs
      .map((doc) => Documento.fromFirestore(doc.id, doc.data()))
      .toList();
}
}