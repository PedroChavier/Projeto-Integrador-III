import { createHash, randomInt } from "node:crypto";
import * as net from "node:net";
import * as tls from "node:tls";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {
  enviarCodigoMfaPorEmail,
  enviarCodigoMfaPorSms,
  gerarCodigoMfaSeisDigitos,
  salvarCodigoMfaNoFirebase,
  verificarCodigoMfa,
  type MfaChannel,
} from "./mfa_code";
export * from "./mfa_code";
export * from "./balcao";
import { enforceRateLimit } from "./rate_limit";

// Inicializa o SDK do Firebase Admin (requisito para acesso ao Auth/Firestore).
admin.initializeApp();

const db = admin.firestore();
const usuariosCollection = db.collection("usuarios");
const passwordRecoveryCollection = db.collection("passwordRecoveryCodes");
const recoveryCodeTtlMinutes = 10;
const recoveryCodeLength = 6;
const passwordMinLength = 8;
const passwordMaxLength = 20;
const passwordPolicyMessage =
  "A senha deve ter entre 8 e 20 caracteres e incluir letra maiuscula, minuscula, numero e caractere especial.";

// Payload esperado para registrar usuário (todos os campos são recebidos como unknown e sanitizados/validados).
type RegistrarUsuarioPayload = {
  cpf?: unknown;
  fullName?: unknown;
  dataNascimento?: unknown;
  email?: unknown;
  telefone?: unknown;
  mfaHabilitado?: unknown;
  userActive?: unknown;
};

// Payload esperado para solicitar código de recuperação de senha.
type SolicitarCodigoRecuperacaoPayload = {
  email?: unknown;
};

// Payload esperado para redefinir senha usando código de recuperação.
type RedefinirSenhaPayload = {
  email?: unknown;
  code?: unknown;
  newPassword?: unknown;
};

// Payload esperado para solicitar o envio de um codigo MFA.
type SolicitarCodigoMfaPayload = {
  canal?: unknown;
};

// Payload esperado para verificar um codigo MFA.
type VerificarCodigoMfaPayload = {
  codigo?: unknown;
  canal?: unknown;
};

type CreditarSaldoPayload = {
  valor?: unknown;
};

