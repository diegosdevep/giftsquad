import SwiftUI
import FirebaseFirestore

struct NotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var listener: ListenerRegistration?
    @State private var navigateToItem: WishlistItem?
    @State private var navigateToEvent: SecretSantaEvent?

    var body: some View {
        Group {
            if notifications.isEmpty {
                EmptyStateView(
                    icon: "bell",
                    title: "Sin novedades",
                    message: "Te avisamos cuando alguien sume ítems a su lista.",
                    primaryActionTitle: nil,
                    primaryAction: nil
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(notifications) { n in
                            Button {
                                markRead(n)
                                Task { await openDeepLink(n.deepLink) }
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    ZStack {
                                        Circle().fill(GSPalette.oceano.opacity(0.12)).frame(width: 40, height: 40)
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(GSPalette.oceano)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(n.title)
                                            .font(GSFont.body(15, weight: .bold))
                                            .foregroundStyle(GSPalette.noche)
                                        Text(n.body)
                                            .font(GSFont.body(13))
                                            .foregroundStyle(GSPalette.grafito)
                                        Text(n.createdAt, style: .relative)
                                            .font(GSFont.caption(10))
                                            .foregroundStyle(GSPalette.grafito.opacity(0.8))
                                    }
                                    Spacer()
                                    if !n.isRead {
                                        Circle().fill(GSPalette.mandarina).frame(width: 8, height: 8)
                                    }
                                }
                                .padding(14)
                                .gsCardStyle()
                                .opacity(n.isRead ? 0.6 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Avisos")
        .onAppear { attachListener() }
        .onDisappear { listener?.remove() }
        .navigationDestination(item: $navigateToItem) { item in
            WishlistItemDetailView(item: item)
        }
        .navigationDestination(item: $navigateToEvent) { event in
            SecretSantaDetailView(event: event)
        }
    }

    private func openDeepLink(_ deepLink: String?) async {
        guard let deepLink, let separatorIndex = deepLink.firstIndex(of: ":") else { return }
        let kind = deepLink[deepLink.startIndex..<separatorIndex]
        let id = String(deepLink[deepLink.index(after: separatorIndex)...])
        guard !id.isEmpty else { return }

        switch kind {
        case "item":
            guard let doc = try? await FirestoreService.shared.item(id).getDocument(),
                  let item = try? doc.data(as: WishlistItem.self) else { return }
            navigateToItem = item
        case "secretSanta":
            guard let doc = try? await FirestoreService.shared.secretSantaEvent(id).getDocument(),
                  let event = try? doc.data(as: SecretSantaEvent.self) else { return }
            navigateToEvent = event
        default:
            break
        }
    }

    private func attachListener() {
        guard let uid = AuthService.shared.currentUserId else { return }
        listener?.remove()
        listener = FirestoreService.shared.notifications()
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeNotifications: \(error)")
                }
                self.notifications = snap?.documents
                    .compactMap { try? $0.data(as: AppNotification.self) } ?? []
            }
    }

    private func markRead(_ notification: AppNotification) {
        guard !notification.isRead, let id = notification.id else { return }
        Task {
            try? await FirestoreService.shared.markNotificationRead(id)
        }
    }
}

#Preview {
    NavigationStack { NotificationsView() }
}
