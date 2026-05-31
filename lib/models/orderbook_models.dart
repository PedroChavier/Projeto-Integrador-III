//Pedro Andre do Carmo Chavier -25018639

import 'package:flutter/foundation.dart'; //Usado para ChangeNotifier - permite noficar a tela quando os dados mudam

//Representa uma ordem aberta no book
class Order {
  final String id;
  final String side; // 'buy' ou 'sell'
  final String type; // 'market' ou 'limit'
  double price;
  int qtyOriginal;
  int qty;
  bool mine; //true se pertence ao usuario logado
  bool isStartup; //true se quem vende é a propria startup
  String? status; // 'aberta', 'parcialmente_executada', 'executada'

  Order({
    required this.id,
    required this.side,
    required this.type,
    required this.price,
    required this.qtyOriginal,
    required this.qty,
    this.mine = false,
    this.isStartup = false,
    this.status = 'aberta',
  });

  //true se a ordem ja foi executada, mas ainda tem quantidade restante
  bool get isPartiallyExecuted => qtyOriginal > qty && qty > 0;
}

//Representa uma negociação ja executada
class Trade {
  final String time;
  final String side; // 'compra' ou 'venda'
  final double price;
  final int qty;

  Trade({
    required this.time,
    required this.side,
    required this.price,
    required this.qty,
  });
}

//Representa a carteira do usuario
class Wallet {
  double brl;
  double brlReserved;
  int tokens;
  int tokensReserved;

  Wallet({
    required this.brl,
    this.brlReserved = 0,
    required this.tokens,
    required this.tokensReserved,
  });


  double get brlDisponivel => (brl - brlReserved).clamp(0, double.infinity); //Clamp garante que nuca fique negativo
}

//Representa uma startup e suas configurações de balcão
class Startup {
  final String id;
  final String nome;
  final String sigla;
  final double precoEmissao;
  double? lastPrice;
  final int tokensEmitidos;
  final String? lockupQuantidadeTipo; // 'percentual' | 'absoluto'
  final double lockupQuantidadeValor; // decimal (0.5 = 50%) ou absoluto
  final int lockupDiasMinimo;
  final bool lockupDesabilitado;
  final DateTime? dataLancamento;

  Startup({
    required this.id,
    required this.nome,
    required this.sigla,
    required this.precoEmissao,
    this.lastPrice,
    required this.tokensEmitidos,
    this.lockupQuantidadeTipo = 'percentual',
    this.lockupQuantidadeValor = 0.5,
    this.lockupDiasMinimo = 30,
    this.lockupDesabilitado = false,
    this.dataLancamento,
  });

  //Exibe o ultimo valor se ja houve trade
  double get displayPrice => lastPrice ?? precoEmissao;

  //Variação entre o ultimo preço e preço de emissao
  double get variation {
    if (lastPrice == null) return 0;
    return ((lastPrice! - precoEmissao) / precoEmissao) * 100;
  }

  //Formata a variação como String
  String get variationText {
    if (lastPrice == null) return 'preco de emissao';
    final v = variation;
    return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }
}

//Estado do balcao
//Change notifier para avisar a tela quando algo mudou
class OrderbookState extends ChangeNotifier {
  late Wallet wallet;
  late Startup currentStartup;

  List<Order> buyBook = []; //ordens de compras
  List<Order> sellBook = []; //ordens de vendas
  List<Trade> trades = []; // historico de trades executadas

  Set<String> myOrderIds = {}; 

  int remoteTokensVendidos = 0;

  String currentTab = 'buy';
  String orderType = 'market';
  double inputPrice = 0;
  int inputQty = 0;

  OrderbookState({required this.wallet, required this.currentStartup});