// Função Callable: registra um usuário (valida autenticação, sanitiza payload, evita CPF duplicado e salva/merge no Firestore).
export const registrarUsuario = functions
  .region('southamerica-east1')
  .https.onCall(
  async (data: RegistrarUsuarioPayload, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }

    const payload = normalizarPayload(data, context.auth.token.email);
    const userId = context.auth.uid;

    await validarCpfDisponivel(payload.cpf, userId);

    const existingSnapshot = await usuariosCollection.doc(userId).get();
    const existingData = existingSnapshot.data() ?? {};
    const existingRole =
      typeof existingData.role === "string" && existingData.role.trim().length > 0
        ? existingData.role
        : "user";
    const existingIsAdmin =
      typeof existingData.isAdmin === "boolean" ? existingData.isAdmin : false;

    await usuariosCollection.doc(userId).set(
      {
        ...payload,
        uid: userId,
        role: existingRole,
        isAdmin: existingIsAdmin,
        createdAt:
          existingSnapshot.exists && existingData.createdAt
            ? existingData.createdAt
            : admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Garante wallet/main desde o signup. Idempotente: não sobrescreve saldo existente.
    const walletRef = usuariosCollection.doc(userId).collection("wallet").doc("main");
    const walletSnap = await walletRef.get();
    if (!walletSnap.exists) {
      await walletRef.set({
        saldo_brl: 0,
        saldo_brl_reservado: 0,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      success: true,
      uid: userId,
    };
  }
);

// Trigger Auth: ao remover usuário no Firebase Auth, tenta remover o perfil correspondente no Firestore.
export const excluirPerfilAoExcluirAuth = functions
  .region('southamerica-east1')
  .auth
  .user()
  .onDelete(async (user) => {
    await usuariosCollection.doc(user.uid).delete().catch(() => undefined);
  });

// Função Callable: solicita código de recuperação de senha, armazenando hash do código no Firestore e enviando e-mail.
export const solicitarCodigoRecuperacaoSenha = functions
  .region('southamerica-east1')
  .https.onCall(
  async (data: SolicitarCodigoRecuperacaoPayload) => {
    const email = sanitizeEmail(data.email);

    await enforceRateLimit({
      key: email,
      action: "solicitarCodigoRecuperacaoSenha",
      maxPerWindow: 5,
      windowSeconds: 600,
    });

    const response = {
      success: true,
      message:
        "Se existir uma conta com este e-mail, um codigo de recuperacao foi enviado.",
    };

    let user: admin.auth.UserRecord;

    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (isAuthUserNotFound(error)) {
        return response;
      }

      throw toHttpsError(error, "Nao foi possivel iniciar a recuperacao de senha.");
    }

    const code = generateNumericCode(recoveryCodeLength);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + recoveryCodeTtlMinutes * 60 * 1000)
    );

    await passwordRecoveryCollection.doc(buildRecoveryDocId(email)).set(
      {
        uid: user.uid,
        email,
        codeHash: hashRecoveryCode(email, code),
        attempts: 0,
        usedAt: null,
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await sendRecoveryCodeEmail({
      to: email,
      code,
      expiresInMinutes: recoveryCodeTtlMinutes,
    });

    return response;
  }
);

// Função Callable: valida código de recuperação e redefine a senha do usuário no Firebase Auth, marcando o uso do código.
export const redefinirSenhaComCodigo = functions
  .region('southamerica-east1')
  .https.onCall(
  async (data: RedefinirSenhaPayload) => {
    const email = sanitizeEmail(data.email);
    const code = sanitizeRecoveryCode(data.code);
    const newPassword = sanitizeNewPassword(data.newPassword);
    const recoveryRef = passwordRecoveryCollection.doc(buildRecoveryDocId(email));
    const recoverySnapshot = await recoveryRef.get();

    if (!recoverySnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Nenhum codigo de recuperacao foi solicitado para este e-mail."
      );
    }

    const recoveryData = recoverySnapshot.data();
    const expiresAt = recoveryData?.expiresAt as admin.firestore.Timestamp | undefined;
    const usedAt = recoveryData?.usedAt;
    const storedHash = recoveryData?.codeHash;

    if (!expiresAt || typeof storedHash !== "string") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "O codigo de recuperacao armazenado esta invalido."
      );
    }

    if (usedAt) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Este codigo ja foi utilizado."
      );
    }

    if (expiresAt.toDate().getTime() < Date.now()) {
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "O codigo informado expirou. Solicite um novo envio."
      );
    }

    if (storedHash !== hashRecoveryCode(email, code)) {
      await recoveryRef.set(
        {
          attempts: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      throw new functions.https.HttpsError(
        "permission-denied",
        "O codigo informado esta incorreto."
      );
    }

    let user: admin.auth.UserRecord;

    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      throw toHttpsError(error, "Nao foi possivel localizar a conta do usuario.");
    }

    await admin.auth().updateUser(user.uid, { password: newPassword });
    await recoveryRef.set(
      {
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      message: "Senha redefinida com sucesso.",
    };
  }
);

