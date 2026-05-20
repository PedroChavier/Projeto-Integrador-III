import { createHash, randomInt } from "node:crypto";
import * as net from "node:net";
import * as tls from "node:tls";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

// Garante que o Firebase Admin esteja inicializado antes de usar Firestore.
// (Importação pode acontecer antes do initializeApp em index.ts.)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Referencias reutilizadas do Firestore e configuracoes padrao do fluxo MFA.
const db = admin.firestore();
const mfaCodesCollection = db.collection("mfaCodes");
const defaultMfaCodeTtlMinutes = 10;
const mfaCodeLength = 6;
const mfaMaxAttempts = 3;

// Canais suportados para entrega do codigo.
export type MfaChannel = "email" | "sms";

// Dados necessarios para persistir um codigo MFA no Firebase.
type SaveMfaCodeParams = {
  uid: string;
  email?: string;
  telefone?: string;
  canal: MfaChannel;
  codigo: string;
  expiresInMinutes?: number;
};

// Dados necessarios para verificar um codigo MFA.
type VerifyMfaCodeParams = {
  uid: string;
  codigo: string;
  canal: MfaChannel;
};

// Dados necessarios para disparo do codigo por e-mail.
type SendMfaCodeEmailParams = {
  to: string;
  codigo: string;
  expiresInMinutes?: number;
  nome?: string;
};

// Dados necessarios para disparo do codigo por SMS.
type SendMfaCodeSmsParams = {
  to: string;
  codigo: string;
  nome?: string;
  expiresInMinutes?: number;
};

// Configuracao SMTP carregada das Cloud Functions.
type SmtpConfig = {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  pass: string;
  fromEmail: string;
  fromName: string;
};

// Configuracao do provedor HTTP de SMS.
type SmsConfig = {
  endpoint: string;
  apiKey: string;
  from: string;
};

// Gera exatamente 6 digitos aleatorios para o desafio MFA.
export function gerarCodigoMfaSeisDigitos(): string {
  return Array.from(
    { length: mfaCodeLength },
    () => randomInt(0, 10).toString()
  ).join("");
}

