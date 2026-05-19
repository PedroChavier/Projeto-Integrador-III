import 'package:cloud_firestore/cloud_firestore.dart';

class Documento {
  final String id;
  final String tipo;
  final String titulo;
  final String descricao;
  final String url;
  final DateTime? updatedAt;

  Documento({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.url,
    this.updatedAt,
  });

  factory Documento.fromFirestore(String id, Map<String, dynamic> data) {
    return Documento(
      id: id,
      tipo: data['tipo'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descricao: data['descricao'] as String? ?? '',
      url: data['url'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'titulo': titulo,
      'descricao': descricao,
      'url': url,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}