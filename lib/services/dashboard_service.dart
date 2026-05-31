//Pedro Andre do Carmo Chavier -25018639

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/wallet_holding.dart';
import 'balcao_service.dart';

/// Representa o preço de um token em um momento especifico
typedef PricePoint = ({double price, DateTime at});

/// Representa uma ordem ja executada do investidor
/// Usada para reconstruir o custo de aquisição e a quantidade de tokens
class OrderExecution {
  final String startupId;
  final String side; // 'buy' | 'sell'
  final double price;
  final int qty;
  final DateTime executedAt;

  const OrderExecution({
    required this.startupId,
    required this.side,
    required this.price,
    required this.qty,
    required this.executedAt,
  });
}

/// Serviço de dados do dashboard
/// Reutiliza BalcoService para posições
class DashboardService {

  //Permite injetar dependencias custumizadas nos testes
  DashboardService({
    BalcaoService? balcaoService,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _balcaoService = balcaoService ?? BalcaoService(),
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final BalcaoService _balcaoService;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// Stream principal: holdings com preços atuais (delegado ao BalcaoService).
  Stream<List<WalletHolding>> watchHoldings() => _balcaoService.watchHoldings();

  /// Busca o historico de ordens do usuario e retorna as executadas
  Future<List<OrderExecution>> fetchExecutions() async {
    final uid = _uid;
    if (uid == null) return const [];

    final snap = await _db
        .collection('usuarios')
        .doc(uid)
        .collection('order_history')
        .orderBy('created_at')
        .get();

    final out = <OrderExecution>[];
    for (final doc in snap.docs) {
      final d = doc.data();

      // Percorre o historico de mundanças de status
      final changes = (d['status_changes'] as List?) ?? const [];
      var lastStatus = 'aberta';
      DateTime? executedAt;

      for (final c in changes) {
        if (c is! Map) continue;
        final s = c['status'] as String?;
        if (s != null) lastStatus = s;
        if (s == 'executada' && c['at'] is Timestamp) {
          executedAt = (c['at'] as Timestamp).toDate();
        }
      }

      //Ignora as ordens que nao foram executadas
      if (lastStatus != 'executada') continue;

      final startupId = (d['startup_id'] as String?) ?? '';
      final qty = (d['qty_original'] as num?)?.toInt() ?? 0;
      if (startupId.isEmpty || qty <= 0) continue;

      out.add(OrderExecution(
        startupId: startupId,
        side: (d['side'] as String?) ?? 'buy',
        price: (d['price'] as num?)?.toDouble() ?? 0,
        qty: qty,
        //
        executedAt:
            executedAt ?? (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ));
    }
    return out;
  }

  /// Calcula o custo de aquisição por startup
  Map<String, double> custoPorStartup(List<OrderExecution> execs) {
    final m = <String, double>{};
    for (final e in execs) {
      final delta = e.price * e.qty;

      //compra aumenta o custo, venda diminui
      m[e.startupId] = (m[e.startupId] ?? 0) + (e.side == 'buy' ? delta : -delta);
    }
    return m;
  }

  /// Custo total investido (base do lucro/prejuízo).
  double custoTotal(List<OrderExecution> execs) => execs.fold(
        0.0,
        (s, e) => s + (e.side == 'buy' ? e.price * e.qty : -e.price * e.qty),
      );

  /// Busca todos os negocios realizados de uma startup em ordem cronologica
  Future<List<PricePoint>> fetchTrades(String startupId) async {
    final snap = await _db
        .collection('startups')
        .doc(startupId)
        .collection('trades')
        .orderBy('executed_at')
        .get();

    final out = <PricePoint>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final price = (d['price'] as num?)?.toDouble();
      final ts = d['executed_at'];
      
      if (price == null || ts is! Timestamp) continue;
      out.add((price: price, at: ts.toDate()));
    }
    return out;
  }
}
