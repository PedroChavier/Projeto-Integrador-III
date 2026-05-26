"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTrades = exports.getOrderbook = exports.ordersCancel = exports.ordersCreate = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
const db = admin.firestore();
// ─── Helpers ──────────────────────────────────────────────────────────────────
function throwHttp(code, msg) {
    throw new functions.https.HttpsError(code, msg);
}
function requireString(value, field) {
    if (typeof value !== "string" || !value.trim()) {
        throwHttp("invalid-argument", `${field} obrigatorio.`);
    }
    return value.trim();
}
function requirePositiveInteger(value, field) {
    if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
        throwHttp("invalid-argument", `${field} deve ser um inteiro positivo.`);
    }
    return value;
}
function startupOrdersRef(startupId) {
    return db.collection("startups").doc(startupId).collection("orders");
}
function startupTradesRef(startupId) {
    return db.collection("startups").doc(startupId).collection("trades");
}
function startupBalcaoRef(startupId) {
    return db.collection("startups").doc(startupId).collection("balcao");
}
function userWalletRef(uid) {
    return db.collection("usuarios").doc(uid).collection("wallet").doc("main");
}
function userPositionRef(uid, startupId) {
    return db.collection("usuarios").doc(uid).collection("positions").doc(startupId);
}
function userPurchasesRef(uid, startupId) {
    return db.collection("usuarios").doc(uid).collection("token_purchases").doc(startupId);
}
function userOrderHistoryRef(uid, orderId) {
    return db.collection("usuarios").doc(uid).collection("order_history").doc(orderId);
}
// ─── DB Reads (with embedded-map fallback) ───────────────────────────────────
async function readConfig(startupId) {
    const subSnap = await startupBalcaoRef(startupId).doc("config").get();
    if (subSnap.exists)
        return subSnap.data();
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");
    const data = startupSnap.data();
    const cfg = (data.balcao?.config ?? {});
    return {
        tokens_emitidos: cfg.tokens_emitidos ?? 0,
        preco_emissao: cfg.preco_emissao ?? 0,
        lockup_quantidade_tipo: cfg.lockup_quantidade_tipo ?? "percentual",
        lockup_quantidade_valor: cfg.lockup_quantidade_valor ?? 0.5,
        lockup_dias_minimo: cfg.lockup_dias_minimo ?? 30,
        limite_preco_percentual: cfg.limite_preco_percentual ?? null,
        qty_maxima_por_ordem: cfg.qty_maxima_por_ordem ?? 100000,
        max_ordens_abertas_por_usuario: cfg.max_ordens_abertas_por_usuario ?? 100,
    };
}
async function readState(startupId) {
    const subSnap = await startupBalcaoRef(startupId).doc("state").get();
    if (subSnap.exists)
        return subSnap.data();
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");
    const data = startupSnap.data();
    const s = (data.balcao?.state ?? {});
    return {
        last_price: s.last_price ?? null,
        tokens_vendidos_startup: s.tokens_vendidos_startup ?? 0,
        tokens_disponiveis_startup: s.tokens_disponiveis_startup ?? 0,
        best_bid: null,
        best_ask: null,
        spread: null,
        total_trades: s.total_trades ?? 0,
    };
}
async function readStateInTx(t, startupId) {
    const stateRef = startupBalcaoRef(startupId).doc("state");
    const stateSnap = await t.get(stateRef);
    if (stateSnap.exists)
        return { state: stateSnap.data(), stateRef };
    // fallback: read embedded from startup doc inside the same tx
    const startupRef = db.collection("startups").doc(startupId);
    const startupSnap = await t.get(startupRef);
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");
    const data = startupSnap.data();
    const s = (data.balcao?.state ?? {});
    const state = {
        last_price: s.last_price ?? null,
        tokens_vendidos_startup: s.tokens_vendidos_startup ?? 0,
        tokens_disponiveis_startup: s.tokens_disponiveis_startup ?? 0,
        best_bid: null,
        best_ask: null,
        spread: null,
        total_trades: s.total_trades ?? 0,
    };
    return { state, stateRef };
}
// ─── Lock-up Validation ───────────────────────────────────────────────────────
function validateLockupQuantidade(config, state) {
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
    }
    else {
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
async function validateLockupTempo(uid, startupId, qtyRequested, lockupDias) {
    const snap = await userPurchasesRef(uid, startupId).get();
    if (!snap.exists) {
        throwHttp("failed-precondition", JSON.stringify({
            code: "LOCKUP_TIME_VIOLATION",
            available_to_sell: 0,
            locked_qty: 0,
        }));
    }
    const entries = snap.data()?.entries ?? [];
    const now = Date.now();
    const lockupMs = lockupDias * 86400000;
    let available = 0;
    let locked = 0;
    const breakdown = [];
    for (const entry of entries) {
        const unlockMs = entry.acquired_at.toMillis() + lockupMs;
        if (now >= unlockMs) {
            available += entry.qty;
        }
        else {
            locked += entry.qty;
            breakdown.push({
                qty: entry.qty,
                unlock_at: new Date(unlockMs).toISOString(),
                days_remaining: Math.ceil((unlockMs - now) / 86400000),
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
async function runMatchingEngine(t, startupId, currentState) {
    const ordersRef = startupOrdersRef(startupId);
    const [bidsSnap, asksSnap] = await Promise.all([
        t.get(ordersRef
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "buy")),
        t.get(ordersRef
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "sell")),
    ]);
    // Sort: bids descending by price (market bids first), asks ascending by price (market asks first)
    const bids = bidsSnap.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => {
        if (a.order_type === "market" && b.order_type !== "market")
            return -1;
        if (b.order_type === "market" && a.order_type !== "market")
            return 1;
        return b.price - a.price || a.created_at.toMillis() - b.created_at.toMillis();
    });
    const asks = asksSnap.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => {
        if (a.order_type === "market" && b.order_type !== "market")
            return -1;
        if (b.order_type === "market" && a.order_type !== "market")
            return 1;
        return a.price - b.price || a.created_at.toMillis() - b.created_at.toMillis();
    });
    const result = {
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
        if (bid.qty_restante <= 0) {
            bi++;
            continue;
        }
        if (ask.qty_restante <= 0) {
            ai++;
            continue;
        }
        const bidIsMarket = bid.order_type === "market";
        const askIsMarket = ask.order_type === "market";
        const crosses = bidIsMarket || askIsMarket || bid.price >= ask.price;
        if (!crosses)
            break;
        // Price taker: market order takes the other side's price; if both market, use last_price or emissionPrice
        let tradePrice;
        if (bidIsMarket && !askIsMarket)
            tradePrice = ask.price;
        else if (askIsMarket && !bidIsMarket)
            tradePrice = bid.price;
        else if (bidIsMarket && askIsMarket)
            tradePrice = currentState.last_price ?? ask.price;
        else
            tradePrice = ask.price;
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
        const newBidStatus = bid.qty_restante === 0 ? "executada" : "parcialmente_executada";
        const newAskStatus = ask.qty_restante === 0 ? "executada" : "parcialmente_executada";
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
        if (ask.seller_type === "startup")
            result.startupTokensSoldDelta += tradeQty;
        result.lastPrice = tradePrice;
        if (bid.qty_restante === 0)
            bi++;
        if (ask.qty_restante === 0)
            ai++;
    }
    return result;
}
// ─── Cloud Functions ──────────────────────────────────────────────────────────
exports.ordersCreate = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");
    const startupId = requireString(data.startup_id, "startup_id");
    const side = requireString(data.side, "side");
    const orderType = requireString(data.order_type, "order_type");
    const qty = requirePositiveInteger(data.qty, "qty");
    if (side !== "buy" && side !== "sell")
        throwHttp("invalid-argument", "side deve ser 'buy' ou 'sell'.");
    if (orderType !== "market" && orderType !== "limit")
        throwHttp("invalid-argument", "order_type deve ser 'market' ou 'limit'.");
    if (qty > 1000000)
        throwHttp("invalid-argument", "Quantidade excede o limite de 1.000.000.");
    let limitPrice = 0;
    if (orderType === "limit") {
        if (typeof data.price !== "number" || data.price <= 0) {
            throwHttp("invalid-argument", "price obrigatorio e deve ser positivo para limit order.");
        }
        limitPrice = data.price;
    }
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");
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
    const walletData = (walletSnap.data() ?? {});
    const saldoBrl = walletData.saldo_brl ?? 0;
    const saldoBrlReservado = walletData.saldo_brl_reservado ?? 0;
    const saldoDisponivel = saldoBrl - saldoBrlReservado;
    const positionData = (positionSnap.data() ?? {});
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
    const newOrderData = {
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
    let executedTrades = [];
    await db.runTransaction(async (t) => {
        const { state: txState, stateRef } = await readStateInTx(t, startupId);
        // Re-read wallet and position inside tx for safety
        const txWalletSnap = await t.get(userWalletRef(uid));
        const txPositionSnap = await t.get(userPositionRef(uid, startupId));
        const txWallet = (txWalletSnap.data() ?? {});
        const txPosition = (txPositionSnap.data() ?? {});
        const txSaldoDisponivel = (txWallet.saldo_brl ?? 0) - (txWallet.saldo_brl_reservado ?? 0);
        const txTokensLivres = txPosition.tokens_livres ?? 0;
        if (side === "buy" && orderType === "limit" && txSaldoDisponivel < estimatedCost) {
            throwHttp("failed-precondition", JSON.stringify({ code: "INSUFFICIENT_BALANCE" }));
        }
        if (side === "sell" && orderType === "limit" && txTokensLivres < qty) {
            throwHttp("failed-precondition", JSON.stringify({ code: "INSUFFICIENT_TOKENS" }));
        }
        // Insert order
        t.set(newOrderRef, newOrderData);
        // Reserve balance for limit orders
        if (orderType === "limit") {
            if (side === "buy") {
                t.set(userWalletRef(uid), {
                    saldo_brl_reservado: admin.firestore.FieldValue.increment(estimatedCost),
                    updated_at: now,
                }, { merge: true });
            }
            else {
                t.set(userPositionRef(uid, startupId), {
                    tokens_reservados: admin.firestore.FieldValue.increment(qty),
                    tokens_livres: admin.firestore.FieldValue.increment(-qty),
                    updated_at: now,
                }, { merge: true });
            }
        }
        const matchResult = await runMatchingEngine(t, startupId, txState);
        executedTrades = matchResult.trades;
        // Write trades
        for (const trade of matchResult.trades) {
            t.set(startupTradesRef(startupId).doc(trade.id), trade);
            const tradeCost = Number((trade.price * trade.qty).toFixed(2));
            // Buyer: deduct BRL (reserved -> settled), credit tokens and purchases entry
            t.set(userWalletRef(trade.buyer_id), {
                saldo_brl: admin.firestore.FieldValue.increment(-tradeCost),
                saldo_brl_reservado: admin.firestore.FieldValue.increment(-tradeCost),
                updated_at: now,
            }, { merge: true });
            t.set(userPositionRef(trade.buyer_id, startupId), {
                tokens_livres: admin.firestore.FieldValue.increment(trade.qty),
                updated_at: now,
            }, { merge: true });
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
            // Seller (investor only): credit BRL, release reserved tokens
            if (trade.seller_type === "investor") {
                t.set(userWalletRef(trade.seller_id), {
                    saldo_brl: admin.firestore.FieldValue.increment(tradeCost),
                    updated_at: now,
                }, { merge: true });
                t.set(userPositionRef(trade.seller_id, startupId), {
                    tokens_reservados: admin.firestore.FieldValue.increment(-trade.qty),
                    updated_at: now,
                }, { merge: true });
            }
        }
        // Update matched order statuses
        for (const [orderId, updates] of matchResult.orderUpdates) {
            t.update(startupOrdersRef(startupId).doc(orderId), {
                ...updates,
                version: admin.firestore.FieldValue.increment(1),
            });
        }
        // Recalculate best_bid, best_ask, spread from remaining orders
        // Use matchResult data: after matching, compute new best prices from updated orders
        const newTokensVendidos = txState.tokens_vendidos_startup + matchResult.startupTokensSoldDelta;
        const newLastPrice = matchResult.lastPrice ?? txState.last_price;
        t.set(stateRef, {
            last_price: newLastPrice,
            tokens_vendidos_startup: newTokensVendidos,
            tokens_disponiveis_startup: Math.max(0, config.tokens_emitidos - newTokensVendidos),
            total_trades: admin.firestore.FieldValue.increment(matchResult.trades.length),
            updated_at: now,
        }, { merge: true });
    });
    // Write order history (outside tx, best-effort)
    await userOrderHistoryRef(uid, newOrderRef.id).set({
        startup_id: startupId,
        side,
        order_type: orderType,
        price: orderType === "limit" ? limitPrice : config.preco_emissao,
        qty_original: qty,
        status_changes: [{ status: "aberta", at: now }],
        created_at: now,
    });
    // Update best_bid / best_ask after transaction (async, non-blocking for response)
    updateBestPrices(startupId).catch(() => undefined);
    return {
        success: true,
        order: { id: newOrderRef.id, ...newOrderData },
        trades: executedTrades,
    };
});
exports.ordersCancel = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");
    const startupId = requireString(data.startup_id, "startup_id");
    const orderId = requireString(data.order_id, "order_id");
    const orderRef = startupOrdersRef(startupId).doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists)
        throwHttp("not-found", "Ordem não encontrada.");
    const order = { id: orderId, ...orderSnap.data() };
    if (order.user_id !== uid)
        throwHttp("permission-denied", "Sem permissão para cancelar esta ordem.");
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
        }
        if (order.side === "sell" && order.order_type === "limit") {
            t.set(userPositionRef(uid, startupId), {
                tokens_reservados: admin.firestore.FieldValue.increment(-order.qty_restante),
                tokens_livres: admin.firestore.FieldValue.increment(order.qty_restante),
                updated_at: now,
            }, { merge: true });
        }
    });
    await userOrderHistoryRef(uid, orderId).set({
        status_changes: admin.firestore.FieldValue.arrayUnion({ status: "cancelada", at: now }),
    }, { merge: true });
    updateBestPrices(startupId).catch(() => undefined);
    return { success: true };
});
exports.getOrderbook = functions
    .region("southamerica-east1")
    .https.onCall(async (data, _context) => {
    const startupId = requireString(data.startup_id, "startup_id");
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");
    const [openOrdersSnap, config, state] = await Promise.all([
        startupOrdersRef(startupId)
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .get(),
        readConfig(startupId),
        readState(startupId),
    ]);
    const orders = openOrdersSnap.docs.map(d => ({ id: d.id, ...d.data() }));
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
exports.getTrades = functions
    .region("southamerica-east1")
    .https.onCall(async (data, _context) => {
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
// ─── Internal: update best_bid / best_ask after order changes ─────────────────
async function updateBestPrices(startupId) {
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
    const bestBid = bidsSnap.empty ? null : bidsSnap.docs[0].data().price;
    const bestAsk = asksSnap.empty ? null : asksSnap.docs[0].data().price;
    const spread = bestBid !== null && bestAsk !== null ? Number((bestAsk - bestBid).toFixed(2)) : null;
    await startupBalcaoRef(startupId).doc("state").set({
        best_bid: bestBid,
        best_ask: bestAsk,
        spread,
        updated_at: admin.firestore.Timestamp.now(),
    }, { merge: true });
}
