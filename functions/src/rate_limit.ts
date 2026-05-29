import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

/**
 * Rate limit por chave (uid ou email) numa janela deslizante simples.
 * Usa Firestore para persistir contagem por janela. Janela = bucket de N segundos.
 *
 * Uso:
 *   await enforceRateLimit({ key: uid, action: "ordersCreate", maxPerWindow: 30, windowSeconds: 60 });
 *
 * Em violacao, lanca HttpsError "resource-exhausted".
 */
export async function enforceRateLimit(params: {
  key: string;
  action: string;
  maxPerWindow: number;
  windowSeconds: number;
}): Promise<void> {
  const { key, action, maxPerWindow, windowSeconds } = params;
  if (!key) return;

  const db = admin.firestore();
  const windowStart = Math.floor(Date.now() / 1000 / windowSeconds) * windowSeconds;
  const docId = `${action}_${key}_${windowStart}`;
  const ref = db.collection("rate_limits").doc(docId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number | undefined) ?? 0;
    if (count >= maxPerWindow) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Limite de requisicoes atingido para ${action}. Tente novamente em alguns segundos.`
      );
    }
    tx.set(
      ref,
      {
        count: admin.firestore.FieldValue.increment(1),
        action,
        key,
        window_start: windowStart,
        expires_at: admin.firestore.Timestamp.fromMillis(
          (windowStart + windowSeconds * 2) * 1000
        ),
      },
      { merge: true }
    );
  });
}