  //Atualiza o book de compras e recalcula quais ordens sao minhas
  void updateBuyBook(List<Order> orders) {
    buyBook = orders;
    myOrderIds = {
      ...myOrderIds.where((id) => sellBook.any((o) => o.id == id)),
      ...orders.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners(); //avisa a tela para reconstruir
  }

  //Atualiza o book de vendas e recalcula quais ordens sao minhas
  void updateSellBook(List<Order> orders) {
    sellBook = orders;
    myOrderIds = {
      ...myOrderIds.where((id) => buyBook.any((o) => o.id == id)),
      ...orders.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners();
  }

  //Atualiza os dos books 
  void updateBothBooks(List<Order> buys, List<Order> sells) {
    buyBook = buys;
    sellBook = sells;
    myOrderIds = {
      ...buys.where((o) => o.mine).map((o) => o.id),
      ...sells.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners(); //avisa a tela para reconstruir
  }

  void updateTrades(List<Trade> remoteTrades) {
    trades = remoteTrades;
    notifyListeners();
  }

  //Atualiza apenas o salvo BRL
  void updateWallet(Wallet w) {
    wallet = Wallet(
      brl: w.brl,
      brlReserved: w.brlReserved,
      tokens: wallet.tokens,
      tokensReserved: wallet.tokensReserved,
    );
    notifyListeners();
  }

  //Atualiza tokens do usuario para a startup atual
  void updatePosition(int tokensLivres, int tokensReservados) {
    wallet = Wallet(
      brl: wallet.brl,
      brlReserved: wallet.brlReserved,
      tokens: tokensLivres,
      tokensReserved: tokensReservados,
    );
    notifyListeners();
  }

  //Atualiza ultimo preço e tokens vendidos quando o Firestore emite novo estado
  void updateStartupState(double? lastPrice, int tokensVendidos) {
    currentStartup.lastPrice = lastPrice;
    remoteTokensVendidos = tokensVendidos;
    notifyListeners();
  }

  //Muda a startup antiga e zera todos os dados do book anterior
  void changeStartup(Startup startup) {
    currentStartup = startup;
    buyBook = [];
    sellBook = [];
    trades = [];
    myOrderIds = {};
    remoteTokensVendidos = 0;
    inputPrice = 0;
    inputQty = 0;
    wallet.tokens = 0;
    wallet.tokensReserved = 0;
    notifyListeners(); //Avisa que a tela mudou e precisa recontrtuir
  }

  //Getters computados (calculados na hora, nao armazenados)

  //Book de compras ondedado do maior para o menor preço
  List<Order> get sortedBuyBook {
    final sorted = [...buyBook]; //Copia para nao alterar o original
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }

  //Book de venda ordenado do menor para o maior preço
  List<Order> get sortedSellBook {
    final sorted = [...sellBook];
    sorted.sort((a, b) => a.price.compareTo(b.price));
    return sorted;
  }

  //Melhor ordem de compra (maior preço)
  Order? get bestBid => sortedBuyBook.isNotEmpty ? sortedBuyBook.first : null;
  //Melhor ordem de venda (menor preço)
  Order? get bestAsk => sortedSellBook.isNotEmpty ? sortedSellBook.first : null;


  //Diferença entre o menor ask e o maior bid
  double get spread {
    final bid = bestBid?.price;
    final ask = bestAsk?.price;
    if (bid == null || ask == null) return 0;
    return ask - bid;
  }

  int get startupTokensVendidos => remoteTokensVendidos;

  //Percentual de tokens vendidos pela startup
  double get startupSaleProgress {
    if (currentStartup.tokensEmitidos == 0) return 0;
    return (startupTokensVendidos / currentStartup.tokensEmitidos).clamp(0.0, 1.0);
  }

  //Volume total disponivel no book de compras e vendas
  int get totalBidVolume => buyBook.fold(0, (total, order) => total + order.qty);
  int get totalAskVolume => sellBook.fold(0, (total, order) => total + order.qty);


  //Estima o custo total de uma market order
  double? estimateMarketTotal(String side, int qty) {
    if (qty <= 0) return null;
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    if (book.isEmpty) return null;

    var remaining = qty;
    var total = 0.0;
    for (final order in book) {
      final take = remaining < order.qty ? remaining : order.qty;
      total += take * order.price;
      remaining -= take;
      if (remaining <= 0) return total;
    }
    return null; // insufficient volume
  }

  //Preço medio estimado de uma market ordem (total/quantidade)
  double? estimateAverageMarketPrice(String side, int qty) {
    final total = estimateMarketTotal(side, qty);
    if (total == null || qty <= 0) return null;
    return total / qty;
  }

  //Quantos toekens é possivel comprar/vender com um valor 
  int estimateMarketQtyForValue(String side, double amount) {
    if (amount <= 0) return 0;
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    if (book.isEmpty) return 0;

    var remaining = amount;
    var qty = 0;
    for (final order in book) {
      final fullLevelCost = order.qty * order.price;
      if (remaining >= fullLevelCost) {
        qty += order.qty;
        remaining -= fullLevelCost;
        continue;
      }

      qty += (remaining / order.price).floor();
      break;
    }
    return qty;
  }

  //Total de tokens disponiveis no book
  int availableMarketQty(String side) {
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    return book.fold(0, (total, order) => total + order.qty);
  }

  //Muda a aba ativa (comra/venda)
  void setTab(String tab) {
    currentTab = tab;
    notifyListeners(); //Notifica a tela
  }

  //Muda o tipo de ordem (market/limite)
  void setOrderType(String type) {
    orderType = type;
    notifyListeners();
  }

  //Formata o preco para moeda brasileira
  String formatPrice(double price) {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  //Formata inteiro 
  String formatQty(int qty) {
    return qty.toString().replaceAllMapped( //Substitui o texto usando logica
          RegExp(r'\B(?=(\d{3})+(?!\d))'), //A cada 3 digitos da direita, insere um .
          (match) => '.',
        );
  }
}
