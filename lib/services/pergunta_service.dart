import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pergunta.dart';

class PerguntaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Pergunta>> getPerguntasStream(String idStartup) {
    return _firestore
        .collection('perguntas')
        .where('idStartup', isEqualTo: idStartup)
        .orderBy('dataEnvio', descending: true)
        .snapshots()
        .map((snapshot) {
          // ignore: avoid_print
          print('Total docs: ${snapshot.docs.length}');
          for (final doc in snapshot.docs) {
            // ignore: avoid_print
            print('Doc: ${doc.id} → ${doc.data()}');
          }
          return snapshot.docs
              .map((doc) => Pergunta.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> enviarPergunta(Pergunta pergunta) async {
    await _firestore.collection('perguntas').add(pergunta.toMap());
  }
}