// Funcao Callable: gera, persiste e envia um codigo MFA para o canal escolhido pelo usuario autenticado.
export const solicitarCodigoMfa = functions
  .region('southamerica-east1')
  .https.onCall(
  async (data: SolicitarCodigoMfaPayload, context) => {
    const uid = context.auth?.uid;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }

    await enforceRateLimit({
      key: uid,
      action: "solicitarCodigoMfa",
      maxPerWindow: 5,
      windowSeconds: 600,
    });

    const canal = sanitizeMfaChannel(data.canal);
    const usuarioSnapshot = await usuariosCollection.doc(uid).get();
    const usuarioData = usuarioSnapshot.data();

    if (!usuarioSnapshot.exists || !usuarioData) {
      throw new functions.https.HttpsError(
        "not-found",
        "Perfil do usuario nao encontrado."
      );
    }

    const fullName =
      typeof usuarioData.fullName === "string" ? usuarioData.fullName.trim() : "";
    const email =
      typeof usuarioData.email === "string" ? usuarioData.email.trim() : "";
    const telefone =
      typeof usuarioData.telefone === "string" ? usuarioData.telefone.trim() : "";
    const mfaHabilitado = usuarioData.mfaHabilitado === true;

    if (!mfaHabilitado) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "A autenticacao multifator nao esta habilitada para este usuario."
      );
    }

    if (canal === "email" && !email) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "O usuario nao possui e-mail cadastrado para MFA."
      );
    }

    if (canal === "sms" && !telefone) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "O usuario nao possui telefone cadastrado para MFA."
      );
    }

    const codigo = gerarCodigoMfaSeisDigitos();

    await salvarCodigoMfaNoFirebase({
      uid,
      email,
      telefone,
      canal,
      codigo,
    });

    if (canal === "email") {
      await enviarCodigoMfaPorEmail({
        to: email,
        codigo,
        nome: fullName,
      });
    } else {
      await enviarCodigoMfaPorSms({
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
  }
);

// Funcao Callable: verifica o codigo MFA fornecido pelo usuario autenticado, validando contra o armazenado.
export const verificarCodigoMfaCallable = functions
  .region('southamerica-east1')
  .https.onCall(
  async (data: VerificarCodigoMfaPayload, context) => {
    const uid = context.auth?.uid;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }

    const codigo = sanitizeRequiredString(data.codigo, "Codigo MFA");
    const canal = sanitizeMfaChannel(data.canal);

    await verificarCodigoMfa({
      uid,
      codigo,
      canal,
    });

    return {
      success: true,
      message: "Codigo MFA verificado com sucesso.",
    };
  }
);

