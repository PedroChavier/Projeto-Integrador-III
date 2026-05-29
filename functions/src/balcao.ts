import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import { enforceRateLimit } from "./rate_limit";

const db = admin.firestore();

// ─── Types ───────────────────────────────────────────────────────────────────

type Side = "buy" | "sell";
type OrderType = "market" | "limit";
type OrderStatus = "aberta" | "parcialmente_executada" | "executada" | "cancelada";
type SellerType = "startup" | "investor";
type LockupTipo = "percentual" | "absoluto";

interface BalcaoConfig {
  tokens_emitidos: number;
  preco_emissao: number;
  lockup_quantidade_tipo: LockupTipo;
  lockup_quantidade_valor: number;
  lockup_dias_minimo: number;
  limite_preco_percentual: number | null;
  qty_maxima_por_ordem: number;
  max_ordens_abertas_por_usuario: number;
}

interface BalcaoState {
  last_price: number | null;
  tokens_vendidos_startup: number;
  tokens_disponiveis_startup: number;
  best_bid: number | null;
  best_ask: number | null;
  spread: number | null;
  total_trades: number;
}

interface Order {
  id: string;
  user_id: string;
  seller_type: SellerType;
  side: Side;
  order_type: OrderType;
  price: number;
  qty_original: number;
  qty_executada: number;
  qty_restante: number;
  status: OrderStatus;
  version: number;
  created_at: admin.firestore.Timestamp;
  updated_at: admin.firestore.Timestamp;
}

interface TradeRecord {
  id: string;
  buy_order_id: string;
  sell_order_id: string;
  buyer_id: string;
  seller_id: string;
  seller_type: SellerType;
  buyer_order_type: OrderType;
  seller_order_type: OrderType;
  price: number;
  qty: number;
  executed_at: admin.firestore.Timestamp;
  spread_at_execution: number | null;
  impact_price: number;
}

// ─── Payloads ─────────────────────────────────────────────────────────────────

type CriarOrdemPayload = {
  startup_id?: unknown;
  side?: unknown;
  order_type?: unknown;
  price?: unknown;
  qty?: unknown;
};

type CancelarOrdemPayload = {
  startup_id?: unknown;
  order_id?: unknown;
};

type GetOrderbookPayload = { startup_id?: unknown };

type GetTradesPayload = { startup_id?: unknown; limit?: unknown; after?: unknown };

// ─── Helpers ──────────────────────────────────────────────────────────────────

function throwHttp(code: functions.https.FunctionsErrorCode, msg: string): never {
  throw new functions.https.HttpsError(code, msg);
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throwHttp("invalid-argument", `${field} obrigatorio.`);
  }
  return (value as string).trim();
}

function requirePositiveInteger(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
    throwHttp("invalid-argument", `${field} deve ser um inteiro positivo.`);
  }
  return value as number;
}

function startupOrdersRef(startupId: string) {
  return db.collection("startups").doc(startupId).collection("orders");
}

function startupTradesRef(startupId: string) {
  return db.collection("startups").doc(startupId).collection("trades");
}

function startupBalcaoRef(startupId: string) {
  return db.collection("startups").doc(startupId).collection("balcao");
}

function userWalletRef(uid: string) {
  return db.collection("usuarios").doc(uid).collection("wallet").doc("main");
}

function userPositionRef(uid: string, startupId: string) {
  return db.collection("usuarios").doc(uid).collection("positions").doc(startupId);
}

function userPurchasesRef(uid: string, startupId: string) {
  return db.collection("usuarios").doc(uid).collection("token_purchases").doc(startupId);
}

function userOrderHistoryRef(uid: string, orderId: string) {
  return db.collection("usuarios").doc(uid).collection("order_history").doc(orderId);
}

function userAuditLogRef(uid: string) {
  return db.collection("usuarios").doc(uid).collection("audit_log").doc();
}

// Anexa entrada de auditoria de mutacao de saldo dentro de uma transacao.
function writeAuditLog(
  t: admin.firestore.Transaction,
  uid: string,
  entry: {
    motivo: string;
    delta_brl?: number;
    delta_brl_reservado?: number;
    delta_tokens_livres?: number;
    delta_tokens_reservados?: number;
    startup_id?: string;
    order_id?: string;
    trade_id?: string;
  },
  now: admin.firestore.Timestamp
): void {
  t.set(userAuditLogRef(uid), {
    ...entry,
    created_at: now,
  });
}

// ─── DB Reads (with embedded-map fallback) ───────────────────────────────────

async function readConfig(startupId: string): Promise<BalcaoConfig> {
  const subSnap = await startupBalcaoRef(startupId).doc("config").get();
  if (subSnap.exists) return subSnap.data() as BalcaoConfig;

  const startupSnap = await db.collection("startups").doc(startupId).get();
  if (!startupSnap.exists) throwHttp("not-found", "Startup não encontrada.");

  const data = startupSnap.data() as Record<string, unknown>;
  const cfg = ((data.balcao as Record<string, unknown> | undefined)?.config ?? {}) as Record<string, unknown>;

  return {
    tokens_emitidos: (cfg.tokens_emitidos as number) ?? 0,
    preco_emissao: (cfg.preco_emissao as number) ?? 0,
    lockup_quantidade_tipo: (cfg.lockup_quantidade_tipo as LockupTipo) ?? "percentual",
    lockup_quantidade_valor: (cfg.lockup_quantidade_valor as number) ?? 0.5,
    lockup_dias_minimo: (cfg.lockup_dias_minimo as number) ?? 30,
    limite_preco_percentual: (cfg.limite_preco_percentual as number | null) ?? null,
    qty_maxima_por_ordem: (cfg.qty_maxima_por_ordem as number) ?? 100000,
    max_ordens_abertas_por_usuario: (cfg.max_ordens_abertas_por_usuario as number) ?? 100,
  };
}

