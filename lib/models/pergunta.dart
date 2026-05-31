//Giovana Uchelli - 25008818

import 'package:cloud_firestore/cloud_firestore.dart';

class Pergunta {
  final String id;
  final String idAutor;
  final String nomeAutor;
  final String iniciaisAutor;
  final String idStartup;
  final String nomeStartup;
  final String textoPergunta;
  final String textoResposta;
  final DateTime dataEnvio;
  final bool privada;

  Pergunta({
    required this.id,
    required this.idAutor,
    required this.nomeAutor,
    required this.iniciaisAutor,
    required this.idStartup,
    required this.nomeStartup,
    required this.textoPergunta,
    this.textoResposta = '',
    required this.dataEnvio,
    this.privada = false,
  });

  factory Pergunta.fromFirestore(String id, Map<String, dynamic> data) {
    return Pergunta(
      id: id,
      idAutor: data['idAutor'] as String? ?? '',
      nomeAutor: data['nomeAutor'] as String? ?? 'Usuário',
      iniciaisAutor: data['iniciaisAutor'] as String? ?? '?',
      idStartup: data['idStartup'] as String? ?? '',
      nomeStartup: data['nomeStartup'] as String? ?? '',
      textoPergunta: data['textoPergunta'] as String? ?? '',
      textoResposta: data['textoResposta'] as String? ?? '',
      dataEnvio: (data['dataEnvio'] as Timestamp?)?.toDate() ?? DateTime.now(),
      privada: data['privada'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idAutor': idAutor,
      'nomeAutor': nomeAutor,
      'iniciaisAutor': iniciaisAutor,
      'idStartup': idStartup,
      'nomeStartup': nomeStartup,
      'textoPergunta': textoPergunta,
      'textoResposta': textoResposta,
      'dataEnvio': Timestamp.fromDate(dataEnvio),
      'privada': privada,
    };
  }
}