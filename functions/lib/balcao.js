//Pedro Andre do Carmo Chavier -25018639

//Gerado pelo copilador do TypeScript
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
exports.inicializarOrdemEmissao = exports.getTrades = exports.getOrderbook = exports.ordersCancel = exports.ordersCreate = void 0;


const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
const rate_limit_1 = require("./rate_limit");  

const db = admin.firestore();


//Erro HTTP padrao com codigo e mensagem
function throwHttp(code, msg) {
    throw new functions.https.HttpsError(code, msg);
}

//Valida se o campo é um string
function requireString(value, field) {
    if (typeof value !== "string" || !value.trim()) {
        throwHttp("invalid-argument", `${field} obrigatorio.`);
    }
    return value.trim();
}

//Valida se um campo é um numero inteiro positivo
function requirePositiveInteger(value, field) {
    if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
        throwHttp("invalid-argument", `${field} deve ser um inteiro positivo.`);
    }
    return value;
}

//Referencias as coleções do firebase

//ordens de compra e venda de uma startup
function startupOrdersRef(startupId) {
    return db.collection("startups").doc(startupId).collection("orders");
}

//Historico de negociações
function startupTradesRef(startupId) {
    return db.collection("startups").doc(startupId).collection("trades");
}

//Configurações e estado do balcão
function startupBalcaoRef(startupId) {
    return db.collection("startups").doc(startupId).collection("balcao");
}

//Carteira BRL do usuario
function userWalletRef(uid) {
    return db.collection("usuarios").doc(uid).collection("wallet").doc("main");
}

//Posição de tokens de uma startup que o usuario possui
function userPositionRef(uid, startupId) {
    return db.collection("usuarios").doc(uid).collection("positions").doc(startupId);
}

//Historico de uma ordem especifica do usuario
function userOrderHistoryRef(uid, orderId) {
    return db.collection("usuarios").doc(uid).collection("order_history").doc(orderId);
}

//Grava log de auditoria dentro de uma transação
function userAuditLogRef(uid) {
    return db.collection("usuarios").doc(uid).collection("audit_log").doc();
}

// Anexa entrada de auditoria de mutacao de saldo dentro de uma transacao.
function writeAuditLog(t, uid, entry, now) {
    t.set(userAuditLogRef(uid), {
        ...entry,
        created_at: now,
    });
}

//Le as configurações do balcao da startup (preço emissao, lockoup, limites...)
async function readConfig(startupId) {
    const subSnap = await startupBalcaoRef(startupId).doc("config").get();
    if (subSnap.exists)
        return subSnap.data();
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");
    const data = startupSnap.data();
    const cfg = (data.balcao?.config ?? {});

    //retorna a s configurações com valores padrão caso algum campo esteja ausente
    return {
        tokens_emitidos: cfg.tokens_emitidos ?? 0,
        preco_emissao: cfg.preco_emissao ?? 0,
        lockup_quantidade_tipo: cfg.lockup_quantidade_tipo ?? "percentual",
        lockup_quantidade_valor: cfg.lockup_quantidade_valor ?? 0.5,
        lockup_dias_minimo: cfg.lockup_dias_minimo ?? 30,
        limite_preco_percentual: cfg.limite_preco_percentual ?? null,
        qty_maxima_por_ordem: cfg.qty_maxima_por_ordem ?? 100000,
        max_ordens_abertas_por_usuario: cfg.max_ordens_abertas_por_usuario ?? 100,
        lockup_desabilitado: cfg.lockup_desabilitado ?? false,
    };
}

//Le o estado atual do mercado (ultimo preço, tokens vendidos, melhor bid/ask)
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

