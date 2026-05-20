class WalletHolding {
  const WalletHolding({
    required this.startupUid,
    required this.startupNome,
    required this.startupSetor,
    required this.quantidade,
    required this.precoMedio,
    required this.valorInvestido,
  });

  final String startupUid;
  final String startupNome;
  final String startupSetor;
  final int quantidade;
  final double precoMedio;
  final double valorInvestido;

  double get valorAtualEstimado => quantidade * precoMedio;

  factory WalletHolding.fromMap(String startupUid, Map<String, dynamic> map) {
    return WalletHolding(
      startupUid: startupUid,
      startupNome: (map['startupNome'] as String? ?? '').trim(),
      startupSetor: (map['startupSetor'] as String? ?? '').trim(),
      quantidade: (map['quantidade'] as num?)?.toInt() ?? 0,
      precoMedio: (map['precoMedio'] as num?)?.toDouble() ?? 0,
      valorInvestido: (map['valorInvestido'] as num?)?.toDouble() ?? 0,
    );
  }
}
