import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.positivo,
    required this.createdAt,
    required this.tipo,
    required this.fonte,
  });

  final String id;
  final String titulo;
  final String subtitulo;
  final double valor;
  final bool positivo;
  final DateTime? createdAt;
  final String tipo;
  final String fonte;

  factory WalletTransaction.fromFirestore(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.tryParse(rawCreatedAt?.toString() ?? '');

    return WalletTransaction(
      id: id,
      titulo: (map['titulo'] as String? ?? 'Transacao').trim(),
      subtitulo: (map['subtitulo'] as String? ?? '').trim(),
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      positivo: map['positivo'] as bool? ?? false,
      createdAt: createdAt,
      tipo: (map['tipo'] as String? ?? 'desconhecido').trim(),
      fonte: (map['fonte'] as String? ?? 'Desconhecido').trim(),
    );
  }
}
