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
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
/**
 * Rate limit por chave (uid ou email) numa janela deslizante simples.
 * Usa Firestore para persistir contagem por janela. Janela = bucket de N segundos.
 *
 * Uso:
 *   await enforceRateLimit({ key: uid, action: "ordersCreate", maxPerWindow: 30, windowSeconds: 60 });
 *
 * Em violacao, lanca HttpsError "resource-exhausted".
 */
async function enforceRateLimit(params) {
    const { key, action, maxPerWindow, windowSeconds } = params;
    if (!key)
        return;
    const db = admin.firestore();
    const windowStart = Math.floor(Date.now() / 1000 / windowSeconds) * windowSeconds;
    const docId = `${action}_${key}_${windowStart}`;
    const ref = db.collection("rate_limits").doc(docId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const count = snap.data()?.count ?? 0;
        if (count >= maxPerWindow) {
            throw new functions.https.HttpsError("resource-exhausted", `Limite de requisicoes atingido para ${action}. Tente novamente em alguns segundos.`);
        }
        tx.set(ref, {
            count: admin.firestore.FieldValue.increment(1),
            action,
            key,
            window_start: windowStart,
            expires_at: admin.firestore.Timestamp.fromMillis((windowStart + windowSeconds * 2) * 1000),
        }, { merge: true });
    });
}
