import 'package:flutter/foundation.dart';

class Order {
  final String id;
  final String side; // 'buy' ou 'sell'
  final String type; // 'market' ou 'limit'
  double price;
  int qtyOriginal;
  int qty;
  bool mine;
  bool isStartup;
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

  bool get isPartial => qtyOriginal > qty && qty > 0;
}

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

  double get brlDisponivel => (brl - brlReserved).clamp(0, double.infinity);
}

class Startup {
  final String id;
  final String nome;
  final String sigla;
  final double precoEmissao;
  double? lastPrice;
  final int tokensEmitidos;

  Startup({
    required this.id,
    required this.nome,
    required this.sigla,
    required this.precoEmissao,
    this.lastPrice,
    required this.tokensEmitidos,
  });

  double get displayPrice => lastPrice ?? precoEmissao;

  double get variation {
    if (lastPrice == null) return 0;
    return ((lastPrice! - precoEmissao) / precoEmissao) * 100;
  }

  String get variationText {
    if (lastPrice == null) return 'preco de emissao';
    final v = variation;
    return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
  }
}

class OrderbookState extends ChangeNotifier {
  late Wallet wallet;
  late Startup currentStartup;

  List<Order> buyBook = [];
  List<Order> sellBook = [];
  List<Trade> trades = [];

  Set<String> myOrderIds = {};

  // Tracks startup tokens sold (from remote state)
  int remoteTokensVendidos = 0;

  String currentTab = 'buy';
  String orderType = 'market';
  double inputPrice = 0;
  int inputQty = 0;

  OrderbookState({required this.wallet, required this.currentStartup});

  // ── Remote updates ────────────────────────────────────────────────────────

  void updateBuyBook(List<Order> orders) {
    buyBook = orders;
    myOrderIds = {
      ...myOrderIds.where((id) => sellBook.any((o) => o.id == id)),
      ...orders.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners();
  }

  void updateSellBook(List<Order> orders) {
    sellBook = orders;
    myOrderIds = {
      ...myOrderIds.where((id) => buyBook.any((o) => o.id == id)),
      ...orders.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners();
  }

  void updateBothBooks(List<Order> buys, List<Order> sells) {
    buyBook = buys;
    sellBook = sells;
    myOrderIds = {
      ...buys.where((o) => o.mine).map((o) => o.id),
      ...sells.where((o) => o.mine).map((o) => o.id),
    };
    notifyListeners();
  }

  void updateTrades(List<Trade> remoteTrades) {
    trades = remoteTrades;
    notifyListeners();
  }

  void updateWallet(Wallet w) {
    wallet = Wallet(
      brl: w.brl,
      brlReserved: w.brlReserved,
      tokens: wallet.tokens,
      tokensReserved: wallet.tokensReserved,
    );
    notifyListeners();
  }

  void updatePosition(int tokensLivres, int tokensReservados) {
    wallet = Wallet(
      brl: wallet.brl,
      brlReserved: wallet.brlReserved,
      tokens: tokensLivres,
      tokensReserved: tokensReservados,
    );
    notifyListeners();
  }

  void updateStartupState(double? lastPrice, int tokensVendidos) {
    currentStartup.lastPrice = lastPrice;
    remoteTokensVendidos = tokensVendidos;
    notifyListeners();
  }

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
    notifyListeners();
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  List<Order> get sortedBuyBook {
    final sorted = [...buyBook];
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }

  List<Order> get sortedSellBook {
    final sorted = [...sellBook];
    sorted.sort((a, b) => a.price.compareTo(b.price));
    return sorted;
  }

  Order? get bestBid => sortedBuyBook.isNotEmpty ? sortedBuyBook.first : null;
  Order? get bestAsk => sortedSellBook.isNotEmpty ? sortedSellBook.first : null;

  double get spread {
    final bid = bestBid?.price;
    final ask = bestAsk?.price;
    if (bid == null || ask == null) return 0;
    return ask - bid;
  }

  int get startupTokensVendidos => remoteTokensVendidos;

  double get startupSaleProgress {
    if (currentStartup.tokensEmitidos == 0) return 0;
    return (startupTokensVendidos / currentStartup.tokensEmitidos).clamp(0.0, 1.0);
  }

  int get totalBidVolume => buyBook.fold(0, (total, order) => total + order.qty);
  int get totalAskVolume => sellBook.fold(0, (total, order) => total + order.qty);

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

  double? estimateAverageMarketPrice(String side, int qty) {
    final total = estimateMarketTotal(side, qty);
    if (total == null || qty <= 0) return null;
    return total / qty;
  }

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

  int availableMarketQty(String side) {
    final book = side == 'buy' ? sortedSellBook : sortedBuyBook;
    return book.fold(0, (total, order) => total + order.qty);
  }

  void setTab(String tab) {
    currentTab = tab;
    notifyListeners();
  }

  void setOrderType(String type) {
    orderType = type;
    notifyListeners();
  }

  String formatPrice(double price) {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String formatQty(int qty) {
    return qty.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        );
  }
}
