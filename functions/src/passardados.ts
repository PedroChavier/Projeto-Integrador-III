import * as fs from "node:fs";
import * as path from "node:path";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

type StartupJsonItem = {
  nome: string;
  setor: string;
  status: string;
  ativo: boolean;
  bio: string;
  tokens_emitidos: number;
  preco_token: number;
  nmr_investidores: number;
};

export const popularStartupsFirestore = functions.https.onRequest(
  async (req, res) => {
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
      const startupsExistentes = new Map<string, FirebaseFirestore.DocumentReference>();
      const batch = db.batch();

      for (const doc of startupsSnapshot.docs) {
        const nome = doc.get("nome");
        if (typeof nome === "string" && nome.trim().length > 0) {
          startupsExistentes.set(normalizarNome(nome), doc.ref);
        }
      }

      for (const startup of startups) {
        const startupKey = normalizarNome(startup.nome);
        const docRef =
          startupsExistentes.get(startupKey) ??
          startupsRef.doc();
        const capitalAportado = startup.tokens_emitidos * startup.preco_token;
        const isNovoDocumento = !startupsExistentes.has(startupKey);
        const payload: Record<string, unknown> = {
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

        batch.set(
          docRef,
          payload,
          { merge: true }
        );
      }

      await batch.commit();

      res.status(200).json({
        success: true,
        message: "Startups importadas com sucesso.",
        totalImportadas: startups.length,
        collection: "startups",
      });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Falha ao importar startups.";

      res.status(500).json({
        success: false,
        message,
      });
    }
  }
);

function carregarStartupsJson(): StartupJsonItem[] {
  const filePath = path.resolve(__dirname, "..", "src", "Startups.json");
  const raw = fs.readFileSync(filePath, "utf8");
  const parsed = JSON.parse(raw) as unknown;

  if (!Array.isArray(parsed)) {
    throw new Error("O arquivo Startups.json nao contem uma lista valida.");
  }

  return parsed.map(validarStartupJson);
}

function validarStartupJson(item: unknown): StartupJsonItem {
  if (!item || typeof item !== "object") {
    throw new Error("Foi encontrado um registro invalido no Startups.json.");
  }

  const startup = item as Record<string, unknown>;

  return {
    nome: lerStringObrigatoria(startup.nome, "nome"),
    setor: lerStringObrigatoria(startup.setor, "setor"),
    status: lerStringObrigatoria(startup.status, "status"),
    ativo: lerBoolean(startup.ativo, "ativo"),
    bio: lerStringObrigatoria(startup.bio, "bio"),
    tokens_emitidos: lerNumero(startup.tokens_emitidos, "tokens_emitidos"),
    preco_token: lerNumero(startup.preco_token, "preco_token"),
    nmr_investidores: lerNumeroInteiro(
      startup.nmr_investidores,
      "nmr_investidores"
    ),
  };
}

function lerStringObrigatoria(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
  }

  return value;
}

function lerBoolean(value: unknown, fieldName: string): boolean {
  if (typeof value !== "boolean") {
    throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
  }

  return value;
}

function lerNumero(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
  }

  return value;
}

function lerNumeroInteiro(value: unknown, fieldName: string): number {
  const numero = lerNumero(value, fieldName);

  if (!Number.isInteger(numero)) {
    throw new Error(`Campo invalido em Startups.json: ${fieldName}.`);
  }

  return numero;
}

function normalizarEstagio(status: string): string {
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

function normalizarNome(nome: string): string {
  return nome
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}
