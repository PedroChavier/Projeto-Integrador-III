import 'package:cloud_firestore/cloud_firestore.dart'; //Pacote do firestore

// Modelo que representa um documento (pitch, contrato, etc.) de uma startup
class Documento {
  final String id;
  final String tipo;       // ex: "pitch", "contrato", "relatorio"
  final String titulo;
  final String descricao;
  final String url;        // link para o arquivo no Storage
  final DateTime? updatedAt;

  Documento({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.url,
    this.updatedAt, // opcional — nem todo doc tem data de atualização
  });

  // Converte um documento do Firestore em objeto Dart
  // O id vem separado do data() porque o Firestore armazena assim
  factory Documento.fromFirestore(String id, Map<String, dynamic> data) {
    return Documento(
      id: id,
      tipo: data['tipo'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descricao: data['descricao'] as String? ?? '',
      url: data['url'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(), // Timestamp do Firestore → DateTime do Dart
    );
  }

  // Converte o objeto em Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'titulo': titulo,
      'descricao': descricao,
      'url': url,
      'updatedAt': FieldValue.serverTimestamp(), // usa o relógio do servidor, não do celular
    };
  }
}