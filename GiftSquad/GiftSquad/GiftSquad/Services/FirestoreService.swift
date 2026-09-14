import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreService {
    static let shared = FirestoreService()
    let db: Firestore

    private init() {
        self.db = Firestore.firestore()
    }

    func users() -> CollectionReference { db.collection("users") }
    func user(_ uid: String) -> DocumentReference { users().document(uid) }

    func groups() -> CollectionReference { db.collection("groups") }
    func group(_ id: String) -> DocumentReference { groups().document(id) }

    func items() -> CollectionReference { db.collection("items") }
    func item(_ id: String) -> DocumentReference { items().document(id) }

    func reservations() -> CollectionReference { db.collection("reservations") }
    func reservation(_ id: String) -> DocumentReference { reservations().document(id) }

    func secretSantaEvents() -> CollectionReference { db.collection("secretSantaEvents") }
    func secretSantaEvent(_ id: String) -> DocumentReference { secretSantaEvents().document(id) }
    func assignments(of eventId: String) -> CollectionReference {
        secretSantaEvent(eventId).collection("assignments")
    }

    func history() -> CollectionReference { db.collection("history") }
    func historyEntry(_ id: String) -> DocumentReference { history().document(id) }
    func notifications() -> CollectionReference { db.collection("notifications") }

    func secretSantaParticipants(of eventId: String) -> CollectionReference {
        secretSantaEvent(eventId).collection("participants")
    }
}

extension FirestoreService {
    func findUser(matching rawQuery: String) async throws -> AppUser? {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        if let byCode = try await users()
            .whereField("friendCode", isEqualTo: query.uppercased())
            .limit(to: 1)
            .getDocuments()
            .documents.first {
            return try? byCode.data(as: AppUser.self)
        }

        let handle = query.hasPrefix("@") ? String(query.dropFirst()) : query
        if let byUsername = try await users()
            .whereField("usernameLower", isEqualTo: handle.lowercased())
            .limit(to: 1)
            .getDocuments()
            .documents.first {
            return try? byUsername.data(as: AppUser.self)
        }

        if query.contains("@"), let byEmail = try await users()
            .whereField("email", isEqualTo: query.lowercased())
            .limit(to: 1)
            .getDocuments()
            .documents.first {
            return try? byEmail.data(as: AppUser.self)
        }

        return nil
    }

    func addMember(_ member: AppUser, toGroupId groupId: String) async throws {
        guard let memberId = member.id else { throw AppError.firestore("Usuario sin id") }
        try await group(groupId).updateData([
            "memberIds": FieldValue.arrayUnion([memberId])
        ])
        try await user(memberId).updateData([
            "groupIds": FieldValue.arrayUnion([groupId])
        ])
    }

    func updateUsername(_ newUsername: String, for uid: String) async throws {
        let lower = newUsername.lowercased()
        let snap = try await users()
            .whereField("usernameLower", isEqualTo: lower)
            .limit(to: 2)
            .getDocuments()
        let takenByOther = snap.documents.contains { $0.documentID != uid }
        guard !takenByOther else {
            throw AppError.validation("Ese @usuario ya está en uso")
        }
        try await user(uid).updateData([
            "username": newUsername,
            "usernameLower": lower
        ])
    }
}

extension FirestoreService {
    func createGroup(_ group: GiftGroup) async throws -> String {
        let normalized = group.name.trimmingCharacters(in: .whitespaces).lowercased()
        let snap = try await groups()
            .whereField("ownerId", isEqualTo: group.ownerId)
            .getDocuments()
        let alreadyExists = snap.documents.contains { doc in
            guard let existing = try? doc.data(as: GiftGroup.self) else { return false }
            return existing.name.trimmingCharacters(in: .whitespaces).lowercased() == normalized
        }
        guard !alreadyExists else {
            throw AppError.validation("Ya tenés un grupo llamado \"\(group.name)\"")
        }
        let ref = try groups().addDocument(from: group)
        try await user(group.ownerId).updateData([
            "groupIds": FieldValue.arrayUnion([ref.documentID])
        ])
        return ref.documentID
    }

