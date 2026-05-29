import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pergunta.dart';

class PerguntaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Pergunta>> getPerguntasStream(String idStartup) {
    return _firestore
        .collection('perguntas')
        .where('idStartup', isEqualTo: idStartup)
        .snapshots()
        .map((snapshot) {
          final lista = snapshot.docs
              .map((doc) => Pergunta.fromFirestore(doc.id, doc.data()))
              .where((p) => !p.privada)
              .toList();

          lista.sort((a, b) => a.dataEnvio.compareTo(b.dataEnvio));

          return lista;
        });
  }

  Future<void> enviarPergunta(Pergunta pergunta) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Usuario nao autenticado.',
      );
    }
    final payload = pergunta.toMap();
    // Defense in depth: sobrescreve idAutor do payload com o uid autenticado.
    // Firestore rule tambem valida, mas garantimos consistencia no cliente.
    payload['idAutor'] = uid;
    await _firestore.collection('perguntas').add(payload);
  }
}