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
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.listarStartups = exports.comprarTokensStartup = exports.creditarSaldoSimulado = exports.verificarCodigoMfaCallable = exports.solicitarCodigoMfa = exports.redefinirSenhaComCodigo = exports.solicitarCodigoRecuperacaoSenha = exports.excluirPerfilAoExcluirAuth = exports.registrarUsuario = void 0;
const node_crypto_1 = require("node:crypto");
const net = __importStar(require("node:net"));
const tls = __importStar(require("node:tls"));
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
const mfa_code_1 = require("./mfa_code");
__exportStar(require("./mfa_code"), exports);
// Inicializa o SDK do Firebase Admin (requisito para acesso ao Auth/Firestore).
admin.initializeApp();
const db = admin.firestore();
const usuariosCollection = db.collection("usuarios");
const passwordRecoveryCollection = db.collection("passwordRecoveryCodes");
const recoveryCodeTtlMinutes = 10;
const recoveryCodeLength = 6;
const passwordMinLength = 8;
const passwordMaxLength = 20;
const passwordPolicyMessage = "A senha deve ter entre 8 e 20 caracteres e incluir letra maiuscula, minuscula, numero e caractere especial.";
// Função Callable: registra um usuário (valida autenticação, sanitiza payload, evita CPF duplicado e salva/merge no Firestore).
exports.registrarUsuario = functions
    .region('southamerica-east1')
    .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
    }
    const payload = normalizarPayload(data, context.auth.token.email);
    const userId = context.auth.uid;
    await validarCpfDisponivel(payload.cpf, userId);
    await usuariosCollection.doc(userId).set({
        ...payload,
        uid: userId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        success: true,
        uid: userId,
    };
});
// Trigger Auth: ao remover usuário no Firebase Auth, tenta remover o perfil correspondente no Firestore.
exports.excluirPerfilAoExcluirAuth = functions
    .region('southamerica-east1')
    .auth
    .user()
    .onDelete(async (user) => {
    await usuariosCollection.doc(user.uid).delete().catch(() => undefined);
});
// Função Callable: solicita código de recuperação de senha, armazenando hash do código no Firestore e enviando e-mail.
exports.solicitarCodigoRecuperacaoSenha = functions
    .region('southamerica-east1')
    .https.onCall(async (data) => {
    const email = sanitizeEmail(data.email);
    const response = {
        success: true,
        message: "Se existir uma conta com este e-mail, um codigo de recuperacao foi enviado.",
    };
    let user;
    try {
        user = await admin.auth().getUserByEmail(email);
    }
    catch (error) {
        if (isAuthUserNotFound(error)) {
            return response;
        }
        throw toHttpsError(error, "Nao foi possivel iniciar a recuperacao de senha.");
    }
    const code = generateNumericCode(recoveryCodeLength);
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + recoveryCodeTtlMinutes * 60 * 1000));
    await passwordRecoveryCollection.doc(buildRecoveryDocId(email)).set({
        uid: user.uid,
        email,
        codeHash: hashRecoveryCode(email, code),
        attempts: 0,
        usedAt: null,
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await sendRecoveryCodeEmail({
        to: email,
        code,
        expiresInMinutes: recoveryCodeTtlMinutes,
    });
    return response;
});
// Função Callable: valida código de recuperação e redefine a senha do usuário no Firebase Auth, marcando o uso do código.
exports.redefinirSenhaComCodigo = functions
    .region('southamerica-east1')
    .https.onCall(async (data) => {
    const email = sanitizeEmail(data.email);
    const code = sanitizeRecoveryCode(data.code);
    const newPassword = sanitizeNewPassword(data.newPassword);
    const recoveryRef = passwordRecoveryCollection.doc(buildRecoveryDocId(email));
    const recoverySnapshot = await recoveryRef.get();
    if (!recoverySnapshot.exists) {
        throw new functions.https.HttpsError("not-found", "Nenhum codigo de recuperacao foi solicitado para este e-mail.");
    }
    const recoveryData = recoverySnapshot.data();
    const expiresAt = recoveryData?.expiresAt;
    const usedAt = recoveryData?.usedAt;
    const storedHash = recoveryData?.codeHash;
    if (!expiresAt || typeof storedHash !== "string") {
        throw new functions.https.HttpsError("failed-precondition", "O codigo de recuperacao armazenado esta invalido.");
    }
    if (usedAt) {
        throw new functions.https.HttpsError("failed-precondition", "Este codigo ja foi utilizado.");
    }
    if (expiresAt.toDate().getTime() < Date.now()) {
        throw new functions.https.HttpsError("deadline-exceeded", "O codigo informado expirou. Solicite um novo envio.");
    }
    if (storedHash !== hashRecoveryCode(email, code)) {
        await recoveryRef.set({
            attempts: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        throw new functions.https.HttpsError("permission-denied", "O codigo informado esta incorreto.");
    }
    let user;
    try {
        user = await admin.auth().getUserByEmail(email);
    }
    catch (error) {
        throw toHttpsError(error, "Nao foi possivel localizar a conta do usuario.");
    }
    await admin.auth().updateUser(user.uid, { password: newPassword });
    await recoveryRef.set({
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        success: true,
        message: "Senha redefinida com sucesso.",
    };
});
// Funcao Callable: gera, persiste e envia um codigo MFA para o canal escolhido pelo usuario autenticado.
exports.solicitarCodigoMfa = functions
    .region('southamerica-east1')
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
    }
    const canal = sanitizeMfaChannel(data.canal);
    const usuarioSnapshot = await usuariosCollection.doc(uid).get();
    const usuarioData = usuarioSnapshot.data();
    if (!usuarioSnapshot.exists || !usuarioData) {
        throw new functions.https.HttpsError("not-found", "Perfil do usuario nao encontrado.");
    }
    const fullName = typeof usuarioData.fullName === "string" ? usuarioData.fullName.trim() : "";
    const email = typeof usuarioData.email === "string" ? usuarioData.email.trim() : "";
    const telefone = typeof usuarioData.telefone === "string" ? usuarioData.telefone.trim() : "";
    const mfaHabilitado = usuarioData.mfaHabilitado === true;
    if (!mfaHabilitado) {
        throw new functions.https.HttpsError("failed-precondition", "A autenticacao multifator nao esta habilitada para este usuario.");
    }
    if (canal === "email" && !email) {
        throw new functions.https.HttpsError("failed-precondition", "O usuario nao possui e-mail cadastrado para MFA.");
    }
    if (canal === "sms" && !telefone) {
        throw new functions.https.HttpsError("failed-precondition", "O usuario nao possui telefone cadastrado para MFA.");
    }
    const codigo = (0, mfa_code_1.gerarCodigoMfaSeisDigitos)();
    await (0, mfa_code_1.salvarCodigoMfaNoFirebase)({
        uid,
        email,
        telefone,
        canal,
        codigo,
    });
    if (canal === "email") {
        await (0, mfa_code_1.enviarCodigoMfaPorEmail)({
            to: email,
            codigo,
            nome: fullName,
        });
    }
    else {
        await (0, mfa_code_1.enviarCodigoMfaPorSms)({
            to: telefone,
            codigo,
            nome: fullName,
        });
    }
    return {
        success: true,
        canal,
        message: `Codigo MFA enviado por ${canal === "email" ? "e-mail" : "SMS"}.`,
    };
});
// Funcao Callable: verifica o codigo MFA fornecido pelo usuario autenticado, validando contra o armazenado.
exports.verificarCodigoMfaCallable = functions
    .region('southamerica-east1')
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
    }
    const codigo = sanitizeRequiredString(data.codigo, "Codigo MFA");
    const canal = sanitizeMfaChannel(data.canal);
    await (0, mfa_code_1.verificarCodigoMfa)({
        uid,
        codigo,
        canal,
    });
    return {
        success: true,
        message: "Codigo MFA verificado com sucesso.",
    };
});
// Funcao Callable: credita saldo simulado com privilegios de Admin SDK para evitar bloqueios das regras do cliente.
exports.creditarSaldoSimulado = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
    }
    const valor = sanitizePositiveNumber(data.valor, "Valor");
    const usuarioRef = usuariosCollection.doc(uid);
    const transacaoRef = usuarioRef.collection("transacoes").doc();
    const usuarioSnapshot = await usuarioRef.get();
    const batch = db.batch();
    if (usuarioSnapshot.exists) {
        batch.set(usuarioRef, {
            saldo: admin.firestore.FieldValue.increment(valor),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    else {
        const authUser = await admin.auth().getUser(uid);
        batch.set(usuarioRef, {
            uid,
            fullName: authUser.displayName?.trim() ?? "",
            email: authUser.email?.trim().toLowerCase() ?? "",
            telefone: authUser.phoneNumber?.replace(/\D/g, "") ?? "",
            cpf: "",
            saldo: valor,
            role: "user",
            isAdmin: false,
            mfaHabilitado: false,
            userActive: true,
            userloggedIn: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    batch.set(transacaoRef, {
        tipo: "deposito",
        titulo: "Credito Simulado",
        subtitulo: formatTransactionDate(new Date()),
        valor,
        positivo: true,
        fonte: "Externo",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {
        success: true,
        valor,
    };
});
exports.comprarTokensStartup = functions
    .region("southamerica-east1")
    .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Usuario nao autenticado.");
    }
    const startupUid = sanitizeRequiredString(data.startupUid, "Startup");
    const quantidade = sanitizePositiveInteger(data.quantidade, "Quantidade");
    const startupRef = db.collection("startups").doc(startupUid);
    const usuarioRef = usuariosCollection.doc(uid);
    const transacaoRef = usuarioRef.collection("transacoes").doc();
    const [startupSnapshot, usuarioSnapshot] = await Promise.all([
        startupRef.get(),
        usuarioRef.get(),
    ]);
    if (!startupSnapshot.exists) {
        throw new functions.https.HttpsError("not-found", "Startup nao encontrada.");
    }
    const startupData = startupSnapshot.data();
    const precoToken = pickPrecoFromData(startupData, toNumber(startupData.cptAportado ?? startupData.capitalAportado ?? startupData.cpt) ?? 0, toNumber(startupData.totalTokensEmitidos ?? startupData.totalTokens ?? startupData.tokensEmitidos) ?? 0);
    if (!Number.isFinite(precoToken) || precoToken <= 0) {
        throw new functions.https.HttpsError("failed-precondition", "A startup nao possui preco de token disponivel.");
    }
    const usuarioData = (usuarioSnapshot.data() ?? {});
    const saldoAtual = toNumber(usuarioData.saldo) ?? 0;
    const valorTotal = Number((precoToken * quantidade).toFixed(2));
    if (saldoAtual < valorTotal) {
        throw new functions.https.HttpsError("failed-precondition", "Saldo insuficiente para concluir a compra.");
    }
    const portfolio = toRecord(usuarioData.portfolio);
    const holdingAtual = toRecord(portfolio[startupUid]);
    const quantidadeAtual = toNumber(holdingAtual.quantidade) ?? 0;
    const valorInvestidoAtual = toNumber(holdingAtual.valorInvestido) ?? 0;
    const novaQuantidade = quantidadeAtual + quantidade;
    const novoValorInvestido = Number((valorInvestidoAtual + valorTotal).toFixed(2));
    const precoMedio = novaQuantidade > 0
        ? Number((novoValorInvestido / novaQuantidade).toFixed(2))
        : 0;
    const startupNome = typeof startupData.nome === "string" ? startupData.nome.trim() : startupUid;
    const startupSetor = typeof startupData.setor === "string" ? startupData.setor.trim() : "";
    const batch = db.batch();
    batch.set(usuarioRef, {
        saldo: admin.firestore.FieldValue.increment(-valorTotal),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        portfolio: {
            [startupUid]: {
                startupUid,
                startupNome,
                startupSetor,
                quantidade: novaQuantidade,
                precoMedio,
                valorInvestido: novoValorInvestido,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        },
    }, { merge: true });
    batch.set(transacaoRef, {
        tipo: "compra_token",
        titulo: `Compra de ${startupNome}`,
        subtitulo: `${quantidade} token(s) a ${formatPrecoBRL(precoToken)}`,
        valor: valorTotal,
        positivo: false,
        fonte: "Mercado",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(startupRef, {
        cptAportado: admin.firestore.FieldValue.increment(valorTotal),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    return {
        success: true,
        startupUid,
        quantidade,
        valorTotal,
    };
});
// Normaliza a etapa/estágio (strings/nums diversos) para um conjunto reduzido de valores canônicos.
function normalizeStage(raw) {
    if (raw === null || raw === undefined)
        return "nova";
    if (typeof raw === "string") {
        const normalized = raw
            .trim()
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, ""); // remove acentos
        if (normalized === "nova")
            return "nova";
        if (normalized === "emoperacao" || normalized === "em-operacao")
            return "emOperacao";
        if (normalized === "emexpansao" || normalized === "em-expansao")
            return "emExpansao";
        // fallback por substring
        if (normalized.includes("nova"))
            return "nova";
        if (normalized.includes("operacao"))
            return "emOperacao";
        if (normalized.includes("expansao"))
            return "emExpansao";
    }
    if (typeof raw === "number") {
        if (raw === 0)
            return "nova";
        if (raw === 1)
            return "emOperacao";
        if (raw === 2)
            return "emExpansao";
    }
    return "nova";
}
// Converte o estágio normalizado em um rótulo amigável para UI.
function stageLabel(raw) {
    const stage = normalizeStage(raw);
    switch (stage) {
        case "emOperacao":
            return "Em operação";
        case "emExpansao":
            return "Em expansão";
        case "nova":
        default:
            return "Nova";
    }
}
// Converte valores potencialmente string/number para um number finito; caso não seja válido, retorna null.
function toNumber(raw) {
    if (typeof raw === "number" && Number.isFinite(raw))
        return raw;
    if (typeof raw === "string") {
        const cleaned = raw
            .replace(/\s/g, "")
            .replace(/\./g, "")
            .replace(",", ".");
        const parsed = Number(cleaned);
        return Number.isFinite(parsed) ? parsed : null;
    }
    return null;
}
// Formata números grandes de forma compacta (k/M) para reduzir tamanho no catálogo.
function formatCompactNumberBR(value) {
    const abs = Math.abs(value);
    if (abs >= 1000000)
        return `${Math.round(value / 1000000)}M`;
    if (abs >= 1000)
        return `${Math.round(value / 1000)}k`;
    return `${Math.round(value)}`;
}
// Adiciona prefixo monetário (R$) ao número compactado.
function formatCapital(value) {
    return `R$ ${formatCompactNumberBR(value)}`;
}
// Formata tokens (usando o mesmo estilo compactado), delegando para função compartilhada.
function formatTokens(value) {
    // a UI hoje usa ex.: "50k"
    // se vier null/0, devolve "0"
    return absRoundToCompact(value);
}
// Formata números de forma compacta com sufixo (k/M/B), usando arredondamento.
function absRoundToCompact(value) {
    const abs = Math.abs(value);
    if (abs >= 1000000000)
        return `${Math.round(value / 1000000000)}B`;
    if (abs >= 1000000)
        return `${Math.round(value / 1000000)}M`;
    if (abs >= 1000)
        return `${Math.round(value / 1000)}k`;
    return `${Math.round(value)}`;
}
// Formata preço em Real Brasileiro, com 2 casas e vírgula decimal (ex.: "R$ 25,00").
function formatPrecoBRL(value) {
    // UI hoje usa "R$ 25,00"
    const fixed = value.toFixed(2);
    const withComma = fixed.replace(".", ",");
    return `R$ ${withComma}`;
}
// Seleciona o preço a partir de múltiplos campos possíveis no documento; se não houver, usa fallback (cptAportado / totalTokens).
function pickPrecoFromData(data, cptAportado, totalTokens) {
    // tenta campos comuns se existirem
    const possibleFields = [
        "preco",
        "precoToken",
        "preco_token",
        "precoTokenAtual",
        "preco_atual",
    ];
    for (const key of possibleFields) {
        const maybe = toNumber(data[key]);
        if (maybe !== null)
            return maybe;
    }
    // fallback: preco = cptAportado / totalTokens
    if (totalTokens > 0)
        return cptAportado / totalTokens;
    return 0;
}
// Função Callable: lista startups do Firestore e retorna itens formatados (capital/tokens/preço) para o catálogo.
exports.listarStartups = functions
    .region('southamerica-east1')
    .https.onCall(async (_data, _context) => {
    // tenta múltiplos nomes de coleção (pra não quebrar se o schema estiver diferente)
    const collectionsToTry = ["startups", "Startups", "startup"];
    let snapshot = null;
    for (const collectionName of collectionsToTry) {
        const snap = await db.collection(collectionName).get();
        if (!snap.empty) {
            snapshot = snap;
            break;
        }
    }
    const docs = snapshot?.docs ?? [];
    const startups = docs.map((doc) => {
        const data = doc.data();
        const nome = typeof data.nome === "string" ? data.nome : "";
        const descricao = typeof data.descricao === "string" ? data.descricao : "";
        const estagio = data.estagioDesenvolvimento ?? data.estagio ?? data.stage;
        const status = stageLabel(estagio);
        const totalTokensRaw = data.totalTokensEmitidos ?? data.totalTokens ?? data.tokensEmitidos;
        const cptAportadoRaw = data.cptAportado ?? data.capitalAportado ?? data.cpt;
        const totalTokens = toNumber(totalTokensRaw) ?? 0;
        const cptAportado = toNumber(cptAportadoRaw) ?? 0;
        const preco = pickPrecoFromData(data, cptAportado, totalTokens);
        return {
            nome,
            descricao,
            status,
            tokens: formatTokens(totalTokens),
            capital: formatCapital(cptAportado),
            preco: formatPrecoBRL(preco),
        };
    });
    return { startups };
});
// Valida se um CPF já está disponível para cadastro; se existir outro usuário com o mesmo CPF, lança erro.
async function validarCpfDisponivel(cpf, userId) {
    const snapshot = await usuariosCollection
        .where("cpf", "==", cpf)
        .limit(1)
        .get();
    if (!snapshot.empty && snapshot.docs[0]?.id !== userId) {
        throw new functions.https.HttpsError("already-exists", "Ja existe um usuario cadastrado com este CPF.");
    }
}
// Sanitiza e normaliza o payload de registro (CPF/telefone/e-mail/senha/data) para um objeto consistente.
function normalizarPayload(data, emailAutenticado) {
    const cpf = sanitizeDigits(data.cpf, "CPF");
    const fullName = sanitizeRequiredString(data.fullName, "Nome completo");
    const telefone = sanitizeDigits(data.telefone, "Telefone");
    const senha = hashPassword(sanitizeRequiredString(data.senha, "Senha"));
    const email = sanitizeEmail(data.email ?? emailAutenticado);
    const dataNascimento = sanitizeBirthDate(data.dataNascimento);
    const mfaHabilitado = Boolean(data.mfaHabilitado);
    const userActive = data.userActive === undefined ? true : Boolean(data.userActive);
    const userloggedIn = data.userloggedIn === undefined ? true : Boolean(data.userloggedIn);
    if (cpf.length !== 11) {
        throw new functions.https.HttpsError("invalid-argument", "CPF invalido.");
    }
    if (telefone.length < 10 || telefone.length > 11) {
        throw new functions.https.HttpsError("invalid-argument", "Telefone invalido.");
    }
    if (typeof emailAutenticado === "string" &&
        emailAutenticado.trim().toLowerCase() !== email) {
        throw new functions.https.HttpsError("invalid-argument", "O e-mail autenticado difere do payload enviado.");
    }
    return {
        cpf,
        fullName,
        dataNascimento,
        email,
        senha,
        telefone,
        mfaHabilitado,
        userActive,
        userloggedIn,
    };
}
// Hasheia a senha recebida com SHA-256 (com validação mínima de tamanho) antes de salvar no Firestore.
function hashPassword(password) {
    validatePasswordPolicy(password);
    return (0, node_crypto_1.createHash)("sha256").update(password).digest("hex");
}
// Sanitiza e valida o código de recuperação (somente dígitos, com tamanho exato).
function sanitizeRecoveryCode(value) {
    const raw = sanitizeRequiredString(value, "Codigo");
    const digits = raw.replace(/\D/g, "");
    if (digits.length !== recoveryCodeLength) {
        throw new functions.https.HttpsError("invalid-argument", `O codigo deve conter ${recoveryCodeLength} digitos.`);
    }
    return digits;
}
// Sanitiza a nova senha e valida tamanho mínimo para redefinição.
function sanitizeNewPassword(value) {
    const password = sanitizeRequiredString(value, "Nova senha");
    validatePasswordPolicy(password);
    return password;
}
function validatePasswordPolicy(password) {
    const isValidLength = password.length >= passwordMinLength && password.length <= passwordMaxLength;
    const hasUppercase = /[A-Z]/.test(password);
    const hasLowercase = /[a-z]/.test(password);
    const hasNumber = /[0-9]/.test(password);
    const hasSpecialCharacter = /[^A-Za-z0-9]/.test(password);
    if (!isValidLength ||
        !hasUppercase ||
        !hasLowercase ||
        !hasNumber ||
        !hasSpecialCharacter) {
        throw new functions.https.HttpsError("invalid-argument", passwordPolicyMessage);
    }
}
// Garante que um campo seja string não vazia (trim), senão lança HttpsError.
function sanitizeRequiredString(value, fieldName) {
    if (typeof value != "string") {
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} obrigatorio.`);
    }
    const normalized = value.trim();
    if (!normalized) {
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} obrigatorio.`);
    }
    return normalized;
}
// Sanitiza campos numéricos representados como texto (mantém apenas dígitos), usando sanitizeRequiredString.
function sanitizeDigits(value, fieldName) {
    const raw = sanitizeRequiredString(value, fieldName);
    return raw.replace(/\D/g, "");
}
// Sanitiza e valida e-mail por regex, convertendo para lowercase.
function sanitizeEmail(value) {
    const email = sanitizeRequiredString(value, "E-mail").toLowerCase();
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailPattern.test(email)) {
        throw new functions.https.HttpsError("invalid-argument", "E-mail invalido.");
    }
    return email;
}
// Converte string de data em Timestamp do Firestore; rejeita datas inválidas e datas no futuro.
function sanitizeBirthDate(value) {
    const raw = sanitizeRequiredString(value, "Data de nascimento");
    const parsedDate = new Date(raw);
    if (Number.isNaN(parsedDate.getTime()) || parsedDate > new Date()) {
        throw new functions.https.HttpsError("invalid-argument", "Data de nascimento invalida.");
    }
    return admin.firestore.Timestamp.fromDate(parsedDate);
}
// Valida o canal escolhido para envio do desafio MFA.
function sanitizeMfaChannel(value) {
    if (value !== "email" && value !== "sms") {
        throw new functions.https.HttpsError("invalid-argument", "Informe um canal MFA valido: email ou sms.");
    }
    return value;
}
function sanitizePositiveNumber(value, fieldName) {
    if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} invalido.`);
    }
    return value;
}
function sanitizePositiveInteger(value, fieldName) {
    if (typeof value !== "number" ||
        !Number.isInteger(value) ||
        !Number.isFinite(value) ||
        value <= 0) {
        throw new functions.https.HttpsError("invalid-argument", `${fieldName} invalida.`);
    }
    return value;
}
function toRecord(value) {
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
        return {};
    }
    return value;
}
function formatTransactionDate(data) {
    const meses = [
        "",
        "jan",
        "fev",
        "mar",
        "abr",
        "mai",
        "jun",
        "jul",
        "ago",
        "set",
        "out",
        "nov",
        "dez",
    ];
    const hora = data.getHours().toString().padStart(2, "0");
    const minuto = data.getMinutes().toString().padStart(2, "0");
    return `${data.getDate()} ${meses[data.getMonth() + 1]} ${data.getFullYear()} - ${hora}:${minuto}`;
}
// Cria um ID determinístico para o documento de recuperação de senha, derivado do e-mail (hash).
function buildRecoveryDocId(email) {
    return (0, node_crypto_1.createHash)("sha256").update(email).digest("hex");
}
// Gera hash do código de recuperação combinando e-mail e código, para comparar sem armazenar o código em claro.
function hashRecoveryCode(email, code) {
    return (0, node_crypto_1.createHash)("sha256").update(`${email}:${code}`).digest("hex");
}
// Gera um código numérico aleatório com o comprimento especificado.
function generateNumericCode(length) {
    return Array.from({ length }, () => (0, node_crypto_1.randomInt)(0, 10)).join("");
}
// Detecta especificamente o erro do Firebase Auth quando o usuário não é encontrado por e-mail.
function isAuthUserNotFound(error) {
    return (typeof error === "object" &&
        error !== null &&
        "code" in error &&
        error.code === "auth/user-not-found");
}
// Converte um erro arbitrário em HttpsError, reaproveitando HttpsError existentes e usando fallback se necessário.
function toHttpsError(error, fallbackMessage) {
    if (error instanceof functions.https.HttpsError) {
        return error;
    }
    const message = error instanceof Error && error.message.trim().length > 0
        ? error.message
        : fallbackMessage;
    return new functions.https.HttpsError("internal", message);
}
// Envia o e-mail de recuperação de senha via conexão TCP/TLS, executando o fluxo SMTP manualmente.
async function sendRecoveryCodeEmail({ to, code, expiresInMinutes, }) {
    const smtp = getSmtpConfig();
    const socket = await connectSmtp(smtp);
    try {
        await expectResponse(socket, 220);
        await sendCommand(socket, `EHLO ${smtp.host}`, 250);
        await sendCommand(socket, `AUTH LOGIN`, 334);
        await sendCommand(socket, Buffer.from(smtp.user, "utf8").toString("base64"), 334);
        await sendCommand(socket, Buffer.from(smtp.pass, "utf8").toString("base64"), 235);
        await sendCommand(socket, `MAIL FROM:<${smtp.fromEmail}>`, 250);
        await sendCommand(socket, `RCPT TO:<${to}>`, 250);
        await sendCommand(socket, "DATA", 354);
        const message = buildRawEmail({
            fromEmail: smtp.fromEmail,
            fromName: smtp.fromName,
            to,
            subject: "Codigo de recuperacao de senha",
            text: [
                "Voce solicitou a recuperacao da sua senha.",
                `Seu codigo de verificacao e: ${code}`,
                `Este codigo expira em ${expiresInMinutes} minutos.`,
                "Se voce nao solicitou esta alteracao, ignore este e-mail.",
            ].join("\n"),
            html: [
                "<p>Voce solicitou a recuperacao da sua senha.</p>",
                `<p><strong>Seu codigo de verificacao e: ${code}</strong></p>`,
                `<p>Este codigo expira em ${expiresInMinutes} minutos.</p>`,
                "<p>Se voce nao solicitou esta alteracao, ignore este e-mail.</p>",
            ].join(""),
        });
        socket.write(`${escapeSmtpData(message)}\r\n.\r\n`);
        await expectResponse(socket, 250);
        await sendCommand(socket, "QUIT", 221);
    }
    finally {
        socket.end();
    }
}
// Lê configuração SMTP das Cloud Functions (configurações expostas via functions.config()).
function getSmtpConfig() {
    const smtp = functions.config().smtp;
    if (!smtp?.host || !smtp?.user || !smtp?.pass || !smtp?.from_email) {
        throw new functions.https.HttpsError("failed-precondition", "As credenciais SMTP nao foram configuradas nas Cloud Functions.");
    }
    return {
        host: String(smtp.host),
        port: Number(smtp.port ?? 465),
        secure: smtp.secure === undefined ? true : String(smtp.secure) === "true",
        user: String(smtp.user),
        pass: String(smtp.pass),
        fromEmail: String(smtp.from_email),
        fromName: String(smtp.from_name ?? "Mescla Invest"),
    };
}
// Conecta ao servidor SMTP via TLS (secure) ou TCP simples (insecure), retornando um socket pronto para comandos.
async function connectSmtp(smtp) {
    return await new Promise((resolve, reject) => {
        const onError = (error) => reject(error);
        if (smtp.secure) {
            const socket = tls.connect({
                host: smtp.host,
                port: smtp.port,
                servername: smtp.host,
            }, () => resolve(socket));
            socket.on("error", onError);
            return;
        }
        const socket = net.connect({
            host: smtp.host,
            port: smtp.port,
        }, () => resolve(socket));
        socket.on("error", onError);
    });
}
// Envia um comando SMTP e espera por um código de resposta específico (ex.: EHLO -> 250).
async function sendCommand(socket, command, expectedCode) {
    socket.write(`${command}\r\n`);
    await expectResponse(socket, expectedCode);
}
// Lê resposta SMTP do socket e valida se o código retornado corresponde ao esperado.
async function expectResponse(socket, expectedCode) {
    const response = await readSmtpResponse(socket);
    if (response.code !== expectedCode) {
        throw new Error(`SMTP respondeu com ${response.code} quando ${expectedCode} era esperado: ${response.message}`);
    }
}
// Lê respostas SMTP do socket até encontrar a linha final do código (ex.: "250 ...") e retorna código+mensagem.
async function readSmtpResponse(socket) {
    return await new Promise((resolve, reject) => {
        let buffer = "";
        const cleanup = () => {
            socket.off("data", onData);
            socket.off("error", onError);
            socket.off("close", onClose);
        };
        const onError = (error) => {
            cleanup();
            reject(error);
        };
        const onClose = () => {
            cleanup();
            reject(new Error("Conexao SMTP encerrada inesperadamente."));
        };
        const onData = (chunk) => {
            buffer += chunk.toString();
            const lines = buffer.split(/\r?\n/).filter(Boolean);
            if (lines.length === 0) {
                return;
            }
            const lastLine = lines[lines.length - 1];
            const match = lastLine.match(/^(\d{3})([ -])(.*)$/);
            if (!match || match[2] !== " ") {
                return;
            }
            cleanup();
            resolve({
                code: Number(match[1]),
                message: lines.join("\n"),
            });
        };
        socket.on("data", onData);
        socket.on("error", onError);
        socket.on("close", onClose);
    });
}
// Monta um e-mail RFC822 "cru" com boundary multipart (texto + HTML) a partir dos dados informados.
function buildRawEmail({ fromEmail, fromName, to, subject, text, html, }) {
    const boundary = `mescla-${Date.now()}`;
    return [
        `From: ${fromName} <${fromEmail}>`,
        `To: <${to}>`,
        `Subject: ${subject}`,
        "MIME-Version: 1.0",
        `Content-Type: multipart/alternative; boundary="${boundary}"`,
        "",
        `--${boundary}`,
        "Content-Type: text/plain; charset=UTF-8",
        "Content-Transfer-Encoding: 8bit",
        "",
        text,
        `--${boundary}`,
        "Content-Type: text/html; charset=UTF-8",
        "Content-Transfer-Encoding: 8bit",
        "",
        html,
        `--${boundary}--`,
    ].join("\r\n");
}
// Escapa conteúdo do corpo para evitar que linhas iniciadas com "." sejam interpretadas como fim do DATA no SMTP.
function escapeSmtpData(message) {
    return message
        .replace(/\r?\n/g, "\r\n")
        .replace(/^\./gm, "..");
}
