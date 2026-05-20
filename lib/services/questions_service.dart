import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pergunta.dart';

class PerguntaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Pergunta>> getPerguntasStream(String idStartup) {
  return _firestore
      .collection('perguntas')
      .where('idStartup', isEqualTo: idStartup)
      .snapshots()
      .map((snapshot) {
        // ignore: avoid_print
        return snapshot.docs
            .map((doc) => Pergunta.fromFirestore(doc.id, doc.data()))
            .toList();
      });
}

  Future<void> enviarPergunta(Pergunta pergunta) async {
    await _firestore.collection('perguntas').add(pergunta.toMap());
  }
}