import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";

initializeApp();
const db = getFirestore();

setGlobalOptions({ region: "southamerica-east1" });

async function lockItem(itemId: string, itemOwnerId: string) {
  const itemDoc = await db.collection("items").doc(itemId).get();
  if (!itemDoc.exists) return;
  const groupIds = (itemDoc.data()?.groupIds as string[] | undefined) ?? [];
  await db.collection("itemLocks").doc(itemId).set({
    itemId,
    itemOwnerId,
    groupIds,
    kind: "reservation",
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function unlockItem(itemId: string) {
  await db.collection("itemLocks").doc(itemId).delete();
}

type NotificationKind =
  | "newWishlistItem"
  | "upcomingEvent"
  | "secretSantaDrawn"
  | "reservationFreed"
  | "generic";

async function notifyUsers(
  userIds: string[],
  kind: NotificationKind,
  title: string,
  body: string,
  deepLink?: string
) {
  if (userIds.length === 0) return;

  const batch = db.batch();
  for (const uid of userIds) {
    const ref = db.collection("notifications").doc();
    batch.set(ref, {
      userId: uid,
      kind,
      title,
      body,
      deepLink: deepLink ?? null,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  const userDocs = await db.getAll(...userIds.map((id) => db.collection("users").doc(id)));
  const tokens = userDocs.flatMap((doc) => (doc.data()?.fcmTokens as string[] | undefined) ?? []);
  if (tokens.length === 0) return;
  await getMessaging().sendEachForMulticast({ tokens, notification: { title, body } });
}

export const onItemCreatedNotifyGroup = onDocumentCreated("items/{itemId}", async (event) => {
  const itemId = event.params.itemId;
  const data = event.data?.data() as
    | { name?: string; ownerId?: string; groupIds?: string[] }
    | undefined;
  if (!data?.ownerId || !data.groupIds || data.groupIds.length === 0) return;

  const groupDocs = await db.getAll(...data.groupIds.map((id) => db.collection("groups").doc(id)));
  const memberIds = new Set<string>();
  for (const doc of groupDocs) {
    ((doc.data()?.memberIds as string[] | undefined) ?? []).forEach((id) => memberIds.add(id));
  }
  memberIds.delete(data.ownerId);
  if (memberIds.size === 0) return;

  const ownerDoc = await db.collection("users").doc(data.ownerId).get();
  const ownerName = (ownerDoc.data()?.displayName as string | undefined) ?? "Alguien";

  await notifyUsers(
    Array.from(memberIds),
    "newWishlistItem",
    "Nuevo en la lista 🎁",
    `${ownerName} agregó "${data.name ?? "un producto"}" a su lista`,
    `item:${itemId}`
  );
});

export const onReservationCreated = onDocumentCreated("reservations/{resId}", async (event) => {
  const data = event.data?.data() as { itemId?: string; itemOwnerId?: string } | undefined;
  if (!data?.itemId || !data.itemOwnerId) return;
  await lockItem(data.itemId, data.itemOwnerId);
});

export const onReservationReleased = onDocumentUpdated("reservations/{resId}", async (event) => {
  const before = event.data?.before.data() as { status?: string } | undefined;
  const after = event.data?.after.data() as { status?: string; itemId?: string } | undefined;
  if (!after?.itemId || before?.status === after.status || after.status !== "released") return;
  await unlockItem(after.itemId);
});

export const onReservationPurchased = onDocumentUpdated("reservations/{resId}", async (event) => {
  const before = event.data?.before.data() as { status?: string } | undefined;
  const after = event.data?.after.data() as
    | {
        status?: string;
        itemId?: string;
        itemOwnerId?: string;
        groupId?: string;
        reservedBy?: string;
      }
    | undefined;
  if (!after?.itemId || before?.status === after.status || after.status !== "purchased") return;

  const itemDoc = await db.collection("items").doc(after.itemId).get();
  const itemData = itemDoc.data() as { name?: string; price?: number; currency?: string } | undefined;

  // ANONIMATO: quién aportó vive en una subcolección legible solo por ese uid
  // (ver firestore.rules) — el doc padre es el reporte compartido del grupo y
  // nunca lleva la identidad de los givers.
  const historyRef = db.collection("history").doc();
  const batch = db.batch();
  batch.set(historyRef, {
    groupId: after.groupId ?? null,
    itemId: after.itemId,
    itemName: itemData?.name ?? "un regalo",
    recipientId: after.itemOwnerId ?? null,
    amount: itemData?.price ?? null,
    currency: itemData?.currency ?? "ARS",
    occasion: null,
    deliveredAt: FieldValue.serverTimestamp(),
    isRevealed: false,
  });
  if (after.reservedBy) {
    batch.set(historyRef.collection("givers").doc(after.reservedBy), {
      giverId: after.reservedBy,
    });
  }
  await batch.commit();

  await db.collection("itemLocks").doc(after.itemId).update({ kind: "purchased" }).catch(() => {
  });
});

interface ExclusionRule {
  fromUserId: string;
  toUserId: string;
}

export const drawSecretSanta = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Necesitás estar logueado.");
  }
  const eventId = request.data?.eventId as string | undefined;
  if (!eventId) {
    throw new HttpsError("invalid-argument", "Falta eventId.");
  }

  const eventRef = db.collection("secretSantaEvents").doc(eventId);
  const eventDoc = await eventRef.get();
  if (!eventDoc.exists) {
    throw new HttpsError("not-found", "El evento no existe.");
  }
  const eventData = eventDoc.data() as {
    createdBy?: string;
    status?: string;
    participantIds?: string[];
    exclusions?: ExclusionRule[];
  };

  if (eventData.createdBy !== uid) {
    throw new HttpsError("permission-denied", "Solo quien organizó el evento puede ejecutar el sorteo.");
  }
  if (eventData.status !== "draft") {
    throw new HttpsError("failed-precondition", "Este evento ya fue sorteado.");
  }

  const participantIds = eventData.participantIds ?? [];
  if (participantIds.length < 3) {
    throw new HttpsError("failed-precondition", "Hacen falta al menos 3 participantes para sortear.");
  }

  const forbidden = new Set((eventData.exclusions ?? []).map((e) => `${e.fromUserId}->${e.toUserId}`));

  const assignment = findDerangement(participantIds, forbidden);
  if (!assignment) {
    throw new HttpsError(
      "failed-precondition",
      "No se pudo armar un sorteo válido con esas exclusiones — probá sacar alguna."
    );
  }

  const batch = db.batch();
  for (const [giverId, recipientId] of assignment.entries()) {
    batch.set(eventRef.collection("assignments").doc(giverId), { giverId, recipientId });
  }
  batch.update(eventRef, { status: "drawn", drawnAt: FieldValue.serverTimestamp() });
  await batch.commit();

  const eventName = (eventDoc.data()?.name as string | undefined) ?? "tu Amigo Invisible";
  await notifyUsers(
    participantIds,
    "secretSantaDrawn",
    "¡Ya se hizo el sorteo! 🎉",
    `Ya podés ver a quién le tenés que regalar en "${eventName}"`,
    `secretSanta:${eventId}`
  );

  return { ok: true };
});

export const onSecretSantaEventCreated = onDocumentCreated(
  "secretSantaEvents/{eventId}",
  async (event) => {
    const eventId = event.params.eventId;
    const data = event.data?.data() as
      | { name?: string; createdBy?: string; participantIds?: string[] }
      | undefined;
    if (!data?.participantIds || !data.createdBy) return;

    const recipientIds = data.participantIds.filter((id) => id !== data.createdBy);
    if (recipientIds.length === 0) return;

    const organizerDoc = await db.collection("users").doc(data.createdBy).get();
    const organizerName = (organizerDoc.data()?.displayName as string | undefined) ?? "Alguien";

    await notifyUsers(
      recipientIds,
      "generic",
      "Amigo Invisible 🎁",
      `${organizerName} te sumó a "${data.name ?? "un evento"}"`,
      `secretSanta:${eventId}`
    );
  }
);

export const onSecretSantaEventDeleted = onDocumentDeleted(
  "secretSantaEvents/{eventId}",
  async (event) => {
    const eventId = event.params.eventId;
    for (const sub of ["assignments", "participants"]) {
      const snap = await db.collection("secretSantaEvents").doc(eventId).collection(sub).get();
      if (snap.empty) continue;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }
);

function findDerangement(
  participantIds: string[],
  forbidden: Set<string>,
  maxAttempts = 500
): Map<string, string> | null {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const recipients = shuffle([...participantIds]);
    let valid = true;
    for (let i = 0; i < participantIds.length; i++) {
      const giver = participantIds[i];
      const recipient = recipients[i];
      if (giver === recipient || forbidden.has(`${giver}->${recipient}`)) {
        valid = false;
        break;
      }
    }
    if (valid) {
      const map = new Map<string, string>();
      participantIds.forEach((giver, i) => map.set(giver, recipients[i]));
      return map;
    }
  }
  return null;
}

function shuffle<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
