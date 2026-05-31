//Giovana Uchelli - 25008818

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pergunta.dart';

//Serviço responsavel pelas perguntas publicas
class PerguntaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //Escuta em tempo real as perguntas
  Stream<List<Pergunta>> getPerguntasStream(String idStartup) {
    return _firestore
        .collection('perguntas')
        .where('idStartup', isEqualTo: idStartup)
        .snapshots()
        .map((snapshot) {
          final lista = snapshot.docs
              .map((doc) => Pergunta.fromFirestore(doc.id, doc.data()))
              .where((p) => !p.privada) //Exclui perguntas do chat privado
              .toList();

          lista.sort((a, b) => a.dataEnvio.compareTo(b.dataEnvio));

          return lista;
        });
  }

  //Salva uma nova pergunta no Firestore
  Future<void> enviarPergunta(Pergunta pergunta) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Usuario nao autenticado.',
      );
    }
    final payload = pergunta.toMap();

    // sobreescreve o idAutor com o uid da sessão, 
    //para que nenhum usuario consiga postar como outro
    payload['idAutor'] = uid;
    await _firestore.collection('perguntas').add(payload);
  }
}