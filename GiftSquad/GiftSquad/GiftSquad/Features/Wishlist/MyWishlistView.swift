import SwiftUI
import FirebaseFirestore

struct MyWishlistView: View {
    @State private var items: [WishlistItem] = []
    @State private var listener: ListenerRegistration?
    @State private var isLoading = true
    @State private var showAdd = false
    @State private var groupNames: [String: String] = [:]
    @State private var groupEmojis: [String: String] = [:]
    @State private var itemPendingDelete: WishlistItem?
    @State private var selectedFilter: ListFilter = .all

    private enum ListFilter: Hashable {
        case all
        case anyGroup
        case personal
        case group(id: String)
    }

    private var inGroupsCount: Int { items.filter { !$0.groupIds.isEmpty }.count }
    private var personalCount: Int { items.count - inGroupsCount }

    private var groupIdsWithItems: [String] {
        let ids = Set(items.flatMap(\.groupIds))
        return ids.sorted { (groupNames[$0] ?? "") < (groupNames[$1] ?? "") }
    }

    private var filteredItems: [WishlistItem] {
        switch selectedFilter {
        case .all: return items
        case .anyGroup: return items.filter { !$0.groupIds.isEmpty }
        case .personal: return items.filter { $0.groupIds.isEmpty }
        case .group(let id): return items.filter { $0.groupIds.contains(id) }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let waveHeight = max(geo.size.height * 0.24, 170)

            ZStack(alignment: .top) {
                GSPalette.crema.ignoresSafeArea()

                GSTopWave()
                    .fill(
                        LinearGradient(
                            colors: [GSPalette.menta, GSPalette.oceano],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: waveHeight)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                if isLoading {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Spacer(minLength: waveHeight - 40)
                            VStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { _ in GSSkeletonCard() }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollContentBackground(.hidden)
                } else if items.isEmpty {
                    EmptyStateView(
                        icon: "gift",
                        title: "Tu lista está vacía",
                        message: "Agregá productos con un link y los demás van a poder regalarte.",
                        primaryActionTitle: "Agregar ítem",
                        primaryAction: { showAdd = true }
                    )
                } else {
                    List {
                        Section {
                            VStack(spacing: 22) {
                                heroHeader(waveHeight: waveHeight)
                                filterBar
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        if filteredItems.isEmpty {
                            Text("Nada en este filtro todavía.")
                                .font(GSFont.body(13))
                                .foregroundStyle(GSPalette.grafito)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            Section {
                                ForEach(filteredItems) { item in
                                    ZStack {
                                        WishlistItemRow(item: item, isOwner: true, groupNames: groupNames, showChevron: false)
                                        NavigationLink(value: item) { Color.clear }
                                            .opacity(0)
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                    .listRowBackground(Color.white)
                                    .listRowSeparator(.visible)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            itemPendingDelete = item
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    GSToolbarIcon(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWishlistItemView()
        }
        .navigationDestination(for: WishlistItem.self) { item in
            WishlistItemDetailView(item: item)
        }
        .onAppear {
            attachListener()
            Task { await loadGroupNames() }
        }
        .refreshable { await loadGroupNames() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .gsConfirmDialog(
            isPresented: Binding(
                get: { itemPendingDelete != nil },
                set: { if !$0 { itemPendingDelete = nil } }
            ),
            icon: "trash.fill",
            title: "¿Eliminar \(itemPendingDelete?.name ?? "este ítem")?",
            message: "Se va a borrar de tu lista y de todos los grupos donde era visible. No se puede deshacer.",
            confirmTitle: "Eliminar",
            onConfirm: {
                if let id = itemPendingDelete?.id {
                    Task { try? await FirestoreService.shared.archiveItem(id) }
                }
                itemPendingDelete = nil
            }
        )
    }

    private func heroHeader(waveHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(GSPalette.crema).frame(width: 108, height: 108)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
            }

            Text("Mi lista")
                .font(GSFont.display(20))
                .foregroundStyle(GSPalette.noche)

            Text(items.count == 1 ? "1 regalo en tu radar" : "\(items.count) regalos en tu radar")
                .font(GSFont.caption(12))
                .foregroundStyle(GSPalette.oceano)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(GSPalette.oceano.opacity(0.12)))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                statChip(value: "\(items.count)", label: "Total", color: GSPalette.oceano, isSelected: selectedFilter == .all) {
                    selectedFilter = .all
                }
                statChip(value: "\(inGroupsCount)", label: "En grupos", color: GSPalette.mandarina, isSelected: selectedFilter == .anyGroup) {
                    selectedFilter = .anyGroup
                }
                statChip(value: "\(personalCount)", label: "Personales", color: GSPalette.grafito, isSelected: selectedFilter == .personal) {
                    selectedFilter = .personal
                }
            }

            if !groupIdsWithItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "Todas", emoji: nil, count: items.count, isSelected: selectedFilter == .all) {
                            selectedFilter = .all
                        }
                        ForEach(groupIdsWithItems, id: \.self) { groupId in
                            let count = items.filter { $0.groupIds.contains(groupId) }.count
                            filterChip(
                                title: groupNames[groupId] ?? "Grupo",
                                emoji: groupEmojis[groupId],
                                count: count,
                                isSelected: selectedFilter == .group(id: groupId)
                            ) {
                                selectedFilter = .group(id: groupId)
                            }
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private func statChip(value: String, label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(value)
                    .font(GSFont.display(19))
                    .foregroundStyle(isSelected ? .white : GSPalette.noche)
                Text(label)
                    .font(GSFont.caption(11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : GSPalette.grafito)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? color : Color.white)
                    .shadow(color: GSPalette.noche.opacity(isSelected ? 0.12 : 0.06), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.clear : color.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func filterChip(title: String, emoji: String?, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.system(size: 13))
                }
                Text(title)
                    .font(GSFont.body(13, weight: .bold))
                    .lineLimit(1)
                Text("\(count)")
                    .font(GSFont.caption(11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : GSPalette.grafito)
            }
            .foregroundStyle(isSelected ? .white : GSPalette.noche)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? GSPalette.oceano : Color.white)
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : GSPalette.grafito.opacity(0.18), lineWidth: 1.2)
            )
            .shadow(color: GSPalette.noche.opacity(isSelected ? 0.12 : 0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func attachListener() {
        guard let uid = AuthService.shared.currentUserId else { return }
        listener?.remove()
        listener = FirestoreService.shared
            .items()
            .whereField("ownerId", isEqualTo: uid)
            .whereField("isArchived", isEqualTo: false)
            .addSnapshotListener { snap, error in
                if let error {
                    Logger.shared.error("observeMyItems: \(error)")
                }
                self.items = snap?.documents
                    .compactMap { try? $0.data(as: WishlistItem.self) } ?? []
                isLoading = false
            }
    }

    private func loadGroupNames() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            let snap = try await FirestoreService.shared.groups()
                .whereField("memberIds", arrayContains: uid)
                .getDocuments()
            var names: [String: String] = [:]
            var emojis: [String: String] = [:]
            for doc in snap.documents {
                guard let group = try? doc.data(as: GiftGroup.self), let id = group.id else { continue }
                names[id] = group.name
                emojis[id] = group.emoji
            }
            self.groupNames = names
            self.groupEmojis = emojis
        } catch {
            Logger.shared.error("loadGroupNames: \(error)")
        }
    }
}

struct WishlistItemRow: View {
    let item: WishlistItem
    let isOwner: Bool
    var groupNames: [String: String] = [:]
    var trailingBadge: AnyView? = nil
    var showChevron: Bool = true

    private static let groupColors: [Color] = [
        GSPalette.oceano, GSPalette.mandarina, GSPalette.menta, GSPalette.durazno, GSPalette.alerta
    ]

    private func color(for groupId: String) -> Color {
        Self.groupColors[abs(groupId.hashValue) % Self.groupColors.count]
    }

    private var groupChips: [(id: String, name: String, color: Color)] {
        guard !item.groupIds.isEmpty else {
            return [("_personal", "Solo en tu lista", GSPalette.grafito)]
        }
        let chips = item.groupIds.compactMap { id -> (String, String, Color)? in
            guard let name = groupNames[id] else { return nil }
            return (id, name, color(for: id))
        }
        return chips.isEmpty ? [("_personal", "Solo en tu lista", GSPalette.grafito)] : chips
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(GSPalette.grafito.opacity(0.10))
                    .frame(width: 60, height: 60)
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(GSPalette.grafito)
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(GSFont.body(14, weight: .bold))
                        .foregroundStyle(GSPalette.noche)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let price = item.price {
                        Text(price, format: .currency(code: item.currency))
                            .font(GSFont.body(13, weight: .bold))
                            .foregroundStyle(GSPalette.mandarina)
                            .lineLimit(1)
                    }
                }

                if let percent = item.discountPercent {
                    Text("-\(percent)% OFF")
                        .font(GSFont.caption(9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(GSPalette.alerta))
                }

                HStack(spacing: 6) {
                    PriorityBadge(priority: item.priority)
                    if isOwner {
                        ForEach(Array(groupChips.prefix(2)), id: \.id) { chip in
                            HStack(spacing: 3) {
                                Image(systemName: chip.id == "_personal" ? "lock.fill" : "circle.fill")
                                    .font(.system(size: chip.id == "_personal" ? 7 : 5, weight: .bold))
                                Text(chip.name)
                                    .font(GSFont.body(9, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(chip.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(chip.color.opacity(0.14)))
                        }
                        if groupChips.count > 2 {
                            Text("+\(groupChips.count - 2)")
                                .font(GSFont.body(9, weight: .bold))
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
                }
            }

            if let trailingBadge {
                trailingBadge
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GSPalette.grafito.opacity(0.4))
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { MyWishlistView() }
}
