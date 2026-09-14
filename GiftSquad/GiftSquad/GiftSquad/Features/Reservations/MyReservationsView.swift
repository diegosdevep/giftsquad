import SwiftUI
import FirebaseFirestore

private struct ReservedItemInfo: Identifiable {
    let reservation: Reservation
    let item: WishlistItem?
    let groupName: String?
    var id: String { reservation.id ?? UUID().uuidString }
}

struct MyReservationsView: View {
    @State private var infos: [ReservedItemInfo] = []
    @State private var isLoading = true
    @State private var selectedItem: WishlistItem?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if infos.isEmpty {
                EmptyStateView(
                    icon: "hand.raised",
                    title: "No reservaste nada todavía",
                    message: "Cuando reserves un regalo para alguien, va a aparecer acá.",
                    primaryActionTitle: nil,
                    primaryAction: nil
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(infos) { info in
                            Button {
                                selectedItem = info.item
                            } label: {
                                reservationRow(info)
                            }
                            .buttonStyle(.plain)
                            .disabled(info.item == nil)
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Mis reservas")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                WishlistItemDetailView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { selectedItem = nil }
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
            }
        }
    }

    private func reservationRow(_ info: ReservedItemInfo) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GSPalette.grafito.opacity(0.10))
                    .frame(width: 56, height: 56)
                AsyncImage(url: info.item?.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "gift")
                            .foregroundStyle(GSPalette.grafito)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(info.item?.name ?? "Ítem eliminado")
                    .font(GSFont.body(15, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .lineLimit(1)
                if let groupName = info.groupName {
                    Text(groupName)
                        .font(GSFont.caption(12))
                        .foregroundStyle(GSPalette.grafito)
                }
                statusBadge(info.reservation.status)
            }
            Spacer()
            if info.item != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GSPalette.grafito.opacity(0.4))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: GSPalette.noche.opacity(0.06), radius: 8, y: 3)
        )
    }

    private func statusBadge(_ status: ReservationStatus) -> some View {
        let color: Color = {
            switch status {
            case .reserved: return GSPalette.durazno
            case .purchased: return GSPalette.menta
            case .released: return GSPalette.grafito
            }
        }()
        return Text(status.shortLabel)
            .font(GSFont.caption(10))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    private func load() async {
        guard let uid = AuthService.shared.currentUserId else {
            isLoading = false
            return
        }
        defer { isLoading = false }
        do {
            let snap = try await FirestoreService.shared.reservations()
                .whereField("reservedBy", isEqualTo: uid)
                .getDocuments()
            let active = snap.documents
                .compactMap { try? $0.data(as: Reservation.self) }
                .filter { $0.status.isActive }
                .sorted { $0.reservedAt > $1.reservedAt }

            var result: [ReservedItemInfo] = []
            for res in active {
                let itemDoc = try? await FirestoreService.shared.item(res.itemId).getDocument()
                let item = itemDoc.flatMap { try? $0.data(as: WishlistItem.self) }
                let groupDoc = try? await FirestoreService.shared.group(res.groupId).getDocument()
                let groupName = groupDoc.flatMap { try? $0.data(as: GiftGroup.self) }?.name
                result.append(ReservedItemInfo(reservation: res, item: item, groupName: groupName))
            }
            self.infos = result
        } catch {
            Logger.shared.error("MyReservationsView load: \(error)")
        }
    }
}
