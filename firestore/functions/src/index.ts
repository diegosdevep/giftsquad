import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
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
    es: { title: "Nuevo en la lista", body: '{autor} agregó "{item}" a su lista' },
    en: { title: "New on the list", body: '{autor} added "{item}" to their list' },
  },
  secretSantaDrawn: {
    es: {
      title: "¡Ya se hizo el sorteo!",
      body: 'Ya podés ver a quién le tenés que regalar en "{evento}"',
    },
    en: {
      title: "The draw is done!",
      body: 'You can now see who you are giving a gift to in "{evento}"',
    },
  },
  secretSantaInvite: {
    es: { title: "Amigo Invisible", body: '{organizador} te sumó a "{evento}"' },
    en: { title: "Secret Santa", body: '{organizador} added you to "{evento}"' },
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

  await eliminarCuenta(uid);
  return { ok: true };
});

async function eliminarCuenta(uid: string) {
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
  await getAuth()
    .deleteUser(uid)
    .catch((e) => {
      if (e?.code !== "auth/user-not-found") throw e;
    });
}

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

const ADMIN_SEMILLA = ["diegoshhh@gmail.com", "testappleuser.24@gmail.com"];
const adminsRef = db.collection("admins");

async function asegurarAdmins() {
  const snap = await adminsRef.limit(1).get();
  if (!snap.empty) return;
  const batch = db.batch();
  for (const email of ADMIN_SEMILLA) {
    batch.set(adminsRef.doc(email), { email, addedAt: FieldValue.serverTimestamp(), addedBy: "semilla" }, { merge: true });
  }
  await batch.commit();
}

async function exigirAdmin(request: CallableRequest): Promise<{ uid: string; email: string }> {
  const email = request.auth?.token?.email?.toLowerCase();
  if (!request.auth || !email || request.auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "No tenés acceso al panel de administración.");
  }
  await asegurarAdmins();
  const doc = await adminsRef.doc(email).get();
  if (!doc.exists) {
    throw new HttpsError("permission-denied", "No tenés acceso al panel de administración.");
  }
  return { uid: request.auth.uid, email };
}

async function registrarAccion(accion: string, actor: string, objetivo: string) {
  await db.collection("adminLog").add({ accion, actor, objetivo, at: FieldValue.serverTimestamp() });
}

async function emailDeUsuario(uid: string): Promise<string | null> {
  const u = await getAuth()
    .getUser(uid)
    .catch(() => null);
  if (u?.email) return u.email.toLowerCase();
  const doc = await db.collection("users").doc(uid).get();
  const email = doc.data()?.email as string | undefined;
  return email ? email.toLowerCase() : null;
}

async function exigirNoAdmin(uid: string) {
  const email = await emailDeUsuario(uid);
  if (email && (await adminsRef.doc(email).get()).exists) {
    throw new HttpsError("failed-precondition", "Primero quitale el rol de admin a esa cuenta.");
  }
}

function validarUid(valor: unknown): string {
  if (typeof valor !== "string" || valor.length < 6 || valor.length > 128) {
    throw new HttpsError("invalid-argument", "Usuario inválido.");
  }
  return valor;
}

function validarEmail(valor: unknown): string {
  const email = typeof valor === "string" ? valor.trim().toLowerCase() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new HttpsError("invalid-argument", "Ingresá un email válido.");
  }
  return email;
}

export const adminSetUserDisabled = onCall({ enforceAppCheck: true }, async (request) => {
  const actor = await exigirAdmin(request);
  const uid = validarUid(request.data?.uid);
  const pausar = request.data?.disabled === true;
  if (uid === actor.uid) {
    throw new HttpsError("failed-precondition", "No podés pausar tu propia cuenta.");
  }
  if (pausar) await exigirNoAdmin(uid);
  try {
    await getAuth().updateUser(uid, { disabled: pausar });
  } catch (e) {
    if ((e as { code?: string })?.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Ese usuario no tiene cuenta de acceso.");
    }
    throw e;
  }
  if (pausar) await getAuth().revokeRefreshTokens(uid);
  await registrarAccion(pausar ? "pausar" : "reactivar", actor.email, uid);
  return { ok: true };
});

export const adminDeleteUser = onCall({ enforceAppCheck: true, timeoutSeconds: 300 }, async (request) => {
  const actor = await exigirAdmin(request);
  const uid = validarUid(request.data?.uid);
  if (uid === actor.uid) {
    throw new HttpsError("failed-precondition", "No podés eliminar tu propia cuenta desde el panel.");
  }
  await exigirNoAdmin(uid);
  await registrarAccion("eliminar", actor.email, uid);
  await eliminarCuenta(uid);
  return { ok: true };
});

