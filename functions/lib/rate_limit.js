//Pedro Andre do Carmo Chavier -25018639

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
exports.enforceRateLimit = enforceRateLimit;

//Acesso ao Firestore pelo backend
const admin = __importStar(require("firebase-admin")); 
//Importa firebase Functions para lançar erros Http
const functions = __importStar(require("firebase-functions/v1"));

//Conta quantas vezes o usuario usou uma função, e bloqueia se passou do limite
async function enforceRateLimit(params) {
    const { key, action, maxPerWindow, windowSeconds } = params;
    if (!key)
        return;

    const db = admin.firestore();

    //Divide o tempo em blocos fixos
    const windowStart = Math.floor(Date.now() / 1000 / windowSeconds) * windowSeconds;

    //id do contador = ação + usuario + bloco de tempo
    const docId = `${action}_${key}_${windowStart}`;
    const ref = db.collection("rate_limits").doc(docId);

    //Permite que dois pedidos simultaneos nao passam do limite ao mesmo tempo
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref); // le o contador atual
        const count = snap.data()?.count ?? 0;

        //se ja atingiu o limite, bloqueia e retorna erro
        if (count >= maxPerWindow) {
            throw new functions.https.HttpsError("resource-exhausted", `Limite de requisicoes atingido para ${action}. Tente novamente em alguns segundos.`);
        }

        // se ainda esta dentro do limite, soma + 1
        tx.set(ref, {
            count: admin.firestore.FieldValue.increment(1),
            action,
            key,
            window_start: windowStart,
            expires_at: admin.firestore.Timestamp.fromMillis((windowStart + windowSeconds * 2) * 1000),
        }, { merge: true });
    });
}
