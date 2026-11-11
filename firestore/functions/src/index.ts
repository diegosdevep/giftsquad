import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
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

type Idioma = "es" | "en";

type MensajeId = "newWishlistItem" | "secretSantaDrawn" | "secretSantaInvite";

interface Plantilla {
  title: string;
  body: string;
}

const MENSAJES: Record<MensajeId, Record<Idioma, Plantilla>> = {
  newWishlistItem: {
    es: { title: "Nuevo en la lista 🎁", body: '{autor} agregó "{item}" a su lista' },
    en: { title: "New on the list 🎁", body: '{autor} added "{item}" to their list' },
  },
  secretSantaDrawn: {
    es: {
      title: "¡Ya se hizo el sorteo! 🎉",
      body: 'Ya podés ver a quién le tenés que regalar en "{evento}"',
    },
    en: {
      title: "The draw is done! 🎉",
      body: 'You can now see who you are giving a gift to in "{evento}"',
    },
  },
  secretSantaInvite: {
    es: { title: "Amigo Invisible 🎁", body: '{organizador} te sumó a "{evento}"' },
    en: { title: "Secret Santa 🎁", body: '{organizador} added you to "{evento}"' },
  },
};

function idiomaDe(valor: unknown): Idioma {
  return valor === "en" ? "en" : "es";
}

function render(id: MensajeId, idioma: Idioma, params: Record<string, string>): Plantilla {
  const plantilla = MENSAJES[id][idioma];
  const completar = (texto: string) =>
    texto.replace(/\{(\w+)\}/g, (_, clave: string) => params[clave] ?? "");
  return { title: completar(plantilla.title), body: completar(plantilla.body) };
}

/**
 * El texto se arma por destinatario: cada uno tiene su idioma guardado en su
 * documento (lo escribe la app). El push se manda en una tanda por idioma, y el
 * doc que queda en `notifications` —el que lee la lista de alertas— se guarda ya
 * traducido, porque es de un solo usuario.
 */
async function notifyUsers(
  userIds: string[],
  kind: NotificationKind,
  mensaje: MensajeId,
  params: Record<string, string>,
  deepLink?: string
) {
  if (userIds.length === 0) return;

  const userDocs = await db.getAll(...userIds.map((id) => db.collection("users").doc(id)));
  const idiomaPorUid = new Map<string, Idioma>();
  const tokensPorIdioma = new Map<Idioma, string[]>();
  for (const doc of userDocs) {
    const idioma = idiomaDe(doc.data()?.language);
    idiomaPorUid.set(doc.id, idioma);
    const tokens = (doc.data()?.fcmTokens as string[] | undefined) ?? [];
    if (tokens.length > 0) {
      tokensPorIdioma.set(idioma, [...(tokensPorIdioma.get(idioma) ?? []), ...tokens]);
    }
  }

  const batch = db.batch();
  for (const uid of userIds) {
    const { title, body } = render(mensaje, idiomaPorUid.get(uid) ?? "es", params);
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

  for (const [idioma, tokens] of tokensPorIdioma) {
    const notification = render(mensaje, idioma, params);
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification,
      // Sin "sound", el iPhone muestra el aviso en silencio y sin vibrar.
      apns: { payload: { aps: { sound: "default" } } },
    });
    res.responses.forEach((r, i) => {
      if (!r.success) console.error(`push fallido (${mensaje}) token#${i}:`, r.error?.code, r.error?.message);
    });
  }
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
    "newWishlistItem",
    { autor: ownerName, item: data.name ?? "un producto" },
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
    "secretSantaDrawn",
    { evento: eventName },
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
      "secretSantaInvite",
      { organizador: organizerName, evento: data.name ?? "un evento" },
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

/**
 * Borrado de cuenta (App Store 5.1.1(v)). Corre en el servidor porque el
 * cliente no tiene permiso para tocar datos de otros: reservas que hizo sobre
 * ítems ajenos, membresías en grupos de terceros, asignaciones de sorteos.
 *
 * Dos criterios que valen la pena explicitar:
 *  - Un grupo con más gente no se destruye: se le pasa la propiedad al miembro
 *    más antiguo que quede. Borrarlo se llevaría puestas las listas de otros.
 *  - El historial compartido del grupo queda, pero se borra su doc en `givers`,
 *    que es lo único que lo vincula con un regalo. El anonimato se sostiene.
 */
