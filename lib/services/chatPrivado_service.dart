//Giovana Uchelli - 25008818

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pergunta.dart';

//serviço responsavel pelo canal privado de perguntas
class ChatPrivadoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //Escuta em tempo real as perguntas privadas
  Stream<List<Pergunta>> getPerguntasPrivadasStream({
    required String idStartup,
    required String idInvestidor,
  }) {
    return _firestore
        .collection('perguntas')
        .where('idStartup', isEqualTo: idStartup)
        .where('idAutor', isEqualTo: idInvestidor)
        .where('privada', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final lista = snap.docs
              .map((doc) => Pergunta.fromFirestore(doc.id, doc.data()))
              .toList();

          lista.sort((a, b) => a.dataEnvio.compareTo(b.dataEnvio));

          return lista;
        });
  }

  //Salva uma nova pergunta privada no Firestore
  Future<void> enviarPerguntaPrivada(Pergunta pergunta) async {
    await _firestore.collection('perguntas').add(pergunta.toMap());
  }

  
  //Verifica se o usuario é investidor
  Future<bool> isInvestidor({
    required String idStartup,
    required String idUsuario,
  }) async {
    final snap = await _firestore
        .collection('usuarios')
        .doc(idUsuario)
        .collection('positions')
        .doc(idStartup)
        .get();

    if (!snap.exists) return false;

    final data = snap.data()!;
    final livres = (data['tokens_livres'] as num?)?.toInt() ?? 0;
    final reservados = (data['tokens_reservados'] as num?)?.toInt() ?? 0;

    return (livres + reservados) > 0;
  }

  
}