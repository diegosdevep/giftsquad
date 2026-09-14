import SwiftUI
import FirebaseFirestore

struct SecretSantaListView: View {
    @State private var events: [SecretSantaEvent] = []
    @State private var listener: ListenerRegistration?
    @State private var showCreate = false
    @State private var eventPendingDelete: SecretSantaEvent?

    var body: some View {
        Group {
            if events.isEmpty {
                EmptyStateView(
                    icon: "theatermasks",
                    title: "Aún no organizaste un Amigo Invisible",
                    message: "Agregá a cualquiera de tus contactos, definí presupuesto y reglas de exclusión — el sorteo es automático.",
                    primaryActionTitle: "Crear evento",
                    primaryAction: { showCreate = true }
                )
            } else {
                List {
                    ForEach(events) { event in
                        ZStack {
                            SecretSantaEventRow(event: event)
                            NavigationLink(value: event) { Color.clear }
                                .opacity(0)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if event.createdBy == AuthService.shared.currentUserId {
                                Button(role: .destructive) {
                                    eventPendingDelete = event
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Amigo Invisible")
        .navigationBarTitleDisplayMode(.inline)
        .gsConfirmDialog(
            isPresented: Binding(
                get: { eventPendingDelete != nil },
                set: { if !$0 { eventPendingDelete = nil } }
            ),
            icon: "trash.fill",
            title: "¿Eliminar \(eventPendingDelete?.name ?? "este evento")?",
            message: "Se borra para todos los participantes, junto con el sorteo si ya se hizo. No se puede deshacer.",
            confirmTitle: "Eliminar",
            onConfirm: {
                if let id = eventPendingDelete?.id {
                    Task { try? await FirestoreService.shared.deleteSecretSantaEvent(id) }
                }
                eventPendingDelete = nil
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    GSToolbarIcon(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateSecretSantaView()
        }
        .navigationDestination(for: SecretSantaEvent.self) { event in
            SecretSantaDetailView(event: event)
        }
        .navigationDestination(for: WishlistItem.self) { item in
            WishlistItemDetailView(item: item)
        }
        .onAppear { attachListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func attachListener() {
        guard let uid = AuthService.shared.currentUserId else { return }
        listener?.remove()
        listener = FirestoreService.shared.observeMySecretSantaEvents(uid: uid) { events in
            self.events = events
        }
    }
}

struct SecretSantaEventRow: View {
    let event: SecretSantaEvent

    private var statusInfo: (label: String, icon: String, color: Color) {
        switch event.status {
        case .draft: return ("Esperando sorteo", "hourglass", GSPalette.durazno)
        case .drawn: return ("Sorteado", "checkmark.seal.fill", GSPalette.oceano)
        case .completed: return ("Finalizado", "checkmark.circle.fill", GSPalette.menta)
        case .cancelled: return ("Cancelado", "xmark.circle.fill", GSPalette.grafito)
        }
    }

    private var isOrganizer: Bool { event.createdBy == AuthService.shared.currentUserId }

    private var metaEntries: [(icon: String, text: String)] {
        var entries: [(icon: String, text: String)] = [
            ("person.2.fill", "\(event.participantIds.count)")
        ]
        if let budget = event.budget {
            entries.append(("dollarsign.circle", budget.formatted(.currency(code: event.currency))))
        }
        if let date = event.exchangeDate {
            entries.append(("calendar", date.formatted(date: .abbreviated, time: .omitted)))
        }
        return entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(statusInfo.color.opacity(0.14)).frame(width: 38, height: 38)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(statusInfo.color)
                        .frame(width: 38, height: 38)
                }

                Text(event.name)
                    .font(GSFont.body(16, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(systemName: statusInfo.icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(statusInfo.label)
                }
                .font(GSFont.caption(10))
                .foregroundStyle(statusInfo.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(statusInfo.color.opacity(0.14)))
                .fixedSize()
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: 38 + 12)
                ForEach(Array(metaEntries.enumerated()), id: \.offset) { index, entry in
                    metaChip(icon: entry.icon, text: entry.text)
                    if index < metaEntries.count - 1 {
                        Spacer(minLength: 8)
                    }
                }
            }
        }
        .padding(12)
        .gsCardStyle()
        .overlay(alignment: .topTrailing) {
            if isOrganizer {
                ZStack {
                    Circle().fill(Color(gsHex: 0xD4AF37)).frame(width: 22, height: 22)
                    Circle().strokeBorder(Color.white, lineWidth: 2).frame(width: 22, height: 22)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: -8, y: 8)
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(GSFont.caption(11))
        .foregroundStyle(GSPalette.grafito)
    }
}