    func joinGroup(inviteCode: String, userId: String) async throws -> GiftGroup {
        let snap = try await groups()
            .whereField("inviteCode", isEqualTo: inviteCode)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first,
              var group = try? doc.data(as: GiftGroup.self),
              let groupId = group.id else {
            throw AppError.firestore("Código de invitación inválido")
        }
        if !group.memberIds.contains(userId) {
            group.memberIds.append(userId)
            try self.group(groupId).setData(from: group, merge: true)
        }
        try await user(userId).updateData([
            "groupIds": FieldValue.arrayUnion([groupId])
        ])
        return group
    }

    func updateGroup(_ groupId: String, name: String, emoji: String) async throws {
        try await group(groupId).updateData([
            "name": name,
            "emoji": emoji
        ])
    }

    func deleteGroup(_ id: String, ownerId: String) async throws {
        if let itemsSnap = try? await items()
            .whereField("ownerId", isEqualTo: ownerId)
            .whereField("groupIds", arrayContains: id)
            .getDocuments() {
            for doc in itemsSnap.documents {
                try? await doc.reference.updateData([
                    "groupIds": FieldValue.arrayRemove([id])
                ])
            }
        }
        try? await user(ownerId).updateData([
            "groupIds": FieldValue.arrayRemove([id])
        ])
        try await group(id).delete()
    }

    func leaveGroup(_ groupId: String, userId: String) async throws {
        try await group(groupId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
        try await user(userId).updateData([
            "groupIds": FieldValue.arrayRemove([groupId])
        ])
    }

    func observeGroups(for userId: String, onChange: @escaping ([GiftGroup]) -> Void) -> ListenerRegistration {
        groups()
            .whereField("memberIds", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeGroups: \(error)")
                }
                let result = snap?.documents.compactMap { try? $0.data(as: GiftGroup.self) } ?? []
                onChange(result)
            }
    }
}

extension FirestoreService {
    func upsertItem(_ item: WishlistItem) async throws -> String {
        var copy = item
        copy.updatedAt = Date()
        if let id = item.id {
            try self.item(id).setData(from: copy, merge: true)
            return id
        } else {
            let ref = try items().addDocument(from: copy)
            return ref.documentID
        }
    }

    func archiveItem(_ id: String) async throws {
        try await item(id).updateData(["isArchived": true])
    }

    private func itemPrivateNotesDoc(_ itemId: String) -> DocumentReference {
        item(itemId).collection("private").document("notes")
    }

    func fetchPrivateNotes(forItem itemId: String) async throws -> String? {
        let doc = try await itemPrivateNotesDoc(itemId).getDocument()
        return (try? doc.data(as: ItemPrivateNotes.self))?.text
    }

    func setPrivateNotes(_ text: String?, forItem itemId: String) async throws {
        let ref = itemPrivateNotesDoc(itemId)
        if let text, !text.isEmpty {
            try ref.setData(from: ItemPrivateNotes(text: text))
        } else {
            try? await ref.delete()
        }
    }

    func observeItems(groupId: String, onChange: @escaping ([WishlistItem]) -> Void) -> ListenerRegistration {
        items()
            .whereField("groupIds", arrayContains: groupId)
            .whereField("isArchived", isEqualTo: false)
            .order(by: "priority")
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeItems: \(error)")
                }
                let result = snap?.documents.compactMap { try? $0.data(as: WishlistItem.self) } ?? []
                onChange(result)
            }
    }
}

extension FirestoreService {
    func reserve(item: WishlistItem, groupId: String, by userId: String) async throws -> String {
        guard let itemId = item.id else { throw AppError.firestore("Ítem sin id") }
        let res = Reservation(
            itemId: itemId,
            itemOwnerId: item.ownerId,
            groupId: groupId,
            reservedBy: userId
        )
        Logger.shared.info("""
            reserve() intentando crear reservation: \
            itemId=\(itemId) itemOwnerId=\(item.ownerId) groupId=\(groupId) \
            reservedBy=\(userId) (equalOwnerUser=\(item.ownerId == userId))
            """)
        do {
            let ref = try reservations().addDocument(from: res)
            Logger.shared.info("reserve() OK, doc=\(ref.documentID)")
            return ref.documentID
        } catch {
            Logger.shared.error("reserve() FALLÓ: \(error)")
            throw error
        }
    }