async function readState(startupId: string): Promise<BalcaoState> {
  const subSnap = await startupBalcaoRef(startupId).doc("state").get();
  if (subSnap.exists) return subSnap.data() as BalcaoState;

  const startupSnap = await db.collection("startups").doc(startupId).get();
  if (!startupSnap.exists) throwHttp("not-found", "Startup não encontrada.");

  const data = startupSnap.data() as Record<string, unknown>;
  const s = ((data.balcao as Record<string, unknown> | undefined)?.state ?? {}) as Record<string, unknown>;

  return {
    last_price: (s.last_price as number | null) ?? null,
    tokens_vendidos_startup: (s.tokens_vendidos_startup as number) ?? 0,
    tokens_disponiveis_startup: (s.tokens_disponiveis_startup as number) ?? 0,
    best_bid: null,
    best_ask: null,
    spread: null,
    total_trades: (s.total_trades as number) ?? 0,
  };
}

async function readStateInTx(
  t: admin.firestore.Transaction,
  startupId: string
): Promise<{ state: BalcaoState; stateRef: admin.firestore.DocumentReference }> {
  const stateRef = startupBalcaoRef(startupId).doc("state");
  const stateSnap = await t.get(stateRef);

  if (stateSnap.exists) return { state: stateSnap.data() as BalcaoState, stateRef };

  // fallback: read embedded from startup doc inside the same tx
  const startupRef = db.collection("startups").doc(startupId);
  const startupSnap = await t.get(startupRef);
  if (!startupSnap.exists) throwHttp("not-found", "Startup não encontrada.");

  const data = startupSnap.data() as Record<string, unknown>;
  const s = ((data.balcao as Record<string, unknown> | undefined)?.state ?? {}) as Record<string, unknown>;

  const state: BalcaoState = {
    last_price: (s.last_price as number | null) ?? null,
    tokens_vendidos_startup: (s.tokens_vendidos_startup as number) ?? 0,
    tokens_disponiveis_startup: (s.tokens_disponiveis_startup as number) ?? 0,
    best_bid: null,
    best_ask: null,
    spread: null,
    total_trades: (s.total_trades as number) ?? 0,
  };

  return { state, stateRef };
}

// ─── Lock-up Validation ───────────────────────────────────────────────────────

function validateLockupQuantidade(config: BalcaoConfig, state: BalcaoState): void {
  const { lockup_quantidade_tipo, lockup_quantidade_valor, tokens_emitidos } = config;
  const { tokens_vendidos_startup } = state;

  if (lockup_quantidade_tipo === "percentual") {
    const pct = tokens_emitidos > 0 ? tokens_vendidos_startup / tokens_emitidos : 0;
    if (pct < lockup_quantidade_valor) {
      const needed = Math.ceil(lockup_quantidade_valor * tokens_emitidos - tokens_vendidos_startup);
      throwHttp("failed-precondition", JSON.stringify({
        code: "LOCKUP_QUANTITY_VIOLATION",
        lockup_type: "percentual",
        tokens_sold_percentage: Math.round(pct * 100),
        required_percentage: Math.round(lockup_quantidade_valor * 100),
        tokens_needed_to_unlock: needed,
      }));
    }
  } else {
    if (tokens_vendidos_startup < lockup_quantidade_valor) {
      throwHttp("failed-precondition", JSON.stringify({
        code: "LOCKUP_QUANTITY_VIOLATION",
        lockup_type: "absoluto",
        tokens_sold: tokens_vendidos_startup,
        required_tokens: lockup_quantidade_valor,
        tokens_needed_to_unlock: lockup_quantidade_valor - tokens_vendidos_startup,
      }));
    }
  }
}

function validateLockupTempoFromSnap(
  snap: admin.firestore.DocumentSnapshot,
  qtyRequested: number,
  lockupDias: number
): void {
  if (!snap.exists) {
    throwHttp("failed-precondition", JSON.stringify({
      code: "LOCKUP_TIME_VIOLATION",
      available_to_sell: 0,
      locked_qty: 0,
    }));
  }

  const entries: Array<{ qty: number; acquired_at: admin.firestore.Timestamp }> =
    (snap.data()?.entries as Array<{ qty: number; acquired_at: admin.firestore.Timestamp }>) ?? [];

  const now = Date.now();
  const lockupMs = lockupDias * 86_400_000;
  let available = 0;
  let locked = 0;
  const breakdown: Array<{ qty: number; unlock_at: string; days_remaining: number }> = [];

  for (const entry of entries) {
    const unlockMs = entry.acquired_at.toMillis() + lockupMs;
    if (now >= unlockMs) {
      available += entry.qty;
    } else {
      locked += entry.qty;
      breakdown.push({
        qty: entry.qty,
        unlock_at: new Date(unlockMs).toISOString(),
        days_remaining: Math.ceil((unlockMs - now) / 86_400_000),
      });
    }
  }

  if (available <= 0) {
    throwHttp("failed-precondition", JSON.stringify({
      code: "LOCKUP_TIME_VIOLATION",
      locked_tokens_breakdown: breakdown,
      available_to_sell: 0,
    }));
  }

  if (available < qtyRequested) {
    throwHttp("failed-precondition", JSON.stringify({
      code: "LOCKUP_PARTIAL_VIOLATION",
      available_to_sell: available,
      locked_qty: locked,
      requested_qty: qtyRequested,
    }));
  }
}