// Funcao Callable: credita saldo simulado com privilegios de Admin SDK para evitar bloqueios das regras do cliente.
export const creditarSaldoSimulado = functions
  .region("southamerica-east1")
  .https.onCall(async (data: CreditarSaldoPayload, context) => {
    const uid = context.auth?.uid;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }

    const valor = sanitizePositiveNumber(data.valor, "Valor");

    const VALOR_MAX_POR_DEPOSITO = 100_000;
    const VALOR_MAX_DIARIO = 500_000;

    if (valor > VALOR_MAX_POR_DEPOSITO) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Valor maximo por deposito: R$ ${VALOR_MAX_POR_DEPOSITO}.`
      );
    }

    const usuarioRef = usuariosCollection.doc(uid);
    const transacaoRef = usuarioRef.collection("transacoes").doc();
    const walletMainRef = usuarioRef.collection("wallet").doc("main");
    const todayKey = new Date().toISOString().slice(0, 10);
    const dailyLimitRef = usuarioRef.collection("deposit_limits").doc(todayKey);

    await db.runTransaction(async (tx) => {
      const limitSnap = await tx.get(dailyLimitRef);
      const totalHoje = (limitSnap.data()?.total as number | undefined) ?? 0;
      if (totalHoje + valor > VALOR_MAX_DIARIO) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          `Limite diario de R$ ${VALOR_MAX_DIARIO} excedido. Ja depositado hoje: R$ ${totalHoje}.`
        );
      }

      tx.set(
        walletMainRef,
        {
          saldo_brl: admin.firestore.FieldValue.increment(valor),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(transacaoRef, {
        tipo: "deposito",
        titulo: "Credito Simulado",
        subtitulo: formatTransactionDate(new Date()),
        valor,
        positivo: true,
        fonte: "Externo",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        dailyLimitRef,
        {
          total: admin.firestore.FieldValue.increment(valor),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return {
      success: true,
      valor,
    };
  });

// Funcao Callable: atualiza o flag mfaHabilitado no perfil do usuario.
// Cliente nao pode escrever esse campo diretamente (protegido pelas rules).
export const atualizarMfaStatus = functions
  .region("southamerica-east1")
  .https.onCall(async (data: { habilitado?: unknown }, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Usuario nao autenticado."
      );
    }
    if (typeof data.habilitado !== "boolean") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "habilitado deve ser boolean."
      );
    }

    await enforceRateLimit({
      key: uid,
      action: "atualizarMfaStatus",
      maxPerWindow: 5,
      windowSeconds: 600,
    });

    await usuariosCollection.doc(uid).set(
      {
        mfaHabilitado: data.habilitado,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { success: true, habilitado: data.habilitado };
  });

// Tipo usado para retornar itens do catálogo de startups (nomes, descrição, valores formatados etc.).
type StartupCatalogItem = {
  uid: string;
  nome: string;
  descricao: string;
  status: string;
  tokens: string;
  capital: string;
  preco: string;
};

// Normaliza a etapa/estágio (strings/nums diversos) para um conjunto reduzido de valores canônicos.
function normalizeStage(raw: unknown): string {
  if (raw === null || raw === undefined) return "nova";

  if (typeof raw === "string") {
    const normalized = raw
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, ""); // remove acentos

    if (normalized === "nova") return "nova";
    if (normalized === "emoperacao" || normalized === "em-operacao") return "emOperacao";
    if (normalized === "emexpansao" || normalized === "em-expansao") return "emExpansao";

    // fallback por substring
    if (normalized.includes("nova")) return "nova";
    if (normalized.includes("operacao")) return "emOperacao";
    if (normalized.includes("expansao")) return "emExpansao";
  }

  if (typeof raw === "number") {
    if (raw === 0) return "nova";
    if (raw === 1) return "emOperacao";
    if (raw === 2) return "emExpansao";
  }

  return "nova";
}

// Converte o estágio normalizado em um rótulo amigável para UI.
function stageLabel(raw: unknown): string {
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
function toNumber(raw: unknown): number | null {
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;

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
function formatCompactNumberBR(value: number): string {
  const abs = Math.abs(value);

  if (abs >= 1_000_000) return `${Math.round(value / 1_000_000)}M`;
  if (abs >= 1_000) return `${Math.round(value / 1_000)}k`;

  return `${Math.round(value)}`;
}

// Adiciona prefixo monetário (R$) ao número compactado.
function formatCapital(value: number): string {
  return `R$ ${formatCompactNumberBR(value)}`;
}

// Formata tokens (usando o mesmo estilo compactado), delegando para função compartilhada.
function formatTokens(value: number): string {
  // a UI hoje usa ex.: "50k"
  // se vier null/0, devolve "0"
  return absRoundToCompact(value);
}

// Formata números de forma compacta com sufixo (k/M/B), usando arredondamento.
function absRoundToCompact(value: number): string {
  const abs = Math.abs(value);

  if (abs >= 1_000_000_000) return `${Math.round(value / 1_000_000_000)}B`;
  if (abs >= 1_000_000) return `${Math.round(value / 1_000_000)}M`;
  if (abs >= 1_000) return `${Math.round(value / 1_000)}k`;

  return `${Math.round(value)}`;
}

// Formata preço em Real Brasileiro, com 2 casas e vírgula decimal (ex.: "R$ 25,00").
function formatPrecoBRL(value: number): string {
  // UI hoje usa "R$ 25,00"
  const fixed = value.toFixed(2);
  const withComma = fixed.replace(".", ",");

  return `R$ ${withComma}`;
}

// Função Callable: lista startups do Firestore e retorna itens formatados (capital/tokens/preço) para o catálogo.
export const listarStartups = functions
  .region('southamerica-east1')
  .https.onCall(
  async (_data: Record<string, unknown> | undefined, _context) => {
    // tenta múltiplos nomes de coleção (pra não quebrar se o schema estiver diferente)
    const collectionsToTry = ["startups", "Startups", "startup"];

    let snapshot: FirebaseFirestore.QuerySnapshot | null = null;

    for (const collectionName of collectionsToTry) {
      const snap = await db.collection(collectionName).get();
      if (!snap.empty) {
        snapshot = snap;
        break;
      }
    }

    const docs = snapshot?.docs ?? [];

    const startups: StartupCatalogItem[] = await Promise.all(docs.map(async (doc) => {
      const data = doc.data() as Record<string, unknown>;

      const nome = typeof data.nome === "string" ? data.nome : "";
      const descricao = typeof data.descricao === "string"
        ? data.descricao
        : typeof data.bio === "string" ? data.bio : "";

      const estagio = data.estagioDesenvolvimento ?? data.estagio ?? data.stage ?? data.status;
      const status = stageLabel(estagio);

      // Mapa embutido balcao.config/state (compat) — usado como fallback
      const balcao = (typeof data.balcao === 'object' && data.balcao !== null)
        ? data.balcao as Record<string, unknown>
        : {};
      const embCfg = (typeof balcao.config === 'object' && balcao.config !== null)
        ? balcao.config as Record<string, unknown>
        : {};
      const embSt = (typeof balcao.state === 'object' && balcao.state !== null)
        ? balcao.state as Record<string, unknown>
        : {};

      // Subcoleção balcao/config|state (canônica) — prevalece sobre o embutido/raiz
      const [cfgSnap, stSnap] = await Promise.all([
        doc.ref.collection("balcao").doc("config").get(),
        doc.ref.collection("balcao").doc("state").get(),
      ]);
      const balcaoCfg = (cfgSnap.exists ? cfgSnap.data() : embCfg) as Record<string, unknown>;
      const balcaoSt = (stSnap.exists ? stSnap.data() : embSt) as Record<string, unknown>;

      const totalTokens = toNumber(balcaoCfg.tokens_emitidos) ?? 0;
      const cptAportado = toNumber(balcaoSt.cptAportado) ?? 0;

      let preco = toNumber(balcaoSt.last_price) ?? 0;
      if (!Number.isFinite(preco) || preco <= 0) preco = toNumber(balcaoCfg.preco_emissao) ?? 0;

      return {
        uid: doc.id,
        nome,
        descricao,
        status,
        tokens: formatTokens(totalTokens),
        capital: formatCapital(cptAportado),
        preco: formatPrecoBRL(preco),
      };
    }));

    return { startups };
  }
);

// Valida se um CPF já está disponível para cadastro; se existir outro usuário com o mesmo CPF, lança erro.
async function validarCpfDisponivel(cpf: string, userId: string): Promise<void> {
  const snapshot = await usuariosCollection
    .where("cpf", "==", cpf)
    .limit(1)
    .get();

  if (!snapshot.empty && snapshot.docs[0]?.id !== userId) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Ja existe um usuario cadastrado com este CPF."
    );
  }
}

// Sanitiza e normaliza o payload de registro (CPF/telefone/e-mail/senha/data) para um objeto consistente.
function normalizarPayload(
  data: RegistrarUsuarioPayload,
  emailAutenticado?: string | null
) {
  const cpf = sanitizeDigits(data.cpf, "CPF");
  const fullName = sanitizeRequiredString(data.fullName, "Nome completo");
  const telefone = sanitizeDigits(data.telefone, "Telefone");
  const email = sanitizeEmail(data.email ?? emailAutenticado);
  const dataNascimento = sanitizeBirthDate(data.dataNascimento);
  const mfaHabilitado = Boolean(data.mfaHabilitado);
  const userActive = data.userActive === undefined ? true : Boolean(data.userActive);

  if (cpf.length !== 11) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "CPF invalido."
    );
  }

  if (telefone.length < 10 || telefone.length > 11) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Telefone invalido."
    );
  }

  if (
    typeof emailAutenticado === "string" &&
    emailAutenticado.trim().toLowerCase() !== email
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "O e-mail autenticado difere do payload enviado."
    );
  }

  return {
    cpf,
    fullName,
    dataNascimento,
    email,
    telefone,
    mfaHabilitado,
    userActive,
  };
}

// Sanitiza e valida o código de recuperação (somente dígitos, com tamanho exato).
function sanitizeRecoveryCode(value: unknown): string {
  const raw = sanitizeRequiredString(value, "Codigo");
  const digits = raw.replace(/\D/g, "");

  if (digits.length !== recoveryCodeLength) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `O codigo deve conter ${recoveryCodeLength} digitos.`
    );
  }

  return digits;
}

// Sanitiza a nova senha e valida tamanho mínimo para redefinição.
function sanitizeNewPassword(value: unknown): string {
  const password = sanitizeRequiredString(value, "Nova senha");
  validatePasswordPolicy(password);

  return password;
}

function validatePasswordPolicy(password: string): void {
  const isValidLength =
    password.length >= passwordMinLength && password.length <= passwordMaxLength;
  const hasUppercase = /[A-Z]/.test(password);
  const hasLowercase = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecialCharacter = /[^A-Za-z0-9]/.test(password);

  if (
    !isValidLength ||
    !hasUppercase ||
    !hasLowercase ||
    !hasNumber ||
    !hasSpecialCharacter
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      passwordPolicyMessage
    );
  }
}

// Garante que um campo seja string não vazia (trim), senão lança HttpsError.
function sanitizeRequiredString(value: unknown, fieldName: string): string {
  if (typeof value != "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} obrigatorio.`
    );
  }

  const normalized = value.trim();
  if (!normalized) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} obrigatorio.`
    );
  }

  return normalized;
}

// Sanitiza campos numéricos representados como texto (mantém apenas dígitos), usando sanitizeRequiredString.
function sanitizeDigits(value: unknown, fieldName: string): string {
  const raw = sanitizeRequiredString(value, fieldName);
  return raw.replace(/\D/g, "");
}

// Sanitiza e valida e-mail por regex, convertendo para lowercase.
function sanitizeEmail(value: unknown): string {
  const email = sanitizeRequiredString(value, "E-mail").toLowerCase();
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!emailPattern.test(email)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "E-mail invalido."
    );
  }

  return email;
}

// Converte string de data em Timestamp do Firestore; rejeita datas inválidas e datas no futuro.
function sanitizeBirthDate(value: unknown): admin.firestore.Timestamp {
  const raw = sanitizeRequiredString(value, "Data de nascimento");
  const parsedDate = new Date(raw);

  if (Number.isNaN(parsedDate.getTime()) || parsedDate > new Date()) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Data de nascimento invalida."
    );
  }

  return admin.firestore.Timestamp.fromDate(parsedDate);
}

// Valida o canal escolhido para envio do desafio MFA.
function sanitizeMfaChannel(value: unknown): MfaChannel {
  if (value !== "email" && value !== "sms") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Informe um canal MFA valido: email ou sms."
    );
  }

  return value;
}

function sanitizePositiveNumber(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} invalido.`
    );
  }

  return value;
}

