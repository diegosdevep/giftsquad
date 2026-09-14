import SwiftUI
import FirebaseFirestore

struct WishlistItemDetailView: View {
    @State private var item: WishlistItem
    @State private var privateNotes: String?
    @State private var reservation: Reservation?
    @State private var crossGroupLock: ItemLock?
    @State private var reservationGroupId: String?
    @State private var isCheckingReservation = true
    @State private var isReserving = false
    @State private var isCancelling = false
    @State private var isMarkingDelivered = false
    @State private var showReserveConfirm = false
    @State private var showCancelConfirm = false
    @State private var showMarkDeliveredConfirm = false
    @State private var showEditItem = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(item: WishlistItem) {
        _item = State(initialValue: item)
    }

    private var isOwner: Bool { item.ownerId == AuthService.shared.currentUserId }

    private var isMyReservation: Bool {
        reservation?.reservedBy == AuthService.shared.currentUserId
    }

    var body: some View {
        ZStack(alignment: .top) {
            GSPalette.crema.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.name)
                                .font(GSFont.display(21))
                                .foregroundStyle(GSPalette.noche)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)

                            if let percent = item.discountPercent, let originalPrice = item.originalPrice {
                                HStack(spacing: 8) {
                                    Text(originalPrice, format: .currency(code: item.currency))
                                        .font(GSFont.body(13))
                                        .foregroundStyle(GSPalette.grafito)
                                        .strikethrough(color: GSPalette.grafito)
                                    Text("-\(percent)% OFF")
                                        .font(GSFont.caption(11))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(GSPalette.alerta))
                                }
                            }

                            HStack(spacing: 8) {
                                if let price = item.price {
                                    Text(price, format: .currency(code: item.currency))
                                        .font(GSFont.body(16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(
                                                LinearGradient(
                                                    colors: [GSPalette.menta, GSPalette.oceano],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        )
                                }
                                PriorityBadge(priority: item.priority)
                                if let category = item.category, !category.isEmpty {
                                    Text(category)
                                        .font(GSFont.caption(10))
                                        .foregroundStyle(GSPalette.durazno)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(GSPalette.durazno.opacity(0.14)))
                                        .lineLimit(1)
                                }
                            }

                            Text("Agregado el \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(GSFont.caption(11))
                                .foregroundStyle(GSPalette.grafito)
                        }

                        if let descriptionText = item.descriptionText, !descriptionText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                GSSectionLabel(title: "Descripción")
                                GSCard {
                                    Text(descriptionText)
                                        .font(GSFont.body(14))
                                        .foregroundStyle(GSPalette.grafito)
                                        .padding(16)
                                }
                            }
                        }

                        if !item.allLinks.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(Array(item.allLinks.enumerated()), id: \.offset) { index, link in
                                    Link(destination: link) {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "safari")
                                            Text(item.allLinks.count > 1 ? "Ver tienda \(index + 1)" : "Ver en la tienda")
                                                .font(GSFont.body(15, weight: .bold))
                                            Spacer()
                                        }
                                        .foregroundStyle(GSPalette.oceano)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(GSPalette.oceano.opacity(0.4), lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                        }

                        if !item.variants.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                GSSectionLabel(title: "Variantes")
                                GSCard {
                                    ForEach(Array(item.variants.enumerated()), id: \.offset) { index, v in
                                        HStack(spacing: 10) {
                                            Image(systemName: "tag.fill")
                                                .foregroundStyle(GSPalette.durazno)
                                            Text(v.label)
                                                .font(GSFont.body(14, weight: .semibold))
                                                .foregroundStyle(GSPalette.noche)
                                            if let note = v.note {
                                                Text("· \(note)")
                                                    .font(GSFont.body(14))
                                                    .foregroundStyle(GSPalette.grafito)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        if index < item.variants.count - 1 { GSDivider() }
                                    }
                                }
                            }
                        }

                        if isOwner, let notes = privateNotes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                    Text("Notas privadas")
                                        .font(GSFont.caption(12))
                                }
                                .foregroundStyle(GSPalette.durazno)
                                Text(notes)
                                    .font(GSFont.body(14))
                                    .foregroundStyle(GSPalette.noche)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(GSPalette.durazno.opacity(0.12))
                            )
                        }

                        if isOwner, let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
                        }

                        if !isOwner {
                            if isCheckingReservation {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            } else if let reservation {
                                GSBanner(
                                    message: isMyReservation ? "Vos lo reservaste." : reservation.status.message,
                                    isError: false
                                )
                                if isMyReservation, reservation.status != .purchased {
                                    Button {
                                        showCancelConfirm = true
                                    } label: {
                                        Text("Cancelar mi reserva")
                                            .font(GSFont.body(14, weight: .bold))
                                            .foregroundStyle(GSPalette.alerta)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(GSPalette.alerta.opacity(0.4), lineWidth: 1.5)
                                            )
                                    }
                                    .disabled(isCancelling)
                                    markDeliveredButton
                                }
                                if let errorMessage {
                                    GSBanner(message: errorMessage, isError: true)
                                }
                            } else if let crossGroupLock {
                                GSBanner(message: crossGroupLockMessage(crossGroupLock), isError: false)
                            } else {
                                GSPrimaryButton(
                                    title: "Reservar este regalo",
                                    isLoading: isReserving,
                                    isEnabled: reservationGroupId != nil && !isReserving
                                ) {
                                    showReserveConfirm = true
                                }

                                Text("El dueño de la lista no verá quién lo reservó.")
                                    .font(GSFont.caption(12))
                                    .foregroundStyle(GSPalette.grafito)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GSPalette.crema)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Editar", systemImage: "pencil") { showEditItem = true }
                        Button("Eliminar", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(GSPalette.noche)
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .task {
            await loadReservationStatus()
            await loadPrivateNotesIfOwner()
        }
        .refreshable { await loadReservationStatus() }
        .sheet(isPresented: $showEditItem) {
            AddWishlistItemView(existingItem: item) { updated in
                item = updated
                Task { await loadPrivateNotesIfOwner() }
            }
        }
        .gsConfirmDialog(
            isPresented: $showReserveConfirm,
            icon: "gift.fill",
            iconTint: GSPalette.oceano,
            title: "¿Reservar este regalo?",
            message: "Lo vas a reservar vos solo. El dueño de la lista nunca va a saber que fuiste vos.",
            confirmTitle: "Reservar",
            isDestructive: false,
            onConfirm: { Task { await reserveItem() } }
        )
        .gsConfirmDialog(
            isPresented: $showMarkDeliveredConfirm,
            icon: "checkmark.seal.fill",
            iconTint: GSPalette.menta,
            title: "¿Marcar como entregado?",
            message: "Vas a confirmar que este regalo ya se lo diste. Pasa al historial del grupo.",
            confirmTitle: "Marcar entregado",
            isDestructive: false,
            onConfirm: { Task { await markDelivered() } }
        )
        .gsConfirmDialog(
            isPresented: $showCancelConfirm,
            icon: "xmark.circle.fill",
            title: "¿Cancelar tu reserva?",
            message: "El regalo va a quedar disponible de nuevo para el resto del grupo.",
            confirmTitle: "Cancelar reserva",
            cancelTitle: "Volver",
            onConfirm: { Task { await cancelReservation() } }
        )
        .gsConfirmDialog(
            isPresented: $showDeleteConfirm,
            icon: "trash.fill",
            title: "¿Eliminar este ítem?",
            message: "Se va a borrar de tu lista y de todos los grupos donde era visible. No se puede deshacer.",
            confirmTitle: "Eliminar",
            onConfirm: { Task { await deleteItem() } }
        )
    }

    private func loadPrivateNotesIfOwner() async {
        guard isOwner, let id = item.id else { return }
        privateNotes = try? await FirestoreService.shared.fetchPrivateNotes(forItem: id)
    }

    private func deleteItem() async {
        guard let id = item.id else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await FirestoreService.shared.archiveItem(id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reserveItem() async {
        guard let uid = AuthService.shared.currentUserId, let groupId = reservationGroupId else { return }
        isReserving = true
        errorMessage = nil
        defer { isReserving = false }
        do {
            _ = try await FirestoreService.shared.reserve(item: item, groupId: groupId, by: uid)
            await loadReservationStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var markDeliveredButton: some View {
        Button {
            showMarkDeliveredConfirm = true
        } label: {
            Text(isMarkingDelivered ? "Marcando…" : "Marcar como entregado")
                .font(GSFont.body(14, weight: .bold))
                .foregroundStyle(GSPalette.menta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(GSPalette.menta.opacity(0.4), lineWidth: 1.5)
                )
        }
        .disabled(isMarkingDelivered)
    }

    private func markDelivered() async {
        guard let uid = AuthService.shared.currentUserId, let id = reservation?.id else { return }
        isMarkingDelivered = true
        errorMessage = nil
        defer { isMarkingDelivered = false }
        do {
            try await FirestoreService.shared.markDelivered(id, by: uid)
            reservation?.status = .purchased
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelReservation() async {
        guard let uid = AuthService.shared.currentUserId, let id = reservation?.id else { return }
        isCancelling = true
        errorMessage = nil
        defer { isCancelling = false }
        do {
            try await FirestoreService.shared.releaseReservation(id, by: uid)
            reservation = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func crossGroupLockMessage(_ lock: ItemLock) -> String {
        lock.kind == "purchased"
            ? "Ya fue entregado (en otro de tus grupos)."
            : "Ya fue reservado en otro de tus grupos."
    }

    private func loadReservationStatus() async {
        guard !isOwner, let itemId = item.id, let uid = AuthService.shared.currentUserId else {
            isCheckingReservation = false
            return
        }
        isCheckingReservation = true
        defer { isCheckingReservation = false }
        do {
            let groupsSnap = try await FirestoreService.shared.groups()
                .whereField("memberIds", arrayContains: uid)
                .getDocuments()
            let myGroupIds = Set(groupsSnap.documents.map(\.documentID))
            if let groupId = item.groupIds.first(where: { myGroupIds.contains($0) }) {
                reservationGroupId = groupId
                reservation = try await FirestoreService.shared.activeReservation(
                    itemId: itemId, groupId: groupId, viewerId: uid
                )
            } else {
                reservationGroupId = nil
                reservation = nil
            }
            crossGroupLock = reservation == nil
                ? try await FirestoreService.shared.activeItemLock(itemId)
                : nil
        } catch {
            Logger.shared.error("loadReservationStatus: \(error)")
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        ZStack {
            if let imageURL = item.imageURL {
                LinearGradient(
                    colors: [GSPalette.menta.opacity(0.10), GSPalette.oceano.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .clipped()
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [GSPalette.menta.opacity(0.18), GSPalette.oceano.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "gift.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [GSPalette.menta, GSPalette.oceano],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
