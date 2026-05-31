//Pedro Andre do Carmo Chavier -25018639

//Representa a posição de um investidor em uma startup
class WalletHolding {
  const WalletHolding({
    required this.startupUid,
    required this.startupNome,
    required this.startupSigla,
    required this.startupSetor,
    required this.quantidade,
    this.quantidadeReservada = 0,
    required this.precoMedio,
    required this.valorInvestido,
    this.precoEmissao = 0,
  });

  final String startupUid;
  final String startupNome;
  final String startupSigla;
  final String startupSetor;
  final int quantidade;
  final int quantidadeReservada;
  final double precoMedio;
  final double valorInvestido;
  final double precoEmissao;


  int get quantidadeTotal => quantidade + quantidadeReservada;

  double get valorAtualEstimado => quantidadeTotal * precoMedio;

  //Variação percentual entre o preço médio e preço de emissao
  double get variacaoEmissao {
    if (precoEmissao <= 0) return 0;
    return ((precoMedio - precoEmissao) / precoEmissao) * 100;
  }

  //Transforma o objeto vindo do firestore em um objeto dart(map)
  factory WalletHolding.fromMap(String startupUid, Map<String, dynamic> map) {
    return WalletHolding(
      startupUid: startupUid,
      startupNome: (map['startupNome'] as String? ?? '').trim(),
      startupSigla: (map['startupSigla'] as String? ?? '').trim(),
      startupSetor: (map['startupSetor'] as String? ?? '').trim(),
      quantidade: (map['quantidade'] as num?)?.toInt() ?? 0,
      precoMedio: (map['precoMedio'] as num?)?.toDouble() ?? 0,
      valorInvestido: (map['valorInvestido'] as num?)?.toDouble() ?? 0,
    );
  }
}