//Versão do readState para uso dentro de uma transação Firestore
async function readStateInTx(t, startupId) {
    const stateRef = startupBalcaoRef(startupId).doc("state");
    const stateSnap = await t.get(stateRef);

    if (stateSnap.exists)
        return { state: stateSnap.data(), stateRef };

    // fallback: le o documento caso nao tenha subcoleção
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

//Valida lockoup de quantidade - so pode ser vendido se atingir um % minimo dos tokens 
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

//Valida Lockup temporal: o ivestidor nao pode vender antes de X dias

function validateLockupTempo(dataLancamento, lockupDias) {
    if (lockupDias === 0)
        return;
    if (!dataLancamento)
        return;

    const unlockMs = dataLancamento.toMillis() + lockupDias * 86400000;
    const now = Date.now();
    if (now >= unlockMs)
        return;
    throwHttp("failed-precondition", JSON.stringify({
        code: "LOCKUP_TIME_VIOLATION",
        unlock_at: new Date(unlockMs).toISOString(),
        days_remaining: Math.ceil((unlockMs - now) / 86400000),
    }));
}

//Casamento de ordens (order Matching): cruza bids com asks e gera trades
function runMatchingEngine(startupId, currentState, rawBids, rawAsks) {

    //Ordena bids: mercado primeiro, depois maior preço, mercado primeiro e depois menor preço
    const bids = [...rawBids]
        .sort((a, b) => {
        if (a.order_type === "market" && b.order_type !== "market")
            return -1;
        if (b.order_type === "market" && a.order_type !== "market")
            return 1;
        return b.price - a.price || a.created_at.toMillis() - b.created_at.toMillis();
    });

    const asks = [...rawAsks]
        .sort((a, b) => {
        if (a.order_type === "market" && b.order_type !== "market")
            return -1;
        if (b.order_type === "market" && a.order_type !== "market")
            return 1;
        return a.price - b.price || a.created_at.toMillis() - b.created_at.toMillis();
    });

    const result = {
        trades: [],
        orderUpdates: new Map(), //Mapa de atualizações de startups por order_id
        lastPrice: currentState.last_price,
        startupTokensSoldDelta: 0, //Quantod tokens fora vendiidos
    };

    const mBids = bids.map(o => ({ ...o }));
    const mAsks = asks.map(o => ({ ...o }));
    let bi = 0;
    let ai = 0;

    //Loop principal: tenta casar o melhor bid, com o melhor ask
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

        //Cruzamento: ordens de mercado sempre cruzmam se bid >= ask
        const crosses = bidIsMarket || askIsMarket || bid.price >= ask.price;

        if (!crosses)
            break;

        // Definição do preço do trade
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

        const newBidStatus = bid.qty_restante === 0 ? "executada" : "parcialmente_executada";
        const newAskStatus = ask.qty_restante === 0 ? "executada" : "parcialmente_executada";
        
        //Registra atualização de status para gravar no banco depois
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

        //Acumula os tokens vendidos
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


// remove a flag investidor_ativo se nao possui mais tokens na startup
async function clearInvestidorAtivoIfEmpty(uid, startupId) {
    const posRef = userPositionRef(uid, startupId);
    const snap = await posRef.get();
    const pos = (snap.data() ?? {});

    const total = (pos.tokens_livres ?? 0) + (pos.tokens_reservados ?? 0);
    if (total <= 0) {
        await posRef.set({ investidor_ativo: false, updated_at: admin.firestore.Timestamp.now() }, { merge: true });
    }
}

//Cloud functions 

// Cria uma nova ordem de compra ou venda
exports.ordersCreate = functions
    .region("southamerica-east1")  //São paulo
    .https.onCall(async (data, context) => {

    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");

    //Limita a criação de ordens: max de 30 por min
    await (0, rate_limit_1.enforceRateLimit)({ key: uid, action: "ordersCreate", maxPerWindow: 30, windowSeconds: 60 });

    //Valida e extrai parametros da requisição
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

    //Ordens de limite exigem preçi explicito
    let limitPrice = 0;
    if (orderType === "limit") {
        if (typeof data.price !== "number" || data.price <= 0) {
            throwHttp("invalid-argument", "price obrigatorio e deve ser positivo para limit order.");
        }
        limitPrice = data.price;
    }

    //Busca dados da startup e configurações do balcao
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    const dataLancamento = startupSnap.data()?.data_lancamento ?? null;
    const [config, state] = await Promise.all([
        readConfig(startupId),
        readState(startupId),
    ]);

    if (qty > config.qty_maxima_por_ordem) {
        throwHttp("invalid-argument", `Quantidade excede o máximo de ${config.qty_maxima_por_ordem} por ordem.`);
    }

    // Validação de lockup para ordens de venda de investidores
    if (side === "sell" && !config.lockup_desabilitado) {
        validateLockupQuantidade(config, state);
        validateLockupTempo(dataLancamento, config.lockup_dias_minimo);
    }

    // Verifova se o usuario atingiu o limite de ordens abertas
    const openOrdersSnap = await startupOrdersRef(startupId)
        .where("user_id", "==", uid)
        .where("status", "in", ["aberta", "parcialmente_executada"])
        .get();
    if (openOrdersSnap.size >= config.max_ordens_abertas_por_usuario) {
        throwHttp("resource-exhausted", `Limite de ${config.max_ordens_abertas_por_usuario} ordens abertas atingido.`);
    }


    // Pré- validação de saldo de tokens 
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

    //Compra a limite: verifica saldo disponivel
    if (side === "buy" && orderType === "limit" && saldoDisponivel < estimatedCost) {
        throwHttp("failed-precondition", JSON.stringify({
            code: "INSUFFICIENT_BALANCE",
            available: saldoDisponivel,
            required: estimatedCost,
        }));
    }


    // Compra a mercado: varre o book de aks para caçcular custo maximo e verificar liquidez
    if (side === "buy" && orderType === "market") {

        const asksSnap = await startupOrdersRef(startupId)
            .where("status", "in", ["aberta", "parcialmente_executada"])
            .where("side", "==", "sell")
            .get();

        const asks = asksSnap.docs
            .map((d) => d.data())
            .sort((a, b) => a.price - b.price);

        let remaining = qty;
        let maxCost = 0;

        for (const ask of asks) {
            const take = Math.min(remaining, ask.qty_restante);
            maxCost += take * ask.price;
            remaining -= take;

            if (remaining <= 0)
                break;
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

    //Venda a limite, verifica tokens livres disponiveis
    if (side === "sell" && orderType === "limit" && tokensLivres < qty) {
        throwHttp("failed-precondition", JSON.stringify({
            code: "INSUFFICIENT_TOKENS",
            tokens_livres: tokensLivres,
            requested: qty,
        }));
    }

    // Proteção de preço, rejeita ordens de limite fora do range permitido em relação ao ultimo preço
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
        const ordersRef = startupOrdersRef(startupId);

        //Le a carteira, posição e o orderbook completo dentro da transação
        const [txWalletSnap, txPositionSnap, bidsSnap, asksSnap] = await Promise.all([
            t.get(userWalletRef(uid)),
            t.get(userPositionRef(uid, startupId)),
            t.get(ordersRef
                .where("status", "in", ["aberta", "parcialmente_executada"])
                .where("side", "==", "buy")),
            t.get(ordersRef
                .where("status", "in", ["aberta", "parcialmente_executada"])
                .where("side", "==", "sell")),
        ]);

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
        // Market sell: mesma checagem de tokens livres dentro da TX para evitar
        // que duas market sells concorrentes debitem mais do que existe em livres.
        if (side === "sell" && orderType === "market" && txTokensLivres < qty) {
            throwHttp("failed-precondition", JSON.stringify({
                code: "INSUFFICIENT_TOKENS",
                tokens_livres: txTokensLivres,
                requested_qty: qty,
            }));
        }

        // revalida lockup dentro da transação
        if (side === "sell" && !config.lockup_desabilitado) {
            validateLockupQuantidade(config, txState);
            validateLockupTempo(dataLancamento, config.lockup_dias_minimo);
        }

        // Monta o orderbook em memoria incluindo a nova ordem e executa o matching
        const newOrderForMatching = { id: newOrderRef.id, ...newOrderData };
        const rawBids = bidsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
        const rawAsks = asksSnap.docs.map(d => ({ id: d.id, ...d.data() }));
        if (side === "buy")
            rawBids.push(newOrderForMatching);
        else
            rawAsks.push(newOrderForMatching);
        const matchResult = runMatchingEngine(startupId, txState, rawBids, rawAsks);

        executedTrades = matchResult.trades;

        // Ordens de mercado devem ser 100% preenchidas,; aborta se liquidez insuficiente
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


        // Detecta novos investidores (primeira compra do token da startup) para incrementar contador
        const newStartupBuyers = [...new Set(matchResult.trades.filter(tr => tr.seller_type === "startup").map(tr => tr.buyer_id))];
        const buyerPositionSnaps = await Promise.all(newStartupBuyers.map(bid => bid === uid ? Promise.resolve(txPositionSnap) : t.get(userPositionRef(bid, startupId))));
        const newInvestorsDelta = buyerPositionSnaps.filter(snap => {
            const pos = snap.data();
            if (!pos)
                return true;
            return ((pos.tokens_livres ?? 0) + (pos.tokens_reservados ?? 0)) === 0;
        }).length;


        // escritas

        //insere a nova ordem no banco
        t.set(newOrderRef, newOrderData);

        //Registra no historico de ordens de usuario
        t.set(userOrderHistoryRef(uid, newOrderRef.id), {
            startup_id: startupId,
            side,
            order_type: orderType,
            price: orderType === "limit" ? limitPrice : config.preco_emissao,
            qty_original: qty,
            status_changes: [{ status: "aberta", at: now }],
            created_at: now,
        });

        // Para ordens de limite: reserva o saldo BRL (buy) ou tokens (sell)
        if (orderType === "limit") {
            if (side === "buy") {

                //Reserva BRL para nao ser usado em outra ordem antes do match
                t.set(userWalletRef(uid), {
                    saldo_brl_reservado: admin.firestore.FieldValue.increment(estimatedCost),
                    updated_at: now,
                }, { merge: true });
                writeAuditLog(t, uid, {
                    motivo: "reserva_limit_buy",
                    delta_brl_reservado: estimatedCost,
                    startup_id: startupId,
                    order_id: newOrderRef.id,
                }, now);
            }
            else {
                t.set
                //Move tokens livres para reservados (impedem dupla venda)
                (userPositionRef(uid, startupId), {
                    tokens_reservados: admin.firestore.FieldValue.increment(qty),
                    tokens_livres: admin.firestore.FieldValue.increment(-qty),
                    updated_at: now,
                }, { merge: true });
                writeAuditLog(t, uid, {
                    motivo: "reserva_limit_sell",
                    delta_tokens_reservados: qty,
                    delta_tokens_livres: -qty,
                    startup_id: startupId,
                    order_id: newOrderRef.id,
                }, now);
            }
        }

        // Processa cada trade gerado pelo matching engine
        for (const trade of matchResult.trades) {
            t.set(startupTradesRef(startupId).doc(trade.id), trade);
            const tradeCost = Number((trade.price * trade.qty).toFixed(2));

            //Comprador: debida BRL (se limite, desconta tambem na reserva)
            t.set(userWalletRef(trade.buyer_id), {
                saldo_brl: admin.firestore.FieldValue.increment(-tradeCost),
                ...(trade.buyer_order_type === "limit"
                    ? { saldo_brl_reservado: admin.firestore.FieldValue.increment(-tradeCost) }
                    : {}),
                updated_at: now,
            }, { merge: true });

            //Comprador: credita tokens
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


            
            if (trade.seller_type === "investor") {

                //vendedor(investidor): credita BRL
                t.set(userWalletRef(trade.seller_id), {
                    saldo_brl: admin.firestore.FieldValue.increment(tradeCost),
                    updated_at: now,
                }, { merge: true });

                //Vendedor: libera tokens reservados (limite) ou debida livres (mercado)
                if (trade.seller_order_type === "limit") {
                    t.set(userPositionRef(trade.seller_id, startupId), {
                        tokens_reservados: admin.firestore.FieldValue.increment(-trade.qty),
                        updated_at: now,
                    }, { merge: true });
                }
                else {
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
            }
            else if (trade.seller_type === "startup") {
                
                //Venda primaria (startup): registra receita e capta no log da startup
                t.set(db.collection("startups").doc(startupId).collection("revenue_log").doc(trade.id), {
                    trade_id: trade.id,
                    qty: trade.qty,
                    price: trade.price,
                    total_brl: tradeCost,
                    buyer_id: trade.buyer_id,
                    buyer_order_id: trade.buy_order_id,
                    created_at: now,
                });
            }
        }


        // atualiza status das ordens casadas (parcialmente ou totalmente executadas)
s
        for (const [orderId, updates] of matchResult.orderUpdates) {
            t.set(startupOrdersRef(startupId).doc(orderId), {
                ...updates,
                version: admin.firestore.FieldValue.increment(1),
            }, { merge: true });
        }

        
        // Atualiza estado global do mercado: preço, tokens vendidos, capital captado, numero de investidores
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
            ...(newInvestorsDelta > 0
                ? { nmrInvestidores: admin.firestore.FieldValue.increment(newInvestorsDelta) }
                : {}),
            updated_at: now,
        }, { merge: true });
    });

    //Atualiza best_bid/best_ask de forma assincrona (nao bloqueia resposta) 
    updateBestPrices(startupId).catch((e) => functions.logger.error("updateBestPrices failed", { startupId, error: String(e) }));

    // Remove investidor_ativo de vendedores que esvaziaram sua posição
    const investorSellerIds = [...new Set(executedTrades.filter(tr => tr.seller_type === "investor").map(tr => tr.seller_id))];
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

//Cancela uma ordem aberta do usuario
//devolve o BRL reservado ou os tokens reservados
exports.ordersCancel = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {

    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");

    await (0, rate_limit_1.enforceRateLimit)({ key: uid, action: "ordersCancel", maxPerWindow: 30, windowSeconds: 60 });

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
        //Marca a ordem como cancelada
        t.update(orderRef, {
            status: "cancelada",
            updated_at: now,
            version: admin.firestore.FieldValue.increment(1),
        });

        //devolve BRL reservado para compras a limite canceladas
        if (order.side === "buy" && order.order_type === "limit") {
            const refund = Number((order.price * order.qty_restante).toFixed(2));
            t.set(userWalletRef(uid), {
                saldo_brl_reservado: admin.firestore.FieldValue.increment(-refund),
                updated_at: now,
            }, { merge: true });
            writeAuditLog(t, uid, {
                motivo: "cancel_limit_buy_refund",
                delta_brl_reservado: -refund,
                startup_id: startupId,
                order_id: orderId,
            }, now);
        }

        //Devolve tokens reservados para vendas a limite canceladas
        if (order.side === "sell" && order.order_type === "limit") {
            t.set(userPositionRef(uid, startupId), {
                tokens_reservados: admin.firestore.FieldValue.increment(-order.qty_restante),
                tokens_livres: admin.firestore.FieldValue.increment(order.qty_restante),
                updated_at: now,
            }, { merge: true });
            writeAuditLog(t, uid, {
                motivo: "cancel_limit_sell_release",
                delta_tokens_reservados: -order.qty_restante,
                delta_tokens_livres: order.qty_restante,
                startup_id: startupId,
                order_id: orderId,
            }, now);
        }

        //Registra mudança de status no historico de ordens
        t.set(userOrderHistoryRef(uid, orderId), {
            status_changes: admin.firestore.FieldValue.arrayUnion({ status: "cancelada", at: now }),
        }, { merge: true });
    });

    updateBestPrices(startupId).catch((e) => functions.logger.error("updateBestPrices failed", { startupId, error: String(e) }));
    return { success: true };
});