function formatTransactionDate(data: Date): string {
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
function buildRecoveryDocId(email: string): string {
  return createHash("sha256").update(email).digest("hex");
}

// Gera hash do código de recuperação combinando e-mail e código, para comparar sem armazenar o código em claro.
function hashRecoveryCode(email: string, code: string): string {
  return createHash("sha256").update(`${email}:${code}`).digest("hex");
}

// Gera um código numérico aleatório com o comprimento especificado.
function generateNumericCode(length: number): string {
  return Array.from({ length }, () => randomInt(0, 10)).join("");
}

// Detecta especificamente o erro do Firebase Auth quando o usuário não é encontrado por e-mail.
function isAuthUserNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "auth/user-not-found"
  );
}

// Converte um erro arbitrário em HttpsError, reaproveitando HttpsError existentes e usando fallback se necessário.
function toHttpsError(error: unknown, fallbackMessage: string): functions.https.HttpsError {
  if (error instanceof functions.https.HttpsError) {
    return error;
  }

  const message =
    error instanceof Error && error.message.trim().length > 0
      ? error.message
      : fallbackMessage;

  return new functions.https.HttpsError("internal", message);
}

// Tipo de configuração SMTP usada para envio do e-mail de recuperação.
type SmtpConfig = {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  pass: string;
  fromEmail: string;
  fromName: string;
};

