import 'package:cloud_firestore/cloud_firestore.dart';

class Documento {
  //Atributos da classe
  final String id;
  final String tipo;
  final String titulo;
  final String descricao;
  final String url;
  final DateTime? updatedAt; //Data da ultima atualização

  Documento({
    //required indica campos obrigatorios
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.url,
    this.updatedAt,
  });

  /// factory = converte dados do firestore em objeto
  /// Firestore devolve os dados em formato map
  /// Esse método transforma o Map em objeto documento
  factory Documento.fromFirestore(String id, Map<String, dynamic> data) {
    return Documento(
      //Id nao fica dentro do data(), ele vem separado
      id: id, 

      //pega o tipo, tenta converter para String, se vier null -> usa ''
      tipo: data['tipo'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descricao: data['descricao'] as String? ?? '',
      url: data['url'] as String? ?? '',
      //convertemos de timestamp para DateTime
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  //converte o objeto para um map (Firebase consegue salvar)
  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'titulo': titulo,
      'descricao': descricao,
      'url': url,

      //faz o Firestore pegar a data automaticamente usando o horario do servidor
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}