async function validateLockupTempo(
  uid: string,
  startupId: string,
  qtyRequested: number,
  lockupDias: number
): Promise<void> {
  const snap = await userPurchasesRef(uid, startupId).get();
  validateLockupTempoFromSnap(snap, qtyRequested, lockupDias);
}

// ─── Matching Engine ──────────────────────────────────────────────────────────

interface MatchResult {
  trades: TradeRecord[];
  orderUpdates: Map<string, Partial<Order & { version: admin.firestore.FieldValue }>>;
  lastPrice: number | null;
  startupTokensSoldDelta: number;
}

function runMatchingEngine(
  startupId: string,
  currentState: BalcaoState,
  rawBids: Order[],
  rawAsks: Order[]
): MatchResult {
  // Sort: bids descending by price (market bids first), asks ascending by price (market asks first)
  const bids: Order[] = [...rawBids]
    .sort((a, b) => {
      if (a.order_type === "market" && b.order_type !== "market") return -1;
      if (b.order_type === "market" && a.order_type !== "market") return 1;
      return b.price - a.price || a.created_at.toMillis() - b.created_at.toMillis();
    });

  const asks: Order[] = [...rawAsks]
    .sort((a, b) => {
      if (a.order_type === "market" && b.order_type !== "market") return -1;
      if (b.order_type === "market" && a.order_type !== "market") return 1;
      return a.price - b.price || a.created_at.toMillis() - b.created_at.toMillis();
    });

  const result: MatchResult = {
    trades: [],
    orderUpdates: new Map(),
    lastPrice: currentState.last_price,
    startupTokensSoldDelta: 0,
  };

  const mBids = bids.map(o => ({ ...o }));
  const mAsks = asks.map(o => ({ ...o }));
  let bi = 0;
  let ai = 0;

  while (bi < mBids.length && ai < mAsks.length) {
    const bid = mBids[bi];
    const ask = mAsks[ai];

    if (bid.qty_restante <= 0) { bi++; continue; }
    if (ask.qty_restante <= 0) { ai++; continue; }

    const bidIsMarket = bid.order_type === "market";
    const askIsMarket = ask.order_type === "market";
    const crosses = bidIsMarket || askIsMarket || bid.price >= ask.price;
    if (!crosses) break;

    // Price taker: market order takes the other side's price; if both market, use last_price or emissionPrice
    let tradePrice: number;
    if (bidIsMarket && !askIsMarket) tradePrice = ask.price;
    else if (askIsMarket && !bidIsMarket) tradePrice = bid.price;
    else if (bidIsMarket && askIsMarket) tradePrice = currentState.last_price ?? ask.price;
    else tradePrice = ask.price;

    const tradeQty = Math.min(bid.qty_restante, ask.qty_restante);
    const now = admin.firestore.Timestamp.now();
    const tradeId = startupTradesRef(startupId).doc().id;

    result.trades.push({
      id: tradeId,
      buy_order_id: bid.id,
      sell_order_id: ask.id,
      buyer_id: bid.user_id,
      seller_id: ask.user_id,
      seller_type: ask.seller_type,
      buyer_order_type: bid.order_type,
      seller_order_type: ask.order_type,
      price: tradePrice,
      qty: tradeQty,
      executed_at: now,
      spread_at_execution: currentState.spread,
      impact_price: tradePrice,
    });

    bid.qty_executada += tradeQty;
    bid.qty_restante -= tradeQty;
    ask.qty_executada += tradeQty;
    ask.qty_restante -= tradeQty;

    const newBidStatus: OrderStatus = bid.qty_restante === 0 ? "executada" : "parcialmente_executada";
    const newAskStatus: OrderStatus = ask.qty_restante === 0 ? "executada" : "parcialmente_executada";

    result.orderUpdates.set(bid.id, {
      qty_executada: bid.qty_executada,
      qty_restante: bid.qty_restante,
      status: newBidStatus,
      updated_at: now,
    });

    result.orderUpdates.set(ask.id, {
      qty_executada: ask.qty_executada,
      qty_restante: ask.qty_restante,
      status: newAskStatus,
      updated_at: now,
    });

    if (ask.seller_type === "startup") result.startupTokensSoldDelta += tradeQty;
    result.lastPrice = tradePrice;

    if (bid.qty_restante === 0) bi++;
    if (ask.qty_restante === 0) ai++;
  }

  return result;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function clearInvestidorAtivoIfEmpty(uid: string, startupId: string): Promise<void> {
  const posRef = userPositionRef(uid, startupId);
  const snap = await posRef.get();
  const pos = (snap.data() ?? {}) as Record<string, number>;
  const total = (pos.tokens_livres ?? 0) + (pos.tokens_reservados ?? 0);
  if (total <= 0) {
    await posRef.set(
      { investidor_ativo: false, updated_at: admin.firestore.Timestamp.now() },
      { merge: true }
    );
  }
}

// ─── Cloud Functions ──────────────────────────────────────────────────────────

export const ordersCreate = functions
  .region("southamerica-east1")
  .https.onCall(async (data: CriarOrdemPayload, context) => {
    const uid = context.auth?.uid;
    if (!uid) throwHttp("unauthenticated", "Usuário não autenticado.");

    await enforceRateLimit({ key: uid!, action: "ordersCreate", maxPerWindow: 30, windowSeconds: 60 });

    const startupId = requireString(data.startup_id, "startup_id");
    const side = requireString(data.side, "side") as Side;
    const orderType = requireString(data.order_type, "order_type") as OrderType;
    const qty = requirePositiveInteger(data.qty, "qty");

    if (side !== "buy" && side !== "sell") throwHttp("invalid-argument", "side deve ser 'buy' ou 'sell'.");
    if (orderType !== "market" && orderType !== "limit") throwHttp("invalid-argument", "order_type deve ser 'market' ou 'limit'.");
    if (qty > 1_000_000) throwHttp("invalid-argument", "Quantidade excede o limite de 1.000.000.");

    let limitPrice = 0;
    if (orderType === "limit") {
      if (typeof data.price !== "number" || data.price <= 0) {
        throwHttp("invalid-argument", "price obrigatorio e deve ser positivo para limit order.");
      }
      limitPrice = data.price as number;
    }

    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists) throwHttp("not-found", "Startup não encontrada.");

    const [config, state] = await Promise.all([
      readConfig(startupId),
      readState(startupId),
    ]);

    if (qty > config.qty_maxima_por_ordem) {
      throwHttp("invalid-argument", `Quantidade excede o máximo de ${config.qty_maxima_por_ordem} por ordem.`);
    }

    // Lock-up validation for investor sell orders
    if (side === "sell") {
      validateLockupQuantidade(config, state);
      await validateLockupTempo(uid, startupId, qty, config.lockup_dias_minimo);
    }

    // Max open orders check
    const openOrdersSnap = await startupOrdersRef(startupId)
      .where("user_id", "==", uid)
      .where("status", "in", ["aberta", "parcialmente_executada"])
      .get();

    if (openOrdersSnap.size >= config.max_ordens_abertas_por_usuario) {
      throwHttp("resource-exhausted", `Limite de ${config.max_ordens_abertas_por_usuario} ordens abertas atingido.`);
    }

    // Balance / token check (outside tx for pre-validation; enforced again inside)
    const [walletSnap, positionSnap] = await Promise.all([
      userWalletRef(uid).get(),
      userPositionRef(uid, startupId).get(),
    ]);

    const walletData = (walletSnap.data() ?? {}) as Record<string, number>;
    const saldoBrl = walletData.saldo_brl ?? 0;
    const saldoBrlReservado = walletData.saldo_brl_reservado ?? 0;
    const saldoDisponivel = saldoBrl - saldoBrlReservado;

    const positionData = (positionSnap.data() ?? {}) as Record<string, number>;
    const tokensLivres = positionData.tokens_livres ?? 0;

    const orderPrice = orderType === "limit" ? limitPrice : config.preco_emissao;
    const estimatedCost = Number((orderPrice * qty).toFixed(2));

    if (side === "buy" && orderType === "limit" && saldoDisponivel < estimatedCost) {
      throwHttp("failed-precondition", JSON.stringify({
        code: "INSUFFICIENT_BALANCE",
        available: saldoDisponivel,
        required: estimatedCost,
      }));
    }

    // Market BUY: estima pior caso varrendo asks ascendentes; bloqueia se book
    // não cobrir qty (liquidez) ou saldo não cobrir o custo máximo (balance).
    if (side === "buy" && orderType === "market") {
      const asksSnap = await startupOrdersRef(startupId)
        .where("status", "in", ["aberta", "parcialmente_executada"])
        .where("side", "==", "sell")
        .get();
      const asks = asksSnap.docs
        .map((d) => d.data() as Order)
        .sort((a, b) => a.price - b.price);
      let remaining = qty;
      let maxCost = 0;
      for (const ask of asks) {
        const take = Math.min(remaining, ask.qty_restante);
        maxCost += take * ask.price;
        remaining -= take;
        if (remaining <= 0) break;
      }
      if (remaining > 0) {
        throwHttp("failed-precondition", JSON.stringify({
          code: "INSUFFICIENT_LIQUIDITY",
          available_qty: qty - remaining,
          requested_qty: qty,
        }));
      }
      const requiredCost = Number(maxCost.toFixed(2));
      if (saldoDisponivel < requiredCost) {
        throwHttp("failed-precondition", JSON.stringify({
          code: "INSUFFICIENT_BALANCE",
          available: saldoDisponivel,
          required: requiredCost,
        }));
      }
    }

    if (side === "sell" && orderType === "limit" && tokensLivres < qty) {
      throwHttp("failed-precondition", JSON.stringify({
        code: "INSUFFICIENT_TOKENS",
        tokens_livres: tokensLivres,
        requested: qty,
      }));
    }

    // Apply price limit protection if configured
    if (config.limite_preco_percentual !== null && orderType === "limit" && state.last_price !== null) {
      const maxDev = config.limite_preco_percentual;
      const maxPrice = state.last_price * (1 + maxDev);
      const minPrice = state.last_price * (1 - maxDev);
      if (limitPrice > maxPrice || limitPrice < minPrice) {
        throwHttp("invalid-argument", JSON.stringify({
          code: "PRICE_OUT_OF_RANGE",
          last_price: state.last_price,
          min_allowed: minPrice,
          max_allowed: maxPrice,
        }));
      }
    }

    const now = admin.firestore.Timestamp.now();
    const newOrderRef = startupOrdersRef(startupId).doc();

    const newOrderData: Omit<Order, "id"> = {
      user_id: uid,
      seller_type: "investor",
      side,
      order_type: orderType,
      price: orderType === "limit" ? limitPrice : 0, // market order price resolved at match time
      qty_original: qty,
      qty_executada: 0,
      qty_restante: qty,
      status: "aberta",
      version: 1,
      created_at: now,
      updated_at: now,
    };

    let executedTrades: TradeRecord[] = [];

    await db.runTransaction(async (t) => {
      // ── ALL READS FIRST (Firestore tx invariant) ──
      const { state: txState, stateRef } = await readStateInTx(t, startupId);

      const ordersRef = startupOrdersRef(startupId);
      const reads: Promise<unknown>[] = [
        t.get(userWalletRef(uid)),
        t.get(userPositionRef(uid, startupId)),
        t.get(ordersRef
          .where("status", "in", ["aberta", "parcialmente_executada"])
          .where("side", "==", "buy")),
        t.get(ordersRef
          .where("status", "in", ["aberta", "parcialmente_executada"])
          .where("side", "==", "sell")),
      ];
      if (side === "sell") {
        reads.push(t.get(userPurchasesRef(uid, startupId)));
      }
      const readResults = await Promise.all(reads);
      const txWalletSnap = readResults[0] as admin.firestore.DocumentSnapshot;
      const txPositionSnap = readResults[1] as admin.firestore.DocumentSnapshot;
      const bidsSnap = readResults[2] as admin.firestore.QuerySnapshot;
      const asksSnap = readResults[3] as admin.firestore.QuerySnapshot;
      const txPurchasesSnap = side === "sell"
        ? readResults[4] as admin.firestore.DocumentSnapshot
        : null;

      const txWallet = (txWalletSnap.data() ?? {}) as Record<string, number>;
      const txPosition = (txPositionSnap.data() ?? {}) as Record<string, number>;
      const txSaldoDisponivel = (txWallet.saldo_brl ?? 0) - (txWallet.saldo_brl_reservado ?? 0);
      const txTokensLivres = txPosition.tokens_livres ?? 0;

      if (side === "buy" && orderType === "limit" && txSaldoDisponivel < estimatedCost) {
        throwHttp("failed-precondition", JSON.stringify({ code: "INSUFFICIENT_BALANCE" }));
      }
      if (side === "sell" && orderType === "limit" && txTokensLivres < qty) {
        throwHttp("failed-precondition", JSON.stringify({ code: "INSUFFICIENT_TOKENS" }));
      }
      // Market sell: mesma checagem de tokens livres dentro da TX para evitar
      // que duas market sells concorrentes debitem mais do que existe em livres.
      if (side === "sell" && orderType === "market" && txTokensLivres < qty) {
        throwHttp("failed-precondition", JSON.stringify({
          code: "INSUFFICIENT_TOKENS",
          tokens_livres: txTokensLivres,
          requested_qty: qty,
        }));
      }

      // Revalidate lockup inside the transaction (state and purchases re-read)
      if (side === "sell") {
        validateLockupQuantidade(config, txState);
        validateLockupTempoFromSnap(txPurchasesSnap!, qty, config.lockup_dias_minimo);
      }

      // Build in-memory orderbook with the new order included (no DB write yet)
      const newOrderForMatching: Order = { id: newOrderRef.id, ...newOrderData };
      const rawBids: Order[] = bidsSnap.docs.map(d => ({ id: d.id, ...d.data() } as Order));
      const rawAsks: Order[] = asksSnap.docs.map(d => ({ id: d.id, ...d.data() } as Order));
      if (side === "buy") rawBids.push(newOrderForMatching);
      else rawAsks.push(newOrderForMatching);

      const matchResult = runMatchingEngine(startupId, txState, rawBids, rawAsks);
      executedTrades = matchResult.trades;

      // Market orders devem ser totalmente preenchidos. Se a liquidez no momento
      // da TX nao for suficiente (ja consumida por outras ordens concorrentes),
      // abortamos para evitar fill parcial silencioso.
      if (orderType === "market") {
        const filledQty = matchResult.trades
          .filter(tr => (side === "buy" ? tr.buy_order_id : tr.sell_order_id) === newOrderRef.id)
          .reduce((sum, tr) => sum + tr.qty, 0);
        if (filledQty < qty) {
          throwHttp("failed-precondition", JSON.stringify({
            code: "INSUFFICIENT_LIQUIDITY_AT_EXECUTION",
            requested_qty: qty,
            filled_qty: filledQty,
          }));
        }
      }

      // ── ALL WRITES AFTER READS ──
      // Insert the new order
      t.set(newOrderRef, newOrderData);

      // Write order history atomically with order creation
      t.set(userOrderHistoryRef(uid, newOrderRef.id), {
        startup_id: startupId,
        side,
        order_type: orderType,
        price: orderType === "limit" ? limitPrice : config.preco_emissao,
        qty_original: qty,
        status_changes: [{ status: "aberta", at: now }],
        created_at: now,
      });

      // Reserve balance for limit orders
      if (orderType === "limit") {
        if (side === "buy") {
          t.set(userWalletRef(uid), {
            saldo_brl_reservado: admin.firestore.FieldValue.increment(estimatedCost),
            updated_at: now,
          }, { merge: true });
          writeAuditLog(t, uid!, {
            motivo: "reserva_limit_buy",
            delta_brl_reservado: estimatedCost,
            startup_id: startupId,
            order_id: newOrderRef.id,
          }, now);
        } else {
          t.set(userPositionRef(uid, startupId), {
            tokens_reservados: admin.firestore.FieldValue.increment(qty),
            tokens_livres: admin.firestore.FieldValue.increment(-qty),
            updated_at: now,
          }, { merge: true });
          writeAuditLog(t, uid!, {
            motivo: "reserva_limit_sell",
            delta_tokens_reservados: qty,
            delta_tokens_livres: -qty,
            startup_id: startupId,
            order_id: newOrderRef.id,
          }, now);
        }
      }

      // Write trades
      for (const trade of matchResult.trades) {
        t.set(startupTradesRef(startupId).doc(trade.id), trade);
        const tradeCost = Number((trade.price * trade.qty).toFixed(2));

        // Buyer: deduct BRL. Limit orders had BRL reserved upfront; market orders did not.
        t.set(userWalletRef(trade.buyer_id), {
          saldo_brl: admin.firestore.FieldValue.increment(-tradeCost),
          ...(trade.buyer_order_type === "limit"
            ? { saldo_brl_reservado: admin.firestore.FieldValue.increment(-tradeCost) }
            : {}),
          updated_at: now,
        }, { merge: true });

        t.set(userPositionRef(trade.buyer_id, startupId), {
          tokens_livres: admin.firestore.FieldValue.increment(trade.qty),
          investidor_ativo: true,
          updated_at: now,
        }, { merge: true });

        writeAuditLog(t, trade.buyer_id, {
          motivo: "trade_buy",
          delta_brl: -tradeCost,
          delta_brl_reservado: trade.buyer_order_type === "limit" ? -tradeCost : 0,
          delta_tokens_livres: trade.qty,
          startup_id: startupId,
          order_id: trade.buy_order_id,
          trade_id: trade.id,
        }, now);

        t.set(userPurchasesRef(trade.buyer_id, startupId), {
          qty_total: admin.firestore.FieldValue.increment(trade.qty),
          entries: admin.firestore.FieldValue.arrayUnion({
            qty: trade.qty,
            acquired_at: trade.executed_at,
            source: "buy_order",
            order_id: trade.buy_order_id,
          }),
          updated_at: now,
        }, { merge: true });

        // Seller (investor only): credit BRL, release tokens.
        // Limit sellers had tokens reserved; market sellers deduct from tokens_livres directly.
        if (trade.seller_type === "investor") {
          t.set(userWalletRef(trade.seller_id), {
            saldo_brl: admin.firestore.FieldValue.increment(tradeCost),
            updated_at: now,
          }, { merge: true });

          if (trade.seller_order_type === "limit") {
            t.set(userPositionRef(trade.seller_id, startupId), {
              tokens_reservados: admin.firestore.FieldValue.increment(-trade.qty),
              updated_at: now,
            }, { merge: true });
          } else {
            t.set(userPositionRef(trade.seller_id, startupId), {
              tokens_livres: admin.firestore.FieldValue.increment(-trade.qty),
              updated_at: now,
            }, { merge: true });
          }

          writeAuditLog(t, trade.seller_id, {
            motivo: "trade_sell",
            delta_brl: tradeCost,
            delta_tokens_reservados: trade.seller_order_type === "limit" ? -trade.qty : 0,
            delta_tokens_livres: trade.seller_order_type === "limit" ? 0 : -trade.qty,
            startup_id: startupId,
            order_id: trade.sell_order_id,
            trade_id: trade.id,
          }, now);
        } else if (trade.seller_type === "startup") {
          // Receita primaria: capital captado pela startup. Registro per-trade
          // num audit log dedicado a startup (espelha a captacao em balcao/state.cptAportado).
          t.set(
            db.collection("startups").doc(startupId).collection("revenue_log").doc(trade.id),
            {
              trade_id: trade.id,
              qty: trade.qty,
              price: trade.price,
              total_brl: tradeCost,
              buyer_id: trade.buyer_id,
              buyer_order_id: trade.buy_order_id,
              created_at: now,
            }
          );
        }
      }

      // Update matched order statuses (use set+merge so it composes with the
      // new-order t.set() above without requiring the doc to already exist).
      for (const [orderId, updates] of matchResult.orderUpdates) {
        t.set(startupOrdersRef(startupId).doc(orderId), {
          ...updates,
          version: admin.firestore.FieldValue.increment(1),
        } as Record<string, unknown>, { merge: true });
      }

      // Recalculate best_bid, best_ask, spread from remaining orders
      // Use matchResult data: after matching, compute new best prices from updated orders
      const newTokensVendidos = txState.tokens_vendidos_startup + matchResult.startupTokensSoldDelta;
      const newLastPrice = matchResult.lastPrice ?? txState.last_price;

      // Capital aportado: soma dos trades onde a startup foi vendedora
      const capitalFromStartup = matchResult.trades
        .filter(tr => tr.seller_type === "startup")
        .reduce((sum, tr) => sum + Number((tr.price * tr.qty).toFixed(2)), 0);

      t.set(stateRef, {
        last_price: newLastPrice,
        tokens_vendidos_startup: newTokensVendidos,
        tokens_disponiveis_startup: Math.max(0, config.tokens_emitidos - newTokensVendidos),
        total_trades: admin.firestore.FieldValue.increment(matchResult.trades.length),
        ...(capitalFromStartup > 0
          ? { cptAportado: admin.firestore.FieldValue.increment(capitalFromStartup) }
          : {}),
        updated_at: now,
      }, { merge: true });
    });

    // Update best_bid / best_ask after transaction (async, non-blocking for response)
    updateBestPrices(startupId).catch((e) =>
      functions.logger.error("updateBestPrices failed", { startupId, error: String(e) })
    );

    // Best-effort: increment nmrInvestidores for first-time buyers of startup tokens
    const newStartupBuyers = [...new Set(
      executedTrades
        .filter(tr => tr.seller_type === "startup")
        .map(tr => tr.buyer_id)
    )];
    if (newStartupBuyers.length > 0) {
      Promise.all(newStartupBuyers.map(async (buyerId) => {
        const purchasesSnap = await userPurchasesRef(buyerId, startupId).get();
        const entries = (purchasesSnap.data()?.entries as unknown[]) ?? [];
        if (entries.length === 1) {
          // First purchase ever for this investor in this startup
          await startupBalcaoRef(startupId).doc("state").set(
            { nmrInvestidores: admin.firestore.FieldValue.increment(1) },
            { merge: true }
          );
        }
      })).catch(() => undefined);
    }

    // Best-effort: clear investidor_ativo for investor sellers who sold all tokens
    const investorSellerIds = [...new Set(
      executedTrades.filter(tr => tr.seller_type === "investor").map(tr => tr.seller_id)
    )];
    if (investorSellerIds.length > 0) {
      Promise.all(investorSellerIds.map(sid => clearInvestidorAtivoIfEmpty(sid, startupId)))
        .catch(() => undefined);
    }

    return {
      success: true,
      order: { id: newOrderRef.id, ...newOrderData },
      trades: executedTrades,
    };
  });