// Tipo de payload para montar e enviar e-mail com código.
type RecoveryEmailPayload = {
  to: string;
  code: string;
  expiresInMinutes: number;
};

// Envia o e-mail de recuperação de senha via conexão TCP/TLS, executando o fluxo SMTP manualmente.
async function sendRecoveryCodeEmail({
  to,
  code,
  expiresInMinutes,
}: RecoveryEmailPayload): Promise<void> {
  const smtp = getSmtpConfig();
  const socket = await connectSmtp(smtp);

  try {
    await expectResponse(socket, 220);
    await sendCommand(socket, `EHLO ${smtp.host}`, 250);
    await sendCommand(
      socket,
      `AUTH LOGIN`,
      334
    );
    await sendCommand(
      socket,
      Buffer.from(smtp.user, "utf8").toString("base64"),
      334
    );
    await sendCommand(
      socket,
      Buffer.from(smtp.pass, "utf8").toString("base64"),
      235
    );
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
  } finally {
    socket.end();
  }
}

// Lê configuração SMTP das Cloud Functions (configurações expostas via functions.config()).
function getSmtpConfig(): SmtpConfig {
  const smtp = (functions as unknown as { config: () => { smtp?: any } }).config().smtp;

  if (!smtp?.host || !smtp?.user || !smtp?.pass || !smtp?.from_email) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "As credenciais SMTP nao foram configuradas nas Cloud Functions."
    );
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
async function connectSmtp(smtp: SmtpConfig): Promise<tls.TLSSocket | net.Socket> {
  return await new Promise((resolve, reject) => {
    const onError = (error: Error) => reject(error);

    if (smtp.secure) {
      const socket = tls.connect(
        {
          host: smtp.host,
          port: smtp.port,
          servername: smtp.host,
        },
        () => resolve(socket)
      );

      socket.on("error", onError);
      return;
    }

    const socket = net.connect(
      {
        host: smtp.host,
        port: smtp.port,
      },
      () => resolve(socket)
    );

    socket.on("error", onError);
  });
}

