import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MemberWishlistItem: Hashable {
    let item: WishlistItem
}

struct GroupMemberWishlistView: View {
    let group: GiftGroup
    let member: AppUser
    @State private var items: [WishlistItem] = []
    @State private var reservations: [Reservation] = []
    @State private var crossGroupLocks: [String: ItemLock] = [:]
    @State private var listener: ListenerRegistration?
    @State private var reservationListener: ListenerRegistration?
    @State private var isLoading = true

    private var groupId: String { group.id ?? "" }
    private var memberId: String { member.id ?? "" }

    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in GSSkeletonCard() }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            } else if items.isEmpty {
                EmptyStateView(
                    icon: "gift",
                    title: "\(member.displayName) no agregó nada",
                    message: "Vuelve a chequear más adelante o mandale un toque.",
                    primaryActionTitle: nil,
                    primaryAction: nil
                )
            } else {
                ScrollView {
                    GSCard {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                NavigationLink(value: MemberWishlistItem(item: item)) {
                                    WishlistItemRow(
                                        item: item,
                                        isOwner: false,
                                        trailingBadge: statusBadge(for: item)
                                    )
                                    .padding(.horizontal, 14)
                                }
                                .buttonStyle(.plain)
                                .opacity(isTaken(item) ? 0.55 : 1)
                                if index < items.count - 1 { GSDivider() }
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Lista de \(member.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListeners() }
        .onDisappear {
            listener?.remove(); listener = nil
            reservationListener?.remove(); reservationListener = nil
        }
        .onChange(of: items) { _, _ in Task { await loadCrossGroupLocks() } }
        .onChange(of: reservations) { _, _ in Task { await loadCrossGroupLocks() } }
        .refreshable {
            crossGroupLocks = [:]
            await loadCrossGroupLocks()
        }
    }

    private func reservation(for item: WishlistItem) -> Reservation? {
        reservations.first(where: { $0.itemId == item.id && $0.status.isActive })
    }

    private func isTaken(_ item: WishlistItem) -> Bool {
        reservation(for: item) != nil || (item.id.flatMap { crossGroupLocks[$0] } != nil)
    }

    private func statusBadge(for item: WishlistItem) -> AnyView? {
        if let r = reservation(for: item) {
            let (label, icon, color): (String, String, Color) = {
                switch r.status {
                case .reserved: return ("Reservado", "hand.raised.fill", GSPalette.durazno)
                case .purchased: return ("Entregado", "checkmark.seal.fill", GSPalette.menta)
                case .released: return ("", "", GSPalette.grafito)
                }
            }()
            guard !label.isEmpty else { return nil }
            return badge(label: label, icon: icon, color: color)
        }
        if let itemId = item.id, let lock = crossGroupLocks[itemId] {
            return lock.kind == "purchased"
                ? badge(label: "Entregado", icon: "checkmark.seal.fill", color: GSPalette.menta)
                : badge(label: "Reservado", icon: "hand.raised.fill", color: GSPalette.durazno)
        }
        return nil
    }

    private func badge(label: String, icon: String, color: Color) -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(GSFont.caption(10))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
        )
    }

    private func loadCrossGroupLocks() async {
        let candidateIds = items.compactMap { item -> String? in
            guard let id = item.id, reservation(for: item) == nil, crossGroupLocks[id] == nil else { return nil }
            return id
        }
        for id in candidateIds {
            guard let lock = try? await FirestoreService.shared.activeItemLock(id) else { continue }
            crossGroupLocks[id] = lock
        }
    }

    private func attachListeners() {
        guard let uid = AuthService.shared.currentUserId else { return }

        listener?.remove()
        listener = FirestoreService.shared.items()
            .whereField("ownerId", isEqualTo: memberId)
            .whereField("groupIds", arrayContains: groupId)
            .whereField("isArchived", isEqualTo: false)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeMemberItems: \(error)")
                }
                self.items = snap?.documents
                    .compactMap { try? $0.data(as: WishlistItem.self) } ?? []
                isLoading = false
            }

        reservationListener?.remove()
        reservationListener = FirestoreService.shared
            .observeReservations(groupId: groupId, viewerId: uid) { reservations in
                self.reservations = reservations.filter { $0.itemOwnerId == memberId }
            }
    }
}