export const ordersCancel = functions
  .region("southamerica-east1")
  .https.onCall(async (data: CancelarOrdemPayload, context) => {
    const uid = context.auth?.uid;
    if (!uid) throwHttp("unauthenticated", "Usuário não autenticado.");

    await enforceRateLimit({ key: uid!, action: "ordersCancel", maxPerWindow: 30, windowSeconds: 60 });

    const startupId = requireString(data.startup_id, "startup_id");
    const orderId = requireString(data.order_id, "order_id");

    const orderRef = startupOrdersRef(startupId).doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) throwHttp("not-found", "Ordem não encontrada.");
    const order = { id: orderId, ...orderSnap.data() } as Order;

    if (order.user_id !== uid) throwHttp("permission-denied", "Sem permissão para cancelar esta ordem.");
    if (order.status === "executada" || order.status === "cancelada") {
      throwHttp("failed-precondition", "Ordem já executada ou cancelada.");
    }

    const now = admin.firestore.Timestamp.now();

    await db.runTransaction(async (t) => {
      t.update(orderRef, {
        status: "cancelada",
        updated_at: now,
        version: admin.firestore.FieldValue.increment(1),
      });

      if (order.side === "buy" && order.order_type === "limit") {
        const refund = Number((order.price * order.qty_restante).toFixed(2));
        t.set(userWalletRef(uid), {
          saldo_brl_reservado: admin.firestore.FieldValue.increment(-refund),
          updated_at: now,
        }, { merge: true });
        writeAuditLog(t, uid!, {
          motivo: "cancel_limit_buy_refund",
          delta_brl_reservado: -refund,
          startup_id: startupId,
          order_id: orderId,
        }, now);
      }

      if (order.side === "sell" && order.order_type === "limit") {
        t.set(userPositionRef(uid, startupId), {
          tokens_reservados: admin.firestore.FieldValue.increment(-order.qty_restante),
          tokens_livres: admin.firestore.FieldValue.increment(order.qty_restante),
          updated_at: now,
        }, { merge: true });
        writeAuditLog(t, uid!, {
          motivo: "cancel_limit_sell_release",
          delta_tokens_reservados: -order.qty_restante,
          delta_tokens_livres: order.qty_restante,
          startup_id: startupId,
          order_id: orderId,
        }, now);
      }

      t.set(userOrderHistoryRef(uid, orderId), {
        status_changes: admin.firestore.FieldValue.arrayUnion({ status: "cancelada", at: now }),
      }, { merge: true });
    });

    updateBestPrices(startupId).catch((e) =>
      functions.logger.error("updateBestPrices failed", { startupId, error: String(e) })
    );

    return { success: true };
  });