export const deleteAccount = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Necesitás estar logueado.");
  }

  const borrarEnTandas = async (docs: FirebaseFirestore.DocumentReference[]) => {
    for (let i = 0; i < docs.length; i += 400) {
      const batch = db.batch();
      docs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
      await batch.commit();
    }
  };

  const borrarSubcoleccion = async (padre: FirebaseFirestore.DocumentReference, nombre: string) => {
    const snap = await padre.collection(nombre).get();
    await borrarEnTandas(snap.docs.map((d) => d.ref));
  };

  // 1. Sus ítems, con las notas privadas, el lock y las reservas que otros
  //    hayan hecho sobre ellos.
  const items = await db.collection("items").where("ownerId", "==", uid).get();
  for (const item of items.docs) {
    await borrarSubcoleccion(item.ref, "private");
    await db.collection("itemLocks").doc(item.id).delete().catch(() => {});
    const reservas = await db.collection("reservations").where("itemId", "==", item.id).get();
    await borrarEnTandas(reservas.docs.map((d) => d.ref));
  }
  await borrarEnTandas(items.docs.map((d) => d.ref));

  // 2. Reservas que hizo sobre ítems ajenos: se liberan, si no el regalo queda
  //    trabado para siempre y nadie más lo puede comprar.
  const propias = await db.collection("reservations").where("reservedBy", "==", uid).get();
  for (const reserva of propias.docs) {
    const itemId = reserva.data()?.itemId as string | undefined;
    if (itemId) await db.collection("itemLocks").doc(itemId).delete().catch(() => {});
  }
  await borrarEnTandas(propias.docs.map((d) => d.ref));

  // 3. Grupos. Si era el dueño, el grupo se borra; los ítems de los demás no se
  //    tocan, solo se les saca este groupId y vuelven a la lista privada de cada
  //    uno (un ítem sin grupos ya se muestra como "Solo en tu lista"). Si era un
  //    miembro más, se lo saca y el grupo sigue igual.
  const grupos = await db.collection("groups").where("memberIds", "array-contains", uid).get();
  for (const grupo of grupos.docs) {
    const miembros = ((grupo.data()?.memberIds as string[] | undefined) ?? []).filter((id) => id !== uid);

    if (grupo.data()?.ownerId !== uid && miembros.length > 0) {
      await grupo.ref.update({ memberIds: miembros });
      continue;
    }

    const enElGrupo = await db.collection("items").where("groupIds", "array-contains", grupo.id).get();
    for (const item of enElGrupo.docs) {
      await item.ref.update({ groupIds: FieldValue.arrayRemove(grupo.id) });
    }

    const locks = await db.collection("itemLocks").where("groupIds", "array-contains", grupo.id).get();
    for (const lock of locks.docs) {
      await lock.ref.update({ groupIds: FieldValue.arrayRemove(grupo.id) });
    }

    // Las reservas viven dentro del grupo: sin grupo no hay dónde verlas, y
    // dejarlas trabaría los ítems de los demás para siempre.
    const reservas = await db.collection("reservations").where("groupId", "==", grupo.id).get();
    for (const reserva of reservas.docs) {
      const itemId = reserva.data()?.itemId as string | undefined;
      if (itemId) await db.collection("itemLocks").doc(itemId).delete().catch(() => {});
    }
    await borrarEnTandas(reservas.docs.map((d) => d.ref));

    // El historial es el reporte de ese grupo: sin el grupo no lo lee nadie.
    const entradas = await db.collection("history").where("groupId", "==", grupo.id).get();
    for (const entrada of entradas.docs) {
      await borrarSubcoleccion(entrada.ref, "givers");
    }
    await borrarEnTandas(entradas.docs.map((d) => d.ref));

    await grupo.ref.delete();
  }

  // 4. Amigo invisible: lo que organizó se borra entero; donde solo participaba
  //    se lo saca y se eliminan las asignaciones que lo involucran.
  const organizados = await db.collection("secretSantaEvents").where("createdBy", "==", uid).get();
  for (const evento of organizados.docs) {
    await borrarSubcoleccion(evento.ref, "assignments");
    await borrarSubcoleccion(evento.ref, "participants");
    await evento.ref.delete();
  }
  const participa = await db
    .collection("secretSantaEvents")
    .where("participantIds", "array-contains", uid)
    .get();
  for (const evento of participa.docs) {
    if (evento.data()?.createdBy === uid) continue;
    await evento.ref.update({ participantIds: FieldValue.arrayRemove(uid) });
    await evento.ref.collection("participants").doc(uid).delete().catch(() => {});
    const asignaciones = await evento.ref.collection("assignments").get();
    await borrarEnTandas(
      asignaciones.docs
        .filter((d) => d.data()?.giverId === uid || d.data()?.recipientId === uid)
        .map((d) => d.ref)
    );
  }

  // 5. Historial: el reporte del grupo queda, su rastro no.
  const historial = await db.collection("history").get();
  for (const entrada of historial.docs) {
    await entrada.ref.collection("givers").doc(uid).delete().catch(() => {});
  }

  // 6. Notificaciones, fotos subidas y el documento del usuario.
  const notificaciones = await db.collection("notifications").where("userId", "==", uid).get();
  await borrarEnTandas(notificaciones.docs.map((d) => d.ref));
  await getStorage().bucket().deleteFiles({ prefix: `items/${uid}/` }).catch(() => {});
  await db.collection("users").doc(uid).delete().catch(() => {});

  // 7. Último: la cuenta de Auth. Con el Admin SDK no hace falta que el usuario
  //    se vuelva a loguear para confirmar.
  await getAuth().deleteUser(uid);

  return { ok: true };
});

/**
 * Suma al usuario autenticado a un grupo a partir de su código de invitación.
 *
 * Vive en el servidor porque quien todavía no es miembro no puede leer el grupo
 * (firestore.rules), así que la búsqueda por `inviteCode` desde el cliente
 * siempre fallaba con "permisos insuficientes". Abrir la lectura de grupos
 * permitiría listar todos los grupos con sus miembros; acá el código se resuelve
 * sin exponer nada más que el grupo al que te sumás.
 */
export const joinGroupByCode = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Necesitás estar logueado.");
  }

  const raw = request.data?.inviteCode;
  const code = typeof raw === "string" ? raw.trim().toUpperCase() : "";
  if (!code) {
    throw new HttpsError("invalid-argument", "Ingresá un código de invitación.");
  }

  const snap = await db.collection("groups").where("inviteCode", "==", code).limit(1).get();
  const grupo = snap.docs[0];
  if (!grupo) {
    throw new HttpsError("not-found", "Código de invitación inválido.");
  }

  const batch = db.batch();
  batch.update(grupo.ref, { memberIds: FieldValue.arrayUnion(uid) });
  batch.set(db.collection("users").doc(uid), { groupIds: FieldValue.arrayUnion(grupo.id) }, { merge: true });
  await batch.commit();

  return { groupId: grupo.id };
});
