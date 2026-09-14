import SwiftUI
import FirebaseFirestore

struct ActiveEventsView: View {
    @State private var reservationPreviews: [ReservationPreview] = []
    @State private var totalReservationsCount = 0
    @State private var isLoading = true

    private var isEmpty: Bool {
        reservationPreviews.isEmpty
    }

    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            GSSectionLabel(title: "Mis reservas")
                            VStack(spacing: 12) {
                                ForEach(0..<2, id: \.self) { _ in GSSkeletonCard() }
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            } else if isEmpty {
                EmptyStateView(
                    icon: "hand.raised.fill",
                    title: "Sin reservas activas",
                    message: "Cuando reserves o entregues un regalo, va a aparecer acá.",
                    primaryActionTitle: nil,
                    primaryAction: nil
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        reservationsSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Reservas")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: EventItemRef.self) { ref in
            WishlistItemDetailView(item: ref.item)
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    private var reservationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GSSectionLabel(title: "Mis reservas")
                Spacer()
                if totalReservationsCount > reservationPreviews.count {
                    NavigationLink {
                        MyReservationsView()
                    } label: {
                        HStack(spacing: 2) {
                            Text("Ver todas (\(totalReservationsCount))")
                            Image(systemName: "chevron.right")
                        }
                        .font(GSFont.body(12, weight: .bold))
                        .foregroundStyle(GSPalette.oceano)
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(spacing: 12) {
                ForEach(reservationPreviews) { preview in
                    if let item = preview.item {
                        NavigationLink(value: EventItemRef(item: item)) {
                            EventReservationRow(preview: preview)
                        }
                        .buttonStyle(.plain)
                    } else {
                        EventReservationRow(preview: preview)
                    }
                }
            }
        }
    }

    private func loadAll() async {
        guard let uid = AuthService.shared.currentUserId else {
            isLoading = false
            return
        }
        defer { isLoading = false }
        await loadReservations(uid: uid)
    }

    private func loadReservations(uid: String) async {
        do {
            let snap = try await FirestoreService.shared.reservations()
                .whereField("reservedBy", isEqualTo: uid)
                .getDocuments()
            let active = snap.documents
                .compactMap { try? $0.data(as: Reservation.self) }
                .filter { $0.status.isActive }
                .sorted { $0.reservedAt > $1.reservedAt }
            self.totalReservationsCount = active.count

            var result: [ReservationPreview] = []
            for res in active.prefix(4) {
                let itemDoc = try? await FirestoreService.shared.item(res.itemId).getDocument()
                let item = itemDoc.flatMap { try? $0.data(as: WishlistItem.self) }
                result.append(ReservationPreview(reservation: res, item: item))
            }
            self.reservationPreviews = result
        } catch {
            Logger.shared.error("ActiveEventsView.loadReservations: \(error)")
        }
    }
}

private struct EventItemRef: Hashable { let item: WishlistItem }

private struct ReservationPreview: Identifiable {
    let reservation: Reservation
    let item: WishlistItem?
    var id: String { reservation.id ?? UUID().uuidString }
}

private struct EventReservationRow: View {
    let preview: ReservationPreview

    private var statusColor: Color {
        switch preview.reservation.status {
        case .reserved: return GSPalette.durazno
        case .purchased: return GSPalette.menta
        case .released: return GSPalette.grafito
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GSPalette.grafito.opacity(0.10))
                    .frame(width: 52, height: 52)
                AsyncImage(url: preview.item?.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "gift")
                            .foregroundStyle(GSPalette.grafito)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.item?.name ?? "Ítem eliminado")
                    .font(GSFont.body(14, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .lineLimit(1)
                Text(preview.reservation.status.shortLabel)
                    .font(GSFont.caption(10))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(statusColor.opacity(0.14)))
            }
            Spacer()
            if preview.item != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GSPalette.grafito.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: GSPalette.noche.opacity(0.05), radius: 6, y: 2)
        )
    }
}

#Preview {
    NavigationStack { ActiveEventsView() }
}