    func markDelivered(_ id: String, by userId: String) async throws {
        try await reservation(id).updateData([
            "status": ReservationStatus.purchased.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func releaseReservation(_ id: String, by userId: String) async throws {
        try await reservation(id).updateData([
            "status": ReservationStatus.released.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func activeReservation(itemId: String, groupId: String, viewerId: String) async throws -> Reservation? {
        let snap = try await reservations()
            .whereField("itemId", isEqualTo: itemId)
            .whereField("groupId", isEqualTo: groupId)
            .whereField("itemOwnerId", isNotEqualTo: viewerId)
            .getDocuments()
        return snap.documents
            .compactMap { try? $0.data(as: Reservation.self) }
            .first { $0.status.isActive }
    }

    func itemLocks() -> CollectionReference { db.collection("itemLocks") }
    func itemLock(_ itemId: String) -> DocumentReference { itemLocks().document(itemId) }

    func activeItemLock(_ itemId: String) async throws -> ItemLock? {
        let doc = try await itemLock(itemId).getDocument()
        return try? doc.data(as: ItemLock.self)
    }

    func deleteHistoryEntry(_ id: String) async throws {
        try await historyEntry(id).delete()
    }

    /// ANONIMATO: /history/{id}/givers/{uid} solo es legible por ese uid — es la
    /// única forma de saber si vos aportaste a un regalo ya entregado.
    func didIContribute(toHistoryEntry entryId: String, uid: String) async throws -> Bool {
        try await historyEntry(entryId).collection("givers").document(uid).getDocument().exists
    }

    func observeReservations(groupId: String, viewerId: String, onChange: @escaping ([Reservation]) -> Void) -> ListenerRegistration {
        reservations()
            .whereField("groupId", isEqualTo: groupId)
            .whereField("itemOwnerId", isNotEqualTo: viewerId)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeReservations: \(error)")
                }
                let result = snap?.documents
                    .compactMap { try? $0.data(as: Reservation.self) } ?? []
                onChange(result)
            }
    }
}

extension FirestoreService {
    func createSecretSantaEvent(_ event: SecretSantaEvent) async throws -> String {
        let ref = try secretSantaEvents().addDocument(from: event)
        return ref.documentID
    }

    func deleteSecretSantaEvent(_ id: String) async throws {
        try await secretSantaEvent(id).delete()
    }

    func updateSecretSantaBudget(eventId: String, budget: Double?) async throws {
        let value: Any = budget ?? FieldValue.delete()
        try await secretSantaEvent(eventId).updateData(["budget": value])
    }

    func myAssignment(for eventId: String, userId: String) async throws -> SecretSantaAssignment? {
        let snap = try await assignments(of: eventId).document(userId).getDocument()
        return try? snap.data(as: SecretSantaAssignment.self)
    }

    func observeMySecretSantaEvents(uid: String, onChange: @escaping ([SecretSantaEvent]) -> Void) -> ListenerRegistration {
        secretSantaEvents()
            .whereField("participantIds", arrayContains: uid)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeMySecretSantaEvents: \(error)")
                }
                let result = (snap?.documents.compactMap { try? $0.data(as: SecretSantaEvent.self) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                onChange(result)
            }
    }

    func setSharedItems(eventId: String, uid: String, items: [SharedGiftItem]) async throws {
        let encoded = try items.map { try Firestore.Encoder().encode($0) }
        try await secretSantaParticipants(of: eventId).document(uid)
            .setData(["sharedItems": encoded], merge: true)
    }

    func sharedItems(eventId: String, uid: String) async throws -> [SharedGiftItem] {
        let doc = try await secretSantaParticipants(of: eventId).document(uid).getDocument()
        guard let raw = doc.data()?["sharedItems"] as? [[String: Any]] else { return [] }
        return raw.compactMap { try? Firestore.Decoder().decode(SharedGiftItem.self, from: $0) }
    }

    func updateExclusions(eventId: String, exclusions: [ExclusionRule]) async throws {
        let encoded = try exclusions.map { try Firestore.Encoder().encode($0) }
        try await secretSantaEvent(eventId).updateData(["exclusions": encoded])
    }

}

extension FirestoreService {
    func observeUnreadNotificationsCount(uid: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        notifications()
            .whereField("userId", isEqualTo: uid)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeUnreadNotificationsCount: \(error)")
                }
                onChange(snap?.documents.count ?? 0)
            }
    }

    func markNotificationRead(_ id: String) async throws {
        try await notifications().document(id).updateData(["isRead": true])
    }
}
