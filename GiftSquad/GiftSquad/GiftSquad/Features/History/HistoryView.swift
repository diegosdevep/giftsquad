import SwiftUI
import FirebaseFirestore

struct HistoryView: View {
    let group: GiftGroup
    @State private var entries: [GiftHistoryEntry] = []
    @State private var itemImageURLs: [String: URL] = [:]
    @State private var listener: ListenerRegistration?
    @State private var isLoading = true
    @State private var entryPendingDelete: GiftHistoryEntry?
    @State private var errorMessage: String?

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private var groupedEntries: [(month: String, entries: [GiftHistoryEntry])] {
        var order: [String] = []
        var buckets: [String: [GiftHistoryEntry]] = [:]
        for entry in entries {
            let key = Self.monthFormatter.string(from: entry.deliveredAt).capitalized
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(entry)
        }
        return order.map { (month: $0, entries: buckets[$0] ?? []) }
    }

    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { _ in GSSkeletonCard() }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            } else if entries.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Sin historial todavía",
                    message: "Cuando se entreguen regalos, van a quedar registrados acá.",
                    primaryActionTitle: nil,
                    primaryAction: nil
                )
            } else {
                List {
                    ForEach(groupedEntries, id: \.month) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                HistoryEntryCard(
                                    entry: entry,
                                    imageURL: itemImageURLs[entry.itemId]
                                )
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        entryPendingDelete = entry
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            GSSectionLabel(title: section.month)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                                .textCase(nil)
                        }
                        .listSectionSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(GSPalette.crema)
            }
        }
        .background(GSPalette.crema.ignoresSafeArea())
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListener() }
        .onDisappear { listener?.remove() }
        .onChange(of: entries) { _, _ in Task { await loadItemImages() } }
        .refreshable { await loadItemImages() }
        .gsConfirmDialog(
            isPresented: Binding(
                get: { entryPendingDelete != nil },
                set: { if !$0 { entryPendingDelete = nil } }
            ),
            icon: "trash.fill",
            title: "¿Eliminar \(entryPendingDelete?.itemName ?? "esta entrega")?",
            message: "Se borra del historial para todo el grupo. No se puede deshacer.",
            confirmTitle: "Eliminar",
            onConfirm: { Task { await deleteEntry() } }
        )
        .gsErrorAlert(message: $errorMessage)
    }

    private func deleteEntry() async {
        guard let id = entryPendingDelete?.id else { return }
        do {
            try await FirestoreService.shared.deleteHistoryEntry(id)
        } catch {
            errorMessage = error.localizedDescription
        }
        entryPendingDelete = nil
    }

    private func attachListener() {
        guard let gid = group.id else { return }
        listener?.remove()
        listener = FirestoreService.shared.history()
            .whereField("groupId", isEqualTo: gid)
            .order(by: "deliveredAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeHistory: \(error)")
                }
                self.entries = snap?.documents
                    .compactMap { try? $0.data(as: GiftHistoryEntry.self) } ?? []
                isLoading = false
            }
    }

    private func loadItemImages() async {
        let candidateIds = Set(entries.map(\.itemId)).subtracting(itemImageURLs.keys)
        guard !candidateIds.isEmpty else { return }
        for id in candidateIds {
            guard let doc = try? await FirestoreService.shared.item(id).getDocument(),
                  let item = try? doc.data(as: WishlistItem.self),
                  let url = item.imageURL else { continue }
            itemImageURLs[id] = url
        }
    }
}

private struct HistoryEntryCard: View {
    let entry: GiftHistoryEntry
    let imageURL: URL?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GSPalette.menta.opacity(0.10))
                    .frame(width: 56, height: 56)
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "gift.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(GSPalette.menta)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.itemName)
                    .font(GSFont.body(15, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .lineLimit(1)
                if let occasion = entry.occasion, !occasion.isEmpty {
                    Text(occasion)
                        .font(GSFont.caption(11))
                        .foregroundStyle(GSPalette.grafito)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(entry.deliveredAt, style: .date)
                        .font(GSFont.caption(11))
                }
                .foregroundStyle(GSPalette.menta)
            }

            Spacer(minLength: 8)

            if let amount = entry.amount {
                Text(amount, format: .currency(code: entry.currency))
                    .font(GSFont.body(15, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: GSPalette.noche.opacity(0.05), radius: 6, y: 2)
        )
    }
}