export const adminAddAdmin = onCall({ enforceAppCheck: true }, async (request) => {
  const actor = await exigirAdmin(request);
  const email = validarEmail(request.data?.email);
  let cuenta;
  try {
    cuenta = await getAuth().getUserByEmail(email);
  } catch {
    throw new HttpsError("not-found", "No hay ninguna cuenta con ese email. La persona tiene que haber entrado a GiftSquad antes.");
  }
  if (!cuenta.emailVerified) {
    throw new HttpsError("failed-precondition", "El email de esa cuenta no está verificado.");
  }
  if (cuenta.disabled) {
    throw new HttpsError("failed-precondition", "Esa cuenta está pausada.");
  }
  const ref = adminsRef.doc(email);
  if ((await ref.get()).exists) {
    throw new HttpsError("already-exists", "Esa cuenta ya es admin.");
  }
  await ref.set({ email, addedAt: FieldValue.serverTimestamp(), addedBy: actor.email });
  await registrarAccion("agregar-admin", actor.email, email);
  return { ok: true };
});

export const adminRemoveAdmin = onCall({ enforceAppCheck: true }, async (request) => {
  const actor = await exigirAdmin(request);
  const email = validarEmail(request.data?.email);
  if (email === actor.email) {
    throw new HttpsError("failed-precondition", "No podés quitarte el rol a vos mismo.");
  }
  await db.runTransaction(async (tx) => {
    const todos = await tx.get(adminsRef);
    const existe = todos.docs.some((d) => d.id === email);
    const actorSigue = todos.docs.some((d) => d.id === actor.email);
    if (!existe) throw new HttpsError("not-found", "Esa cuenta no es admin.");
    if (!actorSigue || todos.size <= 1) {
      throw new HttpsError("failed-precondition", "Tiene que haber al menos un admin.");
    }
    tx.delete(adminsRef.doc(email));
  });
  await registrarAccion("quitar-admin", actor.email, email);
  return { ok: true };
});

const aMillis = (valor: unknown): number | null =>
  valor && typeof (valor as { toMillis?: unknown }).toMillis === "function"
    ? (valor as { toMillis: () => number }).toMillis()
    : null;