// Envia um comando SMTP e espera por um código de resposta específico (ex.: EHLO -> 250).
async function sendCommand(
  socket: tls.TLSSocket | net.Socket,
  command: string,
  expectedCode: number
): Promise<void> {
  socket.write(`${command}\r\n`);
  await expectResponse(socket, expectedCode);
}

// Lê resposta SMTP do socket e valida se o código retornado corresponde ao esperado.
async function expectResponse(
  socket: tls.TLSSocket | net.Socket,
  expectedCode: number
): Promise<void> {
  const response = await readSmtpResponse(socket);

  if (response.code !== expectedCode) {
    throw new Error(
      `SMTP respondeu com ${response.code} quando ${expectedCode} era esperado: ${response.message}`
    );
  }
}

// Lê respostas SMTP do socket até encontrar a linha final do código (ex.: "250 ...") e retorna código+mensagem.
async function readSmtpResponse(
  socket: tls.TLSSocket | net.Socket
): Promise<{ code: number; message: string }> {
  return await new Promise((resolve, reject) => {
    let buffer = "";

    const cleanup = () => {
      socket.off("data", onData);
      socket.off("error", onError);
      socket.off("close", onClose);
    };

    const onError = (error: Error) => {
      cleanup();
      reject(error);
    };

    const onClose = () => {
      cleanup();
      reject(new Error("Conexao SMTP encerrada inesperadamente."));
    };

    const onData = (chunk: Buffer | string) => {
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
function buildRawEmail({
  fromEmail,
  fromName,
  to,
  subject,
  text,
  html,
}: {
  fromEmail: string;
  fromName: string;
  to: string;
  subject: string;
  text: string;
  html: string;
}): string {
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
function escapeSmtpData(message: string): string {
  return message
    .replace(/\r?\n/g, "\r\n")
    .replace(/^\./gm, "..");
}