export const getOrderbook = functions
  .region("southamerica-east1")
  .https.onCall(async (data: GetOrderbookPayload, _context) => {
    const startupId = requireString(data.startup_id, "startup_id");

    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists) throwHttp("not-found", "Startup não encontrada.");

    const [openOrdersSnap, config, state] = await Promise.all([
      startupOrdersRef(startupId)
        .where("status", "in", ["aberta", "parcialmente_executada"])
        .get(),
      readConfig(startupId),
      readState(startupId),
    ]);

    const orders = openOrdersSnap.docs.map(d => ({ id: d.id, ...d.data() } as Order));
    const buyOrders = orders
      .filter(o => o.side === "buy")
      .sort((a, b) => b.price - a.price)
      .slice(0, 20);
    const sellOrders = orders
      .filter(o => o.side === "sell")
      .sort((a, b) => a.price - b.price)
      .slice(0, 20);

    return {
      success: true,
      buy_orders: buyOrders,
      sell_orders: sellOrders,
      last_price: state.last_price,
      preco_emissao: config.preco_emissao,
      best_bid: state.best_bid,
      best_ask: state.best_ask,
      spread: state.spread,
      tokens_vendidos_startup: state.tokens_vendidos_startup,
      tokens_emitidos: config.tokens_emitidos,
    };
  });

