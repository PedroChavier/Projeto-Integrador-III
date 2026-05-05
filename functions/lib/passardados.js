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
exports.popularStartupsFirestore = void 0;
const fs = __importStar(require("node:fs"));
const path = __importStar(require("node:path"));
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
exports.popularStartupsFirestore = functions.https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).json({
            success: false,
            message: "Use o metodo POST para importar as startups.",
        });
        return;
    }
    try {
        const startups = carregarStartupsJson();
        const startupsRef = db.collection("startups");
        const startupsSnapshot = await startupsRef.get();
        const startupsExistentes = new Map();
        const batch = db.batch();
        for (const doc of startupsSnapshot.docs) {
            const nome = doc.get("nome");
            if (typeof nome === "string" && nome.trim().length > 0) {
                startupsExistentes.set(normalizarNome(nome), doc.ref);
            }
        }
        for (const startup of startups) {
            const startupKey = normalizarNome(startup.nome);
            const docRef = startupsExistentes.get(startupKey) ??
                startupsRef.doc();
            const capitalAportado = startup.tokens_emitidos * startup.preco_token;
            const isNovoDocumento = !startupsExistentes.has(startupKey);
            const payload = {
                uid: docRef.id,
                nome: startup.nome.trim(),
                descricao: startup.bio.trim(),
                bio: startup.bio.trim(),
                setor: startup.setor.trim(),
                status: startup.status.trim(),
                ativo: startup.ativo,
                totalTokensEmitidos: startup.tokens_emitidos,
                tokensEmitidos: startup.tokens_emitidos,
                precoToken: startup.preco_token,
                preco_token: startup.preco_token,
                nmrInvestidores: startup.nmr_investidores,
                nmr_investidores: admin.firestore.FieldValue.delete(),
                cptAportado: capitalAportado,
                capitalAportado,
                estagioDesenvolvimento: normalizarEstagio(startup.status),
                origemCarga: "Startups.json",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (isNovoDocumento) {
                payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
                startupsExistentes.set(startupKey, docRef);
            }
            batch.set(docRef, payload, { merge: true });
        }
        await batch.commit();
        res.status(200).json({
            success: true,
            message: "Startups importadas com sucesso.",
            totalImportadas: startups.length,
            collection: "startups",
        });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Falha ao importar startups.";
        res.status(500).json({
            success: false,
            message,
        });
    }
});
function carregarStartupsJson() {
    const filePath = path.resolve(__dirname, "..", "src", "Startups.json");
    const raw = fs.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
        throw new Error("O arquivo Startups.json nao contem uma lista valida.");
    }
    return parsed.map(validarStartupJson);
}
function validarStartupJson(item) {
    if (!item || typeof item !== "object") {
        throw new Error("Foi encontrado um registro invalido no Startups.json.");
    }
    const startup = item;
    return {
        nome: lerStringObrigatoria(startup.nome, "nome"),
        setor: lerStringObrigatoria(startup.setor, "setor"),
        status: lerStringObrigatoria(startup.status, "status"),
        ativo: lerBoolean(startup.ativo, "ativo"),
        bio: lerStringObrigatoria(startup.bio, "bio"),
        tokens_emitidos: lerNumero(startup.tokens_emitidos, "tokens_emitidos"),
        preco_token: lerNumero(startup.preco_token, "preco_token"),
        nmr_investidores: lerNumeroInteiro(startup.nmr_investidores, "nmr_investidores"),
    };
}
function lerStringObrigatoria(value, fieldName) {
    if (typeof value !== "string" || value.trim().length === 0) {
        throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
    }
    return value;
}
function lerBoolean(value, fieldName) {
    if (typeof value !== "boolean") {
        throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
    }
    return value;
}
function lerNumero(value, fieldName) {
    if (typeof value !== "number" || !Number.isFinite(value)) {
        throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
    }
    return value;
}
function lerNumeroInteiro(value, fieldName) {
    const numero = lerNumero(value, fieldName);
    if (!Number.isInteger(numero)) {
        throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
    }
    return numero;
}
function normalizarEstagio(status) {
    const normalizado = status
        .trim()
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/\s+/g, "");
    if (normalizado.includes("operacao")) {
        return "emOperacao";
    }
    if (normalizado.includes("expansao")) {
        return "emExpansao";
    }
    return "nova";
}
function normalizarNome(nome) {
    return nome
        .trim()
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "");
}
//# sourceMappingURL=passardados.js.map