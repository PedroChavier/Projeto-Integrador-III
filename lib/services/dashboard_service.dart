import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/wallet_holding.dart';
import 'balcao_service.dart';

/// Ponto de preço de um token no tempo (um trade do balcão).
typedef PricePoint = ({double price, DateTime at});

/// Uma ordem do investidor já confirmada como `executada`, usada para
/// reconstruir custo de aquisição e a quantidade de tokens possuída ao
/// longo do tempo (req. 5.4 — cálculo sobre transações registradas).
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

/// Camada de dados do Dashboard. Reutiliza [BalcaoService] para as posições
/// e adiciona as leituras necessárias para reconstruir a evolução do
/// patrimônio a partir do histórico de ordens e dos trades das startups.
class DashboardService {
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

  /// Lê o histórico de ordens do usuário e devolve apenas as `executada`,
  /// com o instante real de execução (último `status_changes` com status
  /// `executada`, ou `created_at` como fallback).
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

      // Resolve último status e o instante da execução.
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
      if (lastStatus != 'executada') continue;

      final startupId = (d['startup_id'] as String?) ?? '';
      final qty = (d['qty_original'] as num?)?.toInt() ?? 0;
      if (startupId.isEmpty || qty <= 0) continue;

      out.add(OrderExecution(
        startupId: startupId,
        side: (d['side'] as String?) ?? 'buy',
        price: (d['price'] as num?)?.toDouble() ?? 0,
        qty: qty,
        executedAt:
            executedAt ?? (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ));
    }
    return out;
  }

  /// Custo de aquisição por startup: soma das compras menos as vendas
  /// executadas (`price * qty`). Chave = `startupId`.
  Map<String, double> custoPorStartup(List<OrderExecution> execs) {
    final m = <String, double>{};
    for (final e in execs) {
      final delta = e.price * e.qty;
      m[e.startupId] = (m[e.startupId] ?? 0) + (e.side == 'buy' ? delta : -delta);
    }
    return m;
  }

  /// Custo total investido (base do lucro/prejuízo).
  double custoTotal(List<OrderExecution> execs) => execs.fold(
        0.0,
        (s, e) => s + (e.side == 'buy' ? e.price * e.qty : -e.price * e.qty),
      );

  /// Trades de uma startup (preço × instante), em ordem crescente de tempo,
  /// para reconstruir o preço do token ao longo do período do gráfico.
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