//Retorna o livro de ordens atual de uma startup
//devolve os 20 melhores bids (compra) e 20 melhores asks (vendas)

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

    //Bids: maior preço primeiro
    const buyOrders = orders
        .filter(o => o.side === "buy")
        .sort((a, b) => b.price - a.price)
        .slice(0, 20);
    
    //Asks: menor preço primeiro 
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


//Retorna o historico de trades de uma startup em paginação

exports.getTrades = functions
    .region("southamerica-east1")
    .https.onCall(async (data, _context) => {

    const startupId = requireString(data.startup_id, "startup_id");
    //Limita entre 1 e 50 resultados; padrao 20
    const limitVal = typeof data.limit === "number" ? Math.min(Math.max(data.limit, 1), 50) : 20;

    let query = startupTradesRef(startupId)
        .orderBy("executed_at", "desc")
        .limit(limitVal);

    //Paginação: se 'after' for passado, busca a partir daquele trade
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



// Admin ceria a ordem inicial de venda da startup no mercado primario 
// com o preço e quantidade de emissao configuradas

exports.inicializarOrdemEmissao = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {

    const uid = context.auth?.uid;
    if (!uid)
        throwHttp("unauthenticated", "Usuário não autenticado.");

    //verifica se é admin
    const adminSnap = await db.collection("usuarios").doc(uid).get();
    if (!adminSnap.exists || adminSnap.data()?.isAdmin !== true) {
        throwHttp("permission-denied", "Apenas admin pode inicializar ordem de emissão.");
    }

    const startupId = requireString(data.startup_id, "startup_id");
    const startupSnap = await db.collection("startups").doc(startupId).get();
    if (!startupSnap.exists)
        throwHttp("not-found", "Startup não encontrada.");

    const config = await readConfig(startupId);
    if (config.tokens_emitidos <= 0 || config.preco_emissao <= 0) {
        throwHttp("failed-precondition", "Config inválida: tokens_emitidos/preco_emissao precisam ser positivos.");
    }
    // Verifica a idepotencia: retorna se ja existe ordem de emissão aberta
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

    //Cria a ordem de venda da startup com todos os tokens disponiveus ao preço de emissao
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
    }
    else {
        updateBestPrices(startupId).catch((e) => functions.logger.error("updateBestPrices failed", { startupId, error: String(e) }));
    }
    return { success: true, order_id: orderRef.id };
});

//Internal: atualzia best_bid / best_ask após mudanças no orderbook

//recalcula e persiste o melhor preço de compra (best_bid), melhor preço de venda (best_ask)
// e o spread (diferença entre eles) no estado do balcão
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
