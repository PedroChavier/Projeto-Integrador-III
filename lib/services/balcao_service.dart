//Pedro Andre do Carmo Chavier -25018639

import 'dart:convert'; //Fornece [jsonDecode], usado para interpretar mensagens de erro das cloud functions

import 'package:cloud_firestore/cloud_firestore.dart' hide Order; // Importa tudo, execeto a classe order
import 'package:cloud_functions/cloud_functions.dart'; //Execução de funções no servidor Firebase
import 'package:firebase_auth/firebase_auth.dart'; //autenticação de usuarios via Fireabse

import '../models/orderbook_models.dart';
import '../models/wallet_holding.dart';

//Serviço responsavel por todas as operações do balcão de negociação
class BalcaoService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1'); //aponta para a regiao de sao paulo

  String? get _uid => _auth.currentUser?.uid; 

  // Busca todas as startups cadastradas
  Future<List<Startup>> fetchStartups() async {
    final snap = await _db.collection('startups').get();

    return Future.wait(snap.docs.map((doc) async { //Future.wait executa varias operações assincronas em paralelo
      final d = doc.data();

      //Carrega configuração e estatdo
      final (cfg, st) = await _loadBalcao(doc.reference);

      final nome = (d['nome'] as String?) ?? doc.id;
      final siglaRaw = d['sigla'] as String?;
      final sigla = (siglaRaw != null && siglaRaw.isNotEmpty)
          ? siglaRaw
          : nome
              .replaceAll(' ', '')
              .substring(0, nome.replaceAll(' ', '').length.clamp(0, 4)) // primeiras 4 letras do nome
              .toUpperCase();

      return Startup(
        id: doc.id,
        nome: nome,
        sigla: sigla,
        precoEmissao: (cfg['preco_emissao'] as num?)?.toDouble() ?? 0,
        tokensEmitidos: (cfg['tokens_emitidos'] as num?)?.toInt() ?? 0,
        lastPrice: (st['last_price'] as num?)?.toDouble(),
        lockupQuantidadeTipo:
            (cfg['lockup_quantidade_tipo'] as String?) ?? 'percentual',
        lockupQuantidadeValor:
            (cfg['lockup_quantidade_valor'] as num?)?.toDouble() ?? 0.5,
        lockupDiasMinimo: (cfg['lockup_dias_minimo'] as num?)?.toInt() ?? 30,
        lockupDesabilitado: (cfg['lockup_desabilitado'] as bool?) ?? false,
        dataLancamento: (d['data_lancamento'] as Timestamp?)?.toDate(),
      );
    }));
  }

  //Carrega configuração e estado do balcão de uma startup
  Future<(Map<String, dynamic> cfg, Map<String, dynamic> st)> _loadBalcao(
      DocumentReference docRef) async {
    final col = docRef.collection('balcao');

    //Busca dois documentos em paralelo
    final snaps =
        await Future.wait([col.doc('config').get(), col.doc('state').get()]);
    

    final subCfg = snaps[0].data();
    final subSt = snaps[1].data();


    if (subCfg != null || subSt != null) {
      return (
        Map<String, dynamic>.from(subCfg ?? const {}),
        Map<String, dynamic>.from(subSt ?? const {}),
      );
    }

    //fallback
    final rootSnap = await docRef.get();
    final root = rootSnap.data() is Map
        ? Map<String, dynamic>.from(rootSnap.data() as Map)
        : const <String, dynamic>{};
    final balcao = root['balcao'] is Map
        ? Map<String, dynamic>.from(root['balcao'] as Map)
        : const <String, dynamic>{};
    return (
      balcao['config'] is Map
          ? Map<String, dynamic>.from(balcao['config'] as Map)
          : <String, dynamic>{},
      balcao['state'] is Map
          ? Map<String, dynamic>.from(balcao['state'] as Map)
          : <String, dynamic>{},
    );
  }

  // Escuta em tempo real as ordens abertas e parcialmente exceutas de uma startup

  Stream<(List<Order> buys, List<Order> sells)> watchOrders(String startupId) {
    final uid = _uid;
    return _db
        .collection('startups')
        .doc(startupId)
        .collection('orders')
        .where('status', whereIn: ['aberta', 'parcialmente_executada'])
        .snapshots()
        .map((snap) {
          final buys = <Order>[];
          final sells = <Order>[];
          for (final doc in snap.docs) {
            final o = _orderFromDoc(doc, uid);
            if (o.side == 'buy') {
              buys.add(o);
            } else {
              sells.add(o);
            }
          }
          return (buys, sells);
        });
  }

  //Escuta em tempo real os ultimos negocios da startup
  Stream<List<Trade>> watchTrades(String startupId) {
    return _db
        .collection('startups')
        .doc(startupId)
        .collection('trades')
        .orderBy('executed_at', descending: true)
        .limit(30) //Limita em 30
        .snapshots()
        .map((snap) => snap.docs.map(_tradeFromDoc).toList());
  }

  //Escuta em tempo real o estado do balcao
  Stream<({double? lastPrice, int tokensVendidos, int tokensEmitidos})>
      watchBalcaoState(String startupId) {
    // try sub-collection first; fall back to embedded map via startup doc
    return _db
        .collection('startups')
        .doc(startupId)
        .collection('balcao')
        .doc('state')
        .snapshots()
        .asyncMap((subSnap) async {
      if (subSnap.exists) {
        final d = subSnap.data()!;
        final cfg = await _db
            .collection('startups')
            .doc(startupId)
            .collection('balcao')
            .doc('config')
            .get();
        final emitted = (cfg.data()?['tokens_emitidos'] as num?)?.toInt() ?? 0;
        return (
          lastPrice: (d['last_price'] as num?)?.toDouble(),
          tokensVendidos: (d['tokens_vendidos_startup'] as num?)?.toInt() ?? 0,
          tokensEmitidos: emitted,
        );
      }

      // fallback: le os dados do mapa embutido no documento raiz
      final startupSnap = await _db.collection('startups').doc(startupId).get();
      final balcao =
          startupSnap.data()?['balcao'] as Map<String, dynamic>? ?? {};
      final st = balcao['state'] as Map<String, dynamic>? ?? {};
      final cfg = balcao['config'] as Map<String, dynamic>? ?? {};
      return (
        lastPrice: (st['last_price'] as num?)?.toDouble(),
        tokensVendidos: (st['tokens_vendidos_startup'] as num?)?.toInt() ?? 0,
        tokensEmitidos: (cfg['tokens_emitidos'] as num?)?.toInt() ?? 0,
      );
    });
  }

  //Escuta em tempo real o saldo da carteira do usuario
  Stream<Wallet> watchWallet() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(Wallet(brl: 0, tokens: 0, tokensReserved: 0));
    }
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('wallet')
        .doc('main')
        .snapshots()
        .map((snap) {
      final d = snap.data() ?? const <String, dynamic>{};
      return Wallet(
        brl: (d['saldo_brl'] as num?)?.toDouble() ?? 0,
        brlReserved: (d['saldo_brl_reservado'] as num?)?.toDouble() ?? 0,
        tokens: 0,
        tokensReserved: 0,
      );
    });
  }

  //Escuta as posições do usuario em todas as startups
  Stream<List<WalletHolding>> watchHoldings() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('positions')
        .snapshots()
        .asyncMap((posSnap) async {

      final validPositions = posSnap.docs.where((doc) {
        final d = doc.data();
        final livres = (d['tokens_livres'] as num?)?.toInt() ?? 0;
        final reservados = (d['tokens_reservados'] as num?)?.toInt() ?? 0;
        return livres + reservados > 0;
      }).toList();

      if (validPositions.isEmpty) return const <WalletHolding>[];

      final startupRefs = validPositions
          .map((p) => _db.collection('startups').doc(p.id))
          .toList();

      final results = await Future.wait([
        ...startupRefs.map((r) => r.get()),
        ...startupRefs.map(_loadBalcao),
      ]);
      final startupSnaps = results.take(startupRefs.length).cast<DocumentSnapshot>().toList();
      final balcaoData = results
          .skip(startupRefs.length)
          .cast<(Map<String, dynamic>, Map<String, dynamic>)>()
          .toList();

      final holdings = <WalletHolding>[];
      for (var i = 0; i < validPositions.length; i++) {
        final posDoc = validPositions[i];
        final data = posDoc.data();
        final tokensLivres = (data['tokens_livres'] as num?)?.toInt() ?? 0;
        final tokensReservados =
            (data['tokens_reservados'] as num?)?.toInt() ?? 0;

        final sd = startupSnaps[i].data() as Map<String, dynamic>? ?? {};
        final (cfg, st) = balcaoData[i];
        final lastPrice = (st['last_price'] as num?)?.toDouble() ?? 0;
        final preco = lastPrice > 0
            ? lastPrice
            : (cfg['preco_emissao'] as num?)?.toDouble() ?? 0;

        final totalTokens = tokensLivres + tokensReservados;
        final nomeRaw = (sd['nome'] as String?) ?? posDoc.id;
        final siglaRaw = sd['sigla'] as String?;
        final sigla = (siglaRaw != null && siglaRaw.isNotEmpty)
            ? siglaRaw
            : nomeRaw
                .replaceAll(' ', '')
                .substring(0, nomeRaw.replaceAll(' ', '').length.clamp(0, 4))
                .toUpperCase();
        holdings.add(WalletHolding(
          startupUid: posDoc.id,
          startupNome: nomeRaw,
          startupSigla: sigla,
          startupSetor: (sd['setor'] as String?) ?? '',
          quantidade: tokensLivres,
          quantidadeReservada: tokensReservados,
          precoMedio: preco,
          valorInvestido: totalTokens * preco,
          precoEmissao: (cfg['preco_emissao'] as num?)?.toDouble() ?? 0,
        ));
      }
      holdings.sort((a, b) => b.valorInvestido.compareTo(a.valorInvestido));
      return holdings;
    });
  }

  //Ouve o historico de ordens do usuario
  Stream<List<OrderHistoryEntry>> watchOrderHistory({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('order_history')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final cache = <String, ({String nome, String sigla, double precoAtual})>{};
      final entries = <OrderHistoryEntry>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final startupId = (d['startup_id'] as String?) ?? '';
        String startupNome = cache[startupId]?.nome ?? '';
        String startupSigla = cache[startupId]?.sigla ?? '';
        double precoAtual = cache[startupId]?.precoAtual ?? 0;
        if (startupNome.isEmpty && startupId.isNotEmpty) {
          try {
            final ref = _db.collection('startups').doc(startupId);
            final (cfg, st) = await _loadBalcao(ref);
            final s = await ref.get();
            final sd = s.data() ?? {};
            startupNome = (sd['nome'] as String?) ?? startupId;
            final siglaRaw = sd['sigla'] as String?;
            startupSigla = (siglaRaw != null && siglaRaw.isNotEmpty)
                ? siglaRaw
                : startupNome
                    .replaceAll(' ', '')
                    .substring(
                        0, startupNome.replaceAll(' ', '').length.clamp(0, 4))
                    .toUpperCase();
            final lastPrice = (st['last_price'] as num?)?.toDouble() ?? 0;
            precoAtual = lastPrice > 0
                ? lastPrice
                : (cfg['preco_emissao'] as num?)?.toDouble() ?? 0;
            cache[startupId] = (nome: startupNome, sigla: startupSigla, precoAtual: precoAtual);
          } catch (_) {
            startupNome = startupId;
          }
        }
        final changes = (d['status_changes'] as List?) ?? const [];
        final lastStatus = changes.isNotEmpty
            ? ((changes.last as Map?)?['status'] as String?) ?? 'aberta'
            : 'aberta';
        entries.add(OrderHistoryEntry(
          id: doc.id,
          startupId: startupId,
          startupNome: startupNome,
          startupSigla: startupSigla,
          side: (d['side'] as String?) ?? 'buy',
          orderType: (d['order_type'] as String?) ?? 'market',
          price: (d['price'] as num?)?.toDouble() ?? 0,
          qtyOriginal: (d['qty_original'] as num?)?.toInt() ?? 0,
          status: lastStatus,
          createdAt:
              (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          precoAtual: precoAtual,
        ));
      }
      return entries;
    });
  }

  //Escuta em tempo real a posição do usuarui em uma startup especifica
  Stream<({int tokensLivres, int tokensReservados})> watchPosition(
      String startupId) {
    final uid = _uid;
    if (uid == null) {
      return Stream.value((tokensLivres: 0, tokensReservados: 0));
    }
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('positions')
        .doc(startupId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return (tokensLivres: 0, tokensReservados: 0);
      final d = snap.data()!;
      return (
        tokensLivres: (d['tokens_livres'] as num?)?.toInt() ?? 0,
        tokensReservados: (d['tokens_reservados'] as num?)?.toInt() ?? 0,
      );
    });
  }

  // Envia uma ordem de compra ou venda vida Cloud Functions
  Future<OrderCreateResult> createOrder({
    required String startupId,
    required String side,
    required String orderType,
    required int qty,
    double? price,
  }) async {
    try {
      final res = await _fn.httpsCallable('ordersCreate').call({
        'startup_id': startupId,
        'side': side,
        'order_type': orderType,
        'qty': qty,
        if (price != null) 'price': price,
      });

      final trades = (res.data['trades'] as List?)?.length ?? 0;
      return OrderCreateResult(success: true, tradesExecuted: trades);
    } on FirebaseFunctionsException catch (e) {
      return OrderCreateResult(
        success: false,
        errorCode: _parseErrorCode(e.message),
        errorMessage: _humanizeError(e.message),
      );
    } catch (e) {
      return OrderCreateResult(
        success: false,
        errorMessage: 'Erro ao processar ordem. Tente novamente.',
      );
    }
  }

  //Cancela uma ordem aberta via Cloud Functions
  Future<CancelResult> cancelOrder({
    required String startupId,
    required String orderId,
  }) async {
    try {
      await _fn.httpsCallable('ordersCancel').call({
        'startup_id': startupId,
        'order_id': orderId,
      });
      return CancelResult(success: true);
    } on FirebaseFunctionsException catch (e) {
      return CancelResult(
        success: false,
        errorMessage: _humanizeError(e.message),
      );
    } catch (e) {
      return CancelResult(
          success: false, errorMessage: 'Erro ao cancelar ordem.');
    }
  }

  // Converte um docuemnto do Firestore em um modelo [order]
  Order _orderFromDoc(DocumentSnapshot doc, String? currentUid) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Order(
      id: doc.id,
      side: (d['side'] as String?) ?? 'buy',
      type: (d['order_type'] as String?) ?? 'limit',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      qtyOriginal: (d['qty_original'] as num?)?.toInt() ?? 0,
      qty: (d['qty_restante'] as num?)?.toInt() ?? 0,
      mine: d['user_id'] == currentUid,
      isStartup: d['seller_type'] == 'startup',
      status: (d['status'] as String?) ?? 'aberta',
    );
  }

  //Converte um documento Firestore em um modelo [Trade]
  Trade _tradeFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['executed_at'] as Timestamp?;
    final dt = ts?.toDate() ?? DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return Trade(
      time: '$h:$m:$s',
      side: 'compra', // todos os trades representam uma compra casada com uma venda
      price: (d['price'] as num?)?.toDouble() ?? 0,
      qty: (d['qty'] as num?)?.toInt() ?? 0,
    );
  }

  //Extrai o codigo de erro Json retornado pelas cloud functions
  String? _parseErrorCode(String? message) {
    try {
      final m = jsonDecode(message ?? '{}') as Map<String, dynamic>;
      return m['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  //Converte o codigo de erro da cloud function em uma mensagem legivel
  String _humanizeError(String? message) {
    try {
      final m = jsonDecode(message ?? '{}') as Map<String, dynamic>;
      final code = m['code'] as String?;
      switch (code) {
        case 'INSUFFICIENT_BALANCE':
          return 'Saldo insuficiente para esta operação.';
        case 'INSUFFICIENT_TOKENS':
          return 'Tokens insuficientes em carteira.';
        case 'INSUFFICIENT_LIQUIDITY':
          final avail = m['available_qty'];
          final req = m['requested_qty'];
          return 'Liquidez insuficiente no book: só há $avail tokens à venda (você pediu $req).';
        case 'SELF_TRADE_BLOCKED':
          return 'Você não pode executar contra suas próprias ordens. Aguarde outras ofertas no book.';
        case 'INSUFFICIENT_LIQUIDITY_AT_EXECUTION':
          return 'Liquidez insuficiente no momento da execução. Tente novamente.';
        case 'LOCKUP_QUANTITY_VIOLATION':
          final tipo = m['lockup_type'] as String?;
          if (tipo == 'percentual') {
            final sold = m['tokens_sold_percentage'];
            final req = m['required_percentage'];
            final needed = m['tokens_needed_to_unlock'];
            return 'Vendas bloqueadas: startup vendeu $sold% dos tokens (mínimo $req%). Faltam $needed tokens.';
          } else {
            final sold = m['tokens_sold'];
            final req = m['required_tokens'];
            final needed = m['tokens_needed_to_unlock'];
            return 'Vendas bloqueadas: startup vendeu $sold tokens (mínimo $req). Faltam $needed tokens.';
          }
        case 'LOCKUP_TIME_VIOLATION':
          final days = m['days_remaining'];
          if (days != null) {
            return 'Mercado secundário ainda em lock-up. Abertura em $days dia(s).';
          }
          return 'Mercado secundário ainda em período de lock-up.';
        case 'PRICE_OUT_OF_RANGE':
          final min = m['min_allowed'];
          final max = m['max_allowed'];
          return 'Preço fora do limite permitido (R\$ $min – R\$ $max).';
        default:
          return message ?? 'Erro ao processar ordem.';
      }
    } catch (_) {
      return message ?? 'Erro ao processar ordem.';
    }
  }
}

//Resultado de uma tentativa de criação de ordens
class OrderCreateResult {
  final bool success;
  final int tradesExecuted; //Numero de negocios gerados
  final String? errorCode;
  final String? errorMessage;

  const OrderCreateResult({
    required this.success,
    this.tradesExecuted = 0,
    this.errorCode,
    this.errorMessage,
  });
}

//Resultado de uma tentiva de cancelamento de ordem
class CancelResult {
  final bool success;
  final String? errorMessage;

  const CancelResult({required this.success, this.errorMessage});
}

//Entrada do historico de ordens enriquecida com dados da startup
class OrderHistoryEntry {
  final String id;
  final String startupId;
  final String startupNome;
  final String startupSigla;
  final String side; // byd = compra | sell = venda
  final String orderType; // 'market = a mercado' | 'limit = preço definio=do'
  final double price;
  final int qtyOriginal;
  final String status; // último status em status_changes
  final DateTime createdAt;
  final double precoAtual; // last_price da startup no momento do carregamento

  const OrderHistoryEntry({
    required this.id,
    required this.startupId,
    required this.startupNome,
    this.startupSigla = '',
    required this.side,
    required this.orderType,
    required this.price,
    required this.qtyOriginal,
    required this.status,
    required this.createdAt,
    this.precoAtual = 0,
  });
}