// Salva o codigo no Firestore com hash e tempo de expiracao.
// O codigo em texto puro nao fica persistido, apenas seu hash.
export async function salvarCodigoMfaNoFirebase({
  uid,
  email,
  telefone,
  canal,
  codigo,
  expiresInMinutes = defaultMfaCodeTtlMinutes,
}: SaveMfaCodeParams): Promise<{
  uid: string;
  canal: MfaChannel;
  expiresAt: admin.firestore.Timestamp;
}> {
  // Normaliza e valida os dados recebidos antes de persistir.
  const normalizedUid = sanitizeRequiredString(uid, "UID");
  const normalizedCode = sanitizeMfaCode(codigo);
  const normalizedEmail = email ? sanitizeEmail(email) : null;
  const normalizedPhone = telefone ? sanitizePhone(telefone) : null;

  // Cada canal exige seu respectivo destino.
  if (canal === "email" && !normalizedEmail) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "E-mail obrigatorio para salvar codigo MFA por e-mail."
    );
  }

  if (canal === "sms" && !normalizedPhone) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Telefone obrigatorio para salvar codigo MFA por SMS."
    );
  }

  // Define a expiracao do desafio.
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + expiresInMinutes * 60 * 1000)
  );

  // Usa o UID como chave do documento para manter apenas o ultimo codigo ativo por usuario.
  await mfaCodesCollection.doc(normalizedUid).set(
    {
      uid: normalizedUid,
      canal,
      codeHash: hashMfaCode(normalizedUid, normalizedCode),
      email: normalizedEmail,
      telefone: normalizedPhone,
      attempts: 0,
      verifiedAt: null,
      expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return {
    uid: normalizedUid,
    canal,
    expiresAt,
  };
}

// Envia o codigo por e-mail usando as credenciais SMTP configuradas no ambiente.
export async function enviarCodigoMfaPorEmail({
  to,
  codigo,
  expiresInMinutes = defaultMfaCodeTtlMinutes,
  nome,
}: SendMfaCodeEmailParams): Promise<void> {
  // Valida entrada e carrega a configuracao de envio.
  const email = sanitizeEmail(to);
  const normalizedCode = sanitizeMfaCode(codigo);
  const smtp = getSmtpConfig();
  const socket = await connectSmtp(smtp);

  try {
    await expectResponse(socket, 220);
    await sendCommand(socket, `EHLO ${smtp.host}`, 250);
    await sendCommand(socket, `AUTH LOGIN`, 334);
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
    await sendCommand(socket, `RCPT TO:<${email}>`, 250);
    await sendCommand(socket, "DATA", 354);

    const mensagem = buildMfaMessage({
      codigo: normalizedCode,
      nome,
      expiresInMinutes,
    });

    const emailRaw = buildRawEmail({
      fromEmail: smtp.fromEmail,
      fromName: smtp.fromName,
      to: email,
      subject: "Seu codigo de autenticacao",
      text: mensagem.text,
      html: mensagem.html,
    });

    socket.write(`${escapeSmtpData(emailRaw)}\r\n.\r\n`);
    await expectResponse(socket, 250);
    await sendCommand(socket, "QUIT", 221);
  } catch (error: unknown) {
    const message =
      error instanceof Error && error.message.trim().length > 0
        ? error.message
        : "Falha ao enviar e-mail MFA via SMTP.";

    throw new functions.https.HttpsError("internal", message);
  } finally {
    socket.end();
  }
}

// Envia o codigo por SMS usando um endpoint HTTP externo configurado nas Functions.
// O formato do payload pode ser ajustado conforme o provedor adotado.
export async function enviarCodigoMfaPorSms({
  to,
  codigo,
  nome,
  expiresInMinutes = defaultMfaCodeTtlMinutes,
}: SendMfaCodeSmsParams): Promise<void> {
  // Valida telefone e codigo antes da chamada externa.
  const phone = sanitizePhone(to);
  const normalizedCode = sanitizeMfaCode(codigo);
  const sms = getSmsConfig();
  const mensagem = buildMfaSmsMessage({
    codigo: normalizedCode,
    nome,
    expiresInMinutes,
  });

  // Dispara a requisicao HTTP para o provedor de SMS.
  const response = await fetch(sms.endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${sms.apiKey}`,
    },
    body: JSON.stringify({
      from: sms.from,
      to: phone,
      message: mensagem,
    }),
  });

  // Qualquer resposta nao-2xx vira erro interno para o caller tratar.
  if (!response.ok) {
    const details = await response.text();
    throw new functions.https.HttpsError(
      "internal",
      `Falha ao enviar SMS MFA: ${details || response.statusText}`
    );
  }
}

// Gera um hash deterministico do codigo vinculado ao UID do usuario.
// Isso permite comparar depois sem salvar o codigo original em texto.
function hashMfaCode(uid: string, codigo: string): string {
  return createHash("sha256").update(`${uid}:${codigo}`).digest("hex");
}

// Garante que o codigo possua apenas digitos e exatamente 6 caracteres.
function sanitizeMfaCode(value: string): string {
  const digits = sanitizeRequiredString(value, "Codigo MFA").replace(/\D/g, "");

  if (digits.length != mfaCodeLength) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `O codigo MFA deve conter ${mfaCodeLength} digitos.`
    );
  }

  return digits;
}

// Garante que um campo obrigatorio veio como string nao vazia.
function sanitizeRequiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
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

// Normaliza e valida e-mails usados no fluxo MFA.
function sanitizeEmail(value: unknown): string {
  const email = sanitizeRequiredString(value, "E-mail").toLowerCase();
  const emailPattern: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!emailPattern.test(email)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "E-mail invalido."
    );
  }

  return email;
}

// Normaliza telefone removendo mascara e convertendo para formato internacional simples.
function sanitizePhone(value: unknown): string {
  const digits = sanitizeRequiredString(value, "Telefone").replace(/\D/g, "");

  if (digits.length < 10 || digits.length > 15) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Telefone invalido."
    );
  }

  return `+${digits}`;
}

// Carrega e valida as credenciais SMTP configuradas via functions.config().
function getSmtpConfig(): SmtpConfig {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const fromEmail = process.env.SMTP_FROM_EMAIL;

  if (!host || !user || !pass || !fromEmail) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "As credenciais SMTP nao foram configuradas (env: SMTP_HOST, SMTP_USER, SMTP_PASS, SMTP_FROM_EMAIL)."
    );
  }

  const portRaw = process.env.SMTP_PORT;
  const secureRaw = process.env.SMTP_SECURE;

  return {
    host,
    port: portRaw ? Number(portRaw) : 465,
    secure: secureRaw ? String(secureRaw) === "true" : true,
    user,
    pass,
    fromEmail,
    fromName: process.env.SMTP_FROM_NAME ?? "Mescla Invest",
  };
}

// Carrega e valida os dados do provedor de SMS configurados via env.
function getSmsConfig(): SmsConfig {
  const endpoint = process.env.SMS_ENDPOINT;
  const apiKey = process.env.SMS_API_KEY;
  const from = process.env.SMS_FROM;

  if (!endpoint || !apiKey || !from) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "As credenciais do provedor de SMS nao foram configuradas (env: SMS_ENDPOINT, SMS_API_KEY, SMS_FROM)."
    );
  }

  return {
    endpoint,
    apiKey,
    from,
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

// Monta uma versao compartilhada da mensagem MFA para e-mail.
function buildMfaMessage({
  codigo,
  nome,
  expiresInMinutes,
}: {
  codigo: string;
  nome?: string;
  expiresInMinutes: number;
}): { text: string; html: string } {
  const saudacao = nome?.trim() ? `Ola, ${nome.trim()}.` : "Ola.";

  return {
    text: [
      saudacao,
      "",
      `Seu codigo MFA e: ${codigo}`,
      `Ele expira em ${expiresInMinutes} minutos.`,
      "",
      "Se voce nao tentou entrar na conta, ignore esta mensagem.",
    ].join("\n"),
    html: [
      `<p>${saudacao}</p>`,
      `<p>Seu codigo MFA e: <strong>${codigo}</strong></p>`,
      `<p>Ele expira em ${expiresInMinutes} minutos.</p>`,
      "<p>Se voce nao tentou entrar na conta, ignore esta mensagem.</p>",
    ].join(""),
  };
}

// Monta uma versao curta da mensagem MFA para SMS.
function buildMfaSmsMessage({
  codigo,
  nome,
  expiresInMinutes,
}: {
  codigo: string;
  nome?: string;
  expiresInMinutes: number;
}): string {
  const saudacao = nome?.trim() ? `${nome.trim()}, ` : "";
  return `${saudacao}seu codigo MFA e ${codigo}. Ele expira em ${expiresInMinutes} minutos.`;
}

// Verifica o codigo MFA fornecido pelo usuario contra o armazenado no Firebase.
export async function verificarCodigoMfa({
  uid,
  codigo,
  canal,
}: VerifyMfaCodeParams): Promise<boolean> {
  // Normaliza e valida os dados recebidos.
  const normalizedUid = sanitizeRequiredString(uid, "UID");
  const normalizedCode = sanitizeMfaCode(codigo);

  // Recupera o codigo MFA armazenado para o usuario.
  const mfaSnapshot = await mfaCodesCollection.doc(normalizedUid).get();

  if (!mfaSnapshot.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Nenhum codigo MFA foi solicitado para este usuario."
    );
  }

  const mfaData = mfaSnapshot.data();
  const storedHash = mfaData?.codeHash;
  const expiresAt = mfaData?.expiresAt as admin.firestore.Timestamp | undefined;
  const attempts = mfaData?.attempts ?? 0;
  const verifiedAt = mfaData?.verifiedAt;
  const canalArmazenado = mfaData?.canal;

  // Valida se o documento possui dados necessarios.
  if (!expiresAt || typeof storedHash !== "string") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "O codigo MFA armazenado esta invalido."
    );
  }

  // Valida se o codigo ja foi utilizado.
  if (verifiedAt) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Este codigo MFA ja foi utilizado."
    );
  }

  // Valida se o codigo expirou.
  if (expiresAt.toDate().getTime() < Date.now()) {
    throw new functions.https.HttpsError(
      "deadline-exceeded",
      "O codigo MFA informado expirou. Solicite um novo envio."
    );
  }

  // Valida se o canal corresponde.
  if (canalArmazenado !== canal) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "O canal MFA fornecido nao corresponde ao codigo solicitado."
    );
  }

  // Valida se nao excedeu limite de tentativas.
  if (attempts >= mfaMaxAttempts) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Limite de tentativas excedido. Solicite um novo codigo."
    );
  }

  // Valida se o codigo fornecido corresponde ao hash armazenado.
  const providedHash = hashMfaCode(normalizedUid, normalizedCode);

  if (storedHash !== providedHash) {
    await mfaCodesCollection.doc(normalizedUid).set(
      {
        attempts: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    throw new functions.https.HttpsError(
      "permission-denied",
      "O codigo MFA informado esta incorreto."
    );
  }

  // Marca o codigo como verificado.
  await mfaCodesCollection.doc(normalizedUid).set(
    {
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return true;
}