export const getTrades = functions
  .region("southamerica-east1")
  .https.onCall(async (data: GetTradesPayload, _context) => {
    const startupId = requireString(data.startup_id, "startup_id");
    const limitVal = typeof data.limit === "number" ? Math.min(Math.max(data.limit, 1), 50) : 20;

    let query = startupTradesRef(startupId)
      .orderBy("executed_at", "desc")
      .limit(limitVal);

    if (typeof data.after === "string" && data.after) {
      const afterSnap = await startupTradesRef(startupId).doc(data.after).get();
      if (afterSnap.exists) {
        query = query.startAfter(afterSnap);
      }
    }

    const snap = await query.get();
    return {
      success: true,
      trades: snap.docs.map(d => ({ id: d.id, ...d.data() })),
    };
  });

// ─── Admin: cria a ordem inicial de venda da startup (book primário) ──────────

export const inicializarOrdemEmissao = functions
  .region("southamerica-east1")
  .https.onCall(async (data: { startup_id?: unknown }, context) => {
    const uid = context.auth?.uid;
    if (!uid) throwHttp("unauthenticated", "Usuário não autenticado.");

    const adminSnap = await db.collection("usuarios").doc(uid).get();
    if (!adminSnap.exists || adminSnap.data()?.isAdmin !== true) {
      throwHttp("permission-denied", "Apenas admin pode inicializar ordem de emissão.");
    }

    const startupId = requireString(data.startup_id, "startup_id");

    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists) throwHttp("not-found", "Startup não encontrada.");

    const config = await readConfig(startupId);
    if (config.tokens_emitidos <= 0 || config.preco_emissao <= 0) {
      throwHttp("failed-precondition", "Config inválida: tokens_emitidos/preco_emissao precisam ser positivos.");
    }

    // Idempotent: se já existe ordem aberta de startup, não duplica.
    const existing = await startupOrdersRef(startupId)
      .where("seller_type", "==", "startup")
      .where("status", "in", ["aberta", "parcialmente_executada"])
      .limit(1)
      .get();

    if (!existing.empty) {
      return { success: false, reason: "ALREADY_EXISTS", order_id: existing.docs[0].id };
    }

    const now = admin.firestore.Timestamp.now();
    const orderRef = startupOrdersRef(startupId).doc();

    await orderRef.set({
      user_id: startupId,
      seller_type: "startup",
      side: "sell",
      order_type: "limit",
      status: "aberta",
      price: config.preco_emissao,
      qty_original: config.tokens_emitidos,
      qty_executada: 0,
      qty_restante: config.tokens_emitidos,
      version: 1,
      created_at: now,
      updated_at: now,
    });

    // Inicializa balcao/state se ainda não existir (best_ask = preço de emissão).
    const stateRef = startupBalcaoRef(startupId).doc("state");
    const stateSnap = await stateRef.get();
    if (!stateSnap.exists) {
      await stateRef.set({
        last_price: null,
        tokens_vendidos_startup: 0,
        tokens_disponiveis_startup: config.tokens_emitidos,
        best_bid: null,
        best_ask: config.preco_emissao,
        spread: null,
        total_trades: 0,
        updated_at: now,
      });
    } else {
      updateBestPrices(startupId).catch((e) =>
      functions.logger.error("updateBestPrices failed", { startupId, error: String(e) })
    );
    }

    return { success: true, order_id: orderRef.id };
  });

// ─── Internal: update best_bid / best_ask after order changes ─────────────────

async function updateBestPrices(startupId: string): Promise<void> {
  const [bidsSnap, asksSnap] = await Promise.all([
    startupOrdersRef(startupId)
      .where("status", "in", ["aberta", "parcialmente_executada"])
      .where("side", "==", "buy")
      .orderBy("price", "desc")
      .limit(1)
      .get(),
    startupOrdersRef(startupId)
      .where("status", "in", ["aberta", "parcialmente_executada"])
      .where("side", "==", "sell")
      .orderBy("price", "asc")
      .limit(1)
      .get(),
  ]);

  const bestBid = bidsSnap.empty ? null : (bidsSnap.docs[0].data().price as number);
  const bestAsk = asksSnap.empty ? null : (asksSnap.docs[0].data().price as number);
  const spread = bestBid !== null && bestAsk !== null ? Number((bestAsk - bestBid).toFixed(2)) : null;

  await startupBalcaoRef(startupId).doc("state").set({
    best_bid: bestBid,
    best_ask: bestAsk,
    spread,
    updated_at: admin.firestore.Timestamp.now(),
  }, { merge: true });
}