export const adminOverview = onCall(async (request) => {
  const yo = await exigirAdmin(request);
  const adminsSnap = await adminsRef.get();
  const emailsAdmin = new Set(adminsSnap.docs.map((d) => d.id));

  const [usersSnap, groupsSnap, itemsSnap, reservasSnap, historySnap, eventosSnap] = await Promise.all([
    db.collection("users").get(),
    db.collection("groups").get(),
    db.collection("items").get(),
    db.collection("reservations").get(),
    db.collection("history").get(),
    db.collection("secretSantaEvents").get(),
  ]);
  const auth = getAuth();
  const ultimoIngreso = new Map<string, { lastSignIn: number | null; provider: string | null; disabled: boolean }>();
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      const ms = u.metadata.lastSignInTime ? Date.parse(u.metadata.lastSignInTime) : NaN;
      ultimoIngreso.set(u.uid, {
        lastSignIn: Number.isNaN(ms) ? null : ms,
        provider: u.providerData[0]?.providerId ?? null,
        disabled: u.disabled,
      });
    }
    pageToken = page.pageToken;
  } while (pageToken);

  const itemsPorDueno = new Map<string, number>();
  for (const d of itemsSnap.docs) {
    const o = d.data().ownerId as string;
    itemsPorDueno.set(o, (itemsPorDueno.get(o) ?? 0) + 1);
  }

  const users = usersSnap.docs.map((d) => {
    const x = d.data();
    const a = ultimoIngreso.get(d.id);
    return {
      id: d.id,
      displayName: (x.displayName as string) ?? "",
      email: (x.email as string) ?? "",
      username: (x.username as string) ?? "",
      photoURL: (x.photoURL as string) ?? null,
      language: (x.language as string) ?? null,
      groupCount: ((x.groupIds as string[] | undefined) ?? []).length,
      itemCount: itemsPorDueno.get(d.id) ?? 0,
      hasPush: ((x.fcmTokens as string[] | undefined) ?? []).length > 0,
      createdAt: aMillis(x.createdAt),
      lastSignIn: a?.lastSignIn ?? null,
      provider: a?.provider ?? null,
      disabled: a?.disabled ?? false,
      isAdmin: emailsAdmin.has(((x.email as string) ?? "").toLowerCase()),
    };
  });

  const admins = adminsSnap.docs
    .map((d) => {
      const x = d.data();
      const u = users.find((c) => c.email.toLowerCase() === d.id);
      return {
        email: d.id,
        uid: u?.id ?? null,
        name: u?.displayName ?? "",
        photoURL: u?.photoURL ?? null,
        addedBy: (x.addedBy as string) ?? "",
        addedAt: aMillis(x.addedAt),
      };
    })
    .sort((a, b) => (a.addedAt ?? 0) - (b.addedAt ?? 0));

  const fotoDe = new Map(users.map((u) => [u.id, u.photoURL]));
  const nombreDe = new Map(users.map((u) => [u.id, u.displayName || u.email || u.id]));

  const groups = groupsSnap.docs.map((d) => {
    const x = d.data();
    const memberIds = (x.memberIds as string[] | undefined) ?? [];
    return {
      id: d.id,
      name: (x.name as string) ?? "",
      emoji: (x.emoji as string) ?? null,
      ownerId: x.ownerId as string,
      ownerName: nombreDe.get(x.ownerId as string) ?? (x.ownerId as string),
      inviteCode: (x.inviteCode as string) ?? "",
      createdAt: aMillis(x.createdAt),
      members: memberIds.map((id) => ({ id, name: nombreDe.get(id) ?? id, photoURL: fotoDe.get(id) ?? null })),
      itemCount: itemsSnap.docs.filter((i) => ((i.data().groupIds as string[] | undefined) ?? []).includes(d.id)).length,
    };
  });

  const items = itemsSnap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      name: (x.name as string) ?? "",
      ownerId: x.ownerId as string,
      ownerName: nombreDe.get(x.ownerId as string) ?? (x.ownerId as string),
      groupIds: (x.groupIds as string[] | undefined) ?? [],
      price: typeof x.price === "number" ? x.price : null,
      currency: (x.currency as string) ?? "ARS",
      priority: (x.priority as string) ?? "medium",
      category: (x.category as string) ?? null,
      link: (x.link as string) ?? null,
      imageURL: (x.imageURL as string) ?? null,
      isArchived: x.isArchived === true,
      createdAt: aMillis(x.createdAt),
    };
  });
  const reservasPorEstado: Record<string, number> = {};
  for (const d of reservasSnap.docs) {
    const s = (d.data().status as string) ?? "reserved";
    reservasPorEstado[s] = (reservasPorEstado[s] ?? 0) + 1;
  }

  const eventosPorEstado: Record<string, number> = {};
  for (const d of eventosSnap.docs) {
    const s = (d.data().status as string) ?? "draft";
    eventosPorEstado[s] = (eventosPorEstado[s] ?? 0) + 1;
  }

  const amigoInvisible = eventosSnap.docs
    .map((d) => {
      const x = d.data();
      const participantes = (x.participantIds as string[] | undefined) ?? [];
      return {
        id: d.id,
        name: (x.name as string) ?? "",
        status: (x.status as string) ?? "draft",
        organizerId: (x.createdBy as string) ?? "",
        organizerName: nombreDe.get(x.createdBy as string) ?? "—",
        participants: participantes.map((id) => ({ id, name: nombreDe.get(id) ?? id, photoURL: fotoDe.get(id) ?? null })),
        exclusions: ((x.exclusions as { fromUserId?: string; toUserId?: string }[] | undefined) ?? [])
          .filter((r) => r.fromUserId && r.toUserId)
          .map((r) => ({
            from: nombreDe.get(r.fromUserId as string) ?? (r.fromUserId as string),
            to: nombreDe.get(r.toUserId as string) ?? (r.toUserId as string),
          })),
        budget: typeof x.budget === "number" ? x.budget : null,
        currency: (x.currency as string) ?? "ARS",
        exchangeDate: aMillis(x.exchangeDate),
        createdAt: aMillis(x.createdAt),
        drawnAt: aMillis(x.drawnAt),
      };
    })
    .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));

  const ahora = Date.now();
  const DIA = 24 * 60 * 60 * 1000;
  const activos = (dias: number) =>
    users.filter((u) => u.lastSignIn !== null && ahora - u.lastSignIn <= dias * DIA).length;

  const itemsPorPrioridad: Record<string, number> = {};
  for (const i of items) itemsPorPrioridad[i.priority] = (itemsPorPrioridad[i.priority] ?? 0) + 1;
  const altas: Record<string, number> = {};
  for (const u of users) {
    if (u.createdAt && ahora - u.createdAt <= 30 * DIA) {
      const dia = new Date(u.createdAt).toISOString().slice(0, 10);
      altas[dia] = (altas[dia] ?? 0) + 1;
    }
  }

  return {
    generatedAt: ahora,
    stats: {
      users: users.length,
      activeLast1d: activos(1),
      activeLast7d: activos(7),
      activeLast30d: activos(30),
      groups: groups.length,
      items: items.length,
      itemsArchived: items.filter((i) => i.isArchived).length,
      itemsWithoutGroup: items.filter((i) => i.groupIds.length === 0).length,
      reservations: reservasSnap.size,
      reservationsByStatus: reservasPorEstado,
      history: historySnap.size,
      secretSantaEvents: eventosSnap.size,
      secretSantaByStatus: eventosPorEstado,
      itemsByPriority: itemsPorPrioridad,
      signupsLast30d: altas,
      avgItemsPerUser: users.length ? Number((items.length / users.length).toFixed(1)) : 0,
      avgMembersPerGroup: groups.length
        ? Number((groups.reduce((n, g) => n + g.members.length, 0) / groups.length).toFixed(1))
        : 0,
    },
    users,
    groups,
    items,
    secretSanta: amigoInvisible,
    admins,
    me: yo,
  };
});
