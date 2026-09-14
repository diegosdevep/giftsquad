import SwiftUI
import FirebaseFirestore

struct GroupsListView: View {
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }

    @State private var auth = AuthService.shared
    @State private var groups: [GiftGroup] = []
    @State private var isLoadingGroups = true
    @State private var isLoadingStats = true
    @State private var myItemsCount: Int = 0
    @State private var myReservationsCount: Int = 0
    @State private var listener: ListenerRegistration?
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var ownerNames: [String: String] = [:]

    @State private var groupRecentItems: [WishlistItem] = []
    @State private var isLoadingGroupRecentItems = true
    @State private var itemOwnerNames: [String: String] = [:]
    @State private var showAddItem = false
    @State private var showIntro = false
    @State private var showNotifications = false
    @State private var unreadNotificationsCount = 0
    @State private var notificationsListener: ListenerRegistration?

    var body: some View {
        GeometryReader { geo in
            let waveHeight = max(geo.size.height * 0.24, 170)

            ZStack(alignment: .top) {
                GSPalette.crema.ignoresSafeArea()

                GSTopWave()
                    .fill(
                        LinearGradient(
                            colors: [GSPalette.mandarina, GSPalette.durazno],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: waveHeight)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        greetingHeader
                            .padding(.top, max(waveHeight - 130, 8))

                        statsGrid

                        if isLoadingGroups {
                            VStack(alignment: .leading, spacing: 8) {
                                GSSectionLabel(title: "Mis grupos")
                                VStack(spacing: 12) {
                                    ForEach(0..<2, id: \.self) { _ in GSSkeletonCard() }
                                }
                            }
                        } else if groups.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                GSSectionLabel(title: "Mis grupos")
                                GSCard {
                                    VStack(spacing: 14) {
                                        Text("Todavía no estás en ningún grupo")
                                            .font(GSFont.body(15, weight: .semibold))
                                            .foregroundStyle(GSPalette.noche)
                                            .multilineTextAlignment(.center)
                                        Text("Creá uno para tu familia o amigos, o sumate con un código.")
                                            .font(GSFont.body(13))
                                            .foregroundStyle(GSPalette.grafito)
                                            .multilineTextAlignment(.center)
                                        GSPrimaryButton(title: "Crear grupo", isLoading: false, isEnabled: true) {
                                            showCreate = true
                                        }
                                        GSSwitchLink(title: "Sumarme con código") { showJoin = true }
                                    }
                                    .padding(24)
                                }
                            }
                        } else {
                            groupSection(title: "Mis grupos", groups: groups)
                        }

                        groupRecentItemsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 44, height: 44)
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showIntro = true
                } label: {
                    GSToolbarIcon(systemName: "info")
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        GSToolbarIcon(systemName: "bell.fill")
                        if unreadNotificationsCount > 0 {
                            Circle()
                                .fill(GSPalette.alerta)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Crear grupo", systemImage: "person.3.fill") { showCreate = true }
                    Button("Agregar a mi lista", systemImage: "gift.fill") { showAddItem = true }
                    Button("Sumarme con código", systemImage: "qrcode") { showJoin = true }
                } label: {
                    GSToolbarIcon(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                NotificationsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { showNotifications = false }
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupView()
        }
        .sheet(isPresented: $showJoin) {
            JoinGroupView()
        }
        .sheet(isPresented: $showAddItem) {
            AddWishlistItemView()
        }
        .sheet(isPresented: $showIntro) {
            NavigationStack {
                AppIntroView(onFinish: { showIntro = false })
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { showIntro = false }
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
            }
        }
        .navigationDestination(for: WishlistItem.self) { item in
            WishlistItemDetailView(item: item)
        }
        .navigationDestination(for: GiftGroup.self) { group in
            GroupDetailView(group: group)
        }
        .navigationDestination(for: GroupMemberRef.self) { ref in
            GroupMemberWishlistView(group: ref.group, member: ref.member)
        }
        .navigationDestination(for: MemberWishlistItem.self) { wrapped in
            WishlistItemDetailView(item: wrapped.item)
        }
        .onAppear {
            attachListener()
            Task { await loadStats() }
        }
        .onChange(of: auth.currentUserId) { oldValue, newValue in
            guard oldValue == nil, newValue != nil else { return }
            attachListener()
            Task { await loadStats() }
        }
        .refreshable { await refreshAll() }
        .onDisappear {
            listener?.remove()
            listener = nil
            notificationsListener?.remove()
            notificationsListener = nil
        }
    }

    private var firstName: String {
        let name = auth.appUser?.displayName ?? "Usuario"
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var greetingSubtitle: String {
        if groups.isEmpty { return "Armemos tu primer grupo" }
        if !groupRecentItems.isEmpty {
            return groupRecentItems.count == 1 ? "Hay 1 idea nueva en tus grupos" : "Hay \(groupRecentItems.count) ideas nuevas en tus grupos"
        }
        return "Todo tranquilo por acá"
    }

    private var greetingHeader: some View {
        Group {
            if auth.appUser == nil {
                VStack(alignment: .leading, spacing: 6) {
                    GSSkeleton(cornerRadius: 6).frame(width: 170, height: 22)
                    GSSkeleton(cornerRadius: 5).frame(width: 130, height: 13)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hola, \(firstName) 👋")
                        .font(GSFont.display(22))
                        .foregroundStyle(GSPalette.noche)
                    Text(greetingSubtitle)
                        .font(GSFont.body(13))
                        .foregroundStyle(GSPalette.grafito)
                }
            }
        }
    }

    private static let groupItemsGridColumns = [
        GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)
    ]

    private var groupRecentItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GSSectionLabel(title: "Nuevo en tus grupos")
            if isLoadingGroupRecentItems {
                LazyVGrid(columns: Self.groupItemsGridColumns, spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            GSSkeleton(cornerRadius: 14).frame(maxWidth: .infinity).frame(height: 130)
                            GSSkeleton().frame(width: 80, height: 10)
                            GSSkeleton().frame(width: 50, height: 10)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gsCardStyle()
                    }
                }
            } else if groupRecentItems.isEmpty {
                GSCard {
                    VStack(spacing: 6) {
                        Image(systemName: "gift")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(GSPalette.grafito.opacity(0.5))
                        Text("Todavía no hay nada nuevo en tus grupos")
                            .font(GSFont.body(13, weight: .semibold))
                            .foregroundStyle(GSPalette.noche)
                            .multilineTextAlignment(.center)
                        Text("Cuando alguien agregue un regalo a su lista, va a aparecer acá.")
                            .font(GSFont.caption(11))
                            .foregroundStyle(GSPalette.grafito)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            } else {
                LazyVGrid(columns: Self.groupItemsGridColumns, spacing: 14) {
                    ForEach(groupRecentItems) { item in
                        NavigationLink(value: item) {
                            HomeGroupItemCard(item: item, ownerName: itemOwnerNames[item.ownerId])
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func groupSection(title: String, groups: [GiftGroup]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GSSectionLabel(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(groups) { group in
                        NavigationLink(value: group) {
                            GroupCircleTile(
                                group: group,
                                displayTitle: groupDisplayTitle(for: group, among: groups),
                                ownerName: ownerNames[group.ownerId]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private func groupDisplayTitle(for group: GiftGroup, among groups: [GiftGroup]) -> String {
        guard group.ownerId != AuthService.shared.currentUserId else { return group.name }
        let hasCollision = groups.contains { $0.id != group.id && $0.name == group.name }
        guard hasCollision else { return group.name }
        let firstName = ownerNames[group.ownerId]?.split(separator: " ").first.map(String.init)
        return firstName.map { "\($0) · \(group.name)" } ?? group.name
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            if isLoadingGroups || isLoadingStats {
                ForEach(0..<3, id: \.self) { _ in statChipSkeleton }
            } else {
                statChip(icon: "person.3.fill", color: GSPalette.oceano, value: "\(groups.count)", label: groups.count == 1 ? "Grupo activo" : "Grupos activos")
                statChip(icon: "gift.fill", color: GSPalette.menta, value: "\(myItemsCount)", label: "En mi lista")
                Button {
                    selectedTab = 2
                } label: {
                    statChip(icon: "hand.raised.fill", color: GSPalette.durazno, value: "\(myReservationsCount)", label: myReservationsCount == 1 ? "Reserva activa" : "Reservas activas")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statChip(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(GSFont.display(19))
                .foregroundStyle(GSPalette.noche)
            Text(label)
                .font(GSFont.caption(10))
                .foregroundStyle(GSPalette.grafito)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .gsCardStyle(cornerRadius: 16)
    }

    private var statChipSkeleton: some View {
        VStack(spacing: 8) {
            GSSkeleton(cornerRadius: 9).frame(width: 30, height: 30)
            GSSkeleton(cornerRadius: 5).frame(width: 26, height: 17)
            GSSkeleton(cornerRadius: 4).frame(width: 50, height: 9)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .gsCardStyle(cornerRadius: 16)
    }

    private func attachListener() {
        guard let uid = AuthService.shared.currentUserId else { return }
        listener?.remove()
        listener = FirestoreService.shared.observeGroups(for: uid) { groups in
            self.groups = groups
            isLoadingGroups = false
            Task { await self.loadOwnerNames() }
            Task { await self.loadGroupRecentItems() }
        }
        notificationsListener?.remove()
        notificationsListener = FirestoreService.shared.observeUnreadNotificationsCount(uid: uid) { count in
            self.unreadNotificationsCount = count
        }
    }

    private func refreshAll() async {
        async let items: () = loadMyItemsCount()
        async let reservations: () = loadMyReservationsCount()
        async let owners: () = loadOwnerNames()
        async let groupRecent: () = loadGroupRecentItems()
        _ = await (items, reservations, owners, groupRecent)
    }

    private func loadOwnerNames() async {
        let uid = AuthService.shared.currentUserId
        let ownerIds = Set(groups.filter { $0.ownerId != uid }.map(\.ownerId))
        let missing = ownerIds.subtracting(ownerNames.keys)
        guard !missing.isEmpty else { return }
        for ownerId in missing {
            guard let snap = try? await FirestoreService.shared.user(ownerId).getDocument(),
                  let owner = try? snap.data(as: AppUser.self) else { continue }
            ownerNames[ownerId] = owner.displayName
        }
    }

    private func loadStats() async {
        async let items: () = loadMyItemsCount()
        async let reservations: () = loadMyReservationsCount()
        _ = await (items, reservations)
        isLoadingStats = false
    }

    private func loadMyItemsCount() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            let snap = try await FirestoreService.shared.items()
                .whereField("ownerId", isEqualTo: uid)
                .whereField("isArchived", isEqualTo: false)
                .count
                .getAggregation(source: .server)
            self.myItemsCount = Int(truncating: snap.count)
        } catch {
            Logger.shared.error("loadMyItemsCount: \(error)")
        }
    }

    private func loadMyReservationsCount() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            let snap = try await FirestoreService.shared.reservations()
                .whereField("reservedBy", isEqualTo: uid)
                .getDocuments()
            self.myReservationsCount = snap.documents
                .compactMap { try? $0.data(as: Reservation.self) }
                .filter { $0.status.isActive }
                .count
        } catch {
            Logger.shared.error("loadMyReservationsCount: \(error)")
        }
    }

    private func loadGroupRecentItems() async {
        defer { isLoadingGroupRecentItems = false }
        guard let uid = AuthService.shared.currentUserId else { return }
        let myGroupIds = Array(Set(groups.compactMap(\.id)).prefix(30))
        guard !myGroupIds.isEmpty else {
            self.groupRecentItems = []
            return
        }
        do {
            let snap = try await FirestoreService.shared.items()
                .whereField("groupIds", arrayContainsAny: myGroupIds)
                .whereField("isArchived", isEqualTo: false)
                .getDocuments()
            let myGroupIdSet = Set(myGroupIds)
            let candidates = snap.documents
                .compactMap { try? $0.data(as: WishlistItem.self) }
                .filter { $0.ownerId != uid }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(20)

            var result: [WishlistItem] = []
            for item in candidates {
                guard let itemId = item.id,
                      let sharedGroupId = item.groupIds.first(where: { myGroupIdSet.contains($0) }) else { continue }
                let active = try? await FirestoreService.shared.activeReservation(
                    itemId: itemId, groupId: sharedGroupId, viewerId: uid
                )
                if active == nil {
                    result.append(item)
                }
                if result.count == 5 { break }
            }
            self.groupRecentItems = result

            let missingOwnerIds = Set(groupRecentItems.map(\.ownerId)).subtracting(itemOwnerNames.keys)
            for ownerId in missingOwnerIds {
                guard let doc = try? await FirestoreService.shared.user(ownerId).getDocument(),
                      let owner = try? doc.data(as: AppUser.self) else { continue }
                itemOwnerNames[ownerId] = owner.displayName
            }
        } catch {
            Logger.shared.error("loadGroupRecentItems: \(error)")
        }
    }
}

private struct HomeGroupItemCard: View {
    let item: WishlistItem
    var ownerName: String?

    private var ownerFirstName: String? {
        guard let ownerName else { return nil }
        return ownerName.split(separator: " ").first.map(String.init) ?? ownerName
    }

    private var isNew: Bool {
        Calendar.current.isDate(item.createdAt, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var displayName: String {
        guard let first = item.name.first else { return item.name }
        return first.uppercased() + item.name.dropFirst()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GSPalette.grafito.opacity(0.08))
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        GSSkeleton(cornerRadius: 14)
                    default:
                        Image(systemName: "photo")
                            .foregroundStyle(GSPalette.grafito)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if isNew {
                    Text("Nuevo")
                        .font(GSFont.caption(9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(GSPalette.mandarina))
                        .padding(6)
                }
            }
            .frame(height: 130)

            Text(displayName)
                .font(GSFont.body(12, weight: .bold))
                .foregroundStyle(GSPalette.noche)
                .lineLimit(1)
                .truncationMode(.tail)

            PriorityBadge(priority: item.priority)

            HStack(spacing: 4) {
                if let ownerFirstName {
                    Text("de \(ownerFirstName)")
                        .font(GSFont.caption(10))
                        .foregroundStyle(GSPalette.grafito)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let price = item.price {
                    Text(price, format: .currency(code: item.currency))
                        .font(GSFont.body(12, weight: .bold))
                        .foregroundStyle(GSPalette.noche)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCardStyle()
    }
}

private struct GroupCircleTile: View {
    let group: GiftGroup
    let displayTitle: String
    var ownerName: String?

    private static let tints: [Color] = [
        GSPalette.oceano, GSPalette.mandarina, GSPalette.menta, GSPalette.durazno, GSPalette.alerta
    ]

    private var tint: Color {
        let key = group.id ?? group.name
        return Self.tints[abs(key.hashValue) % Self.tints.count]
    }
    private var metallicRing: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                tint.opacity(0.95),
                .white.opacity(0.95),
                tint.opacity(0.5),
                Color(white: 0.65),
                .white.opacity(0.9),
                tint.opacity(0.95)
            ]),
            center: .center,
            angle: .degrees(-45)
        )
    }
    private var isOwner: Bool { group.ownerId == AuthService.shared.currentUserId }
    private var ownerFirstName: String? {
        guard let ownerName else { return nil }
        return ownerName.split(separator: " ").first.map(String.init) ?? ownerName
    }
    private var roleText: String {
        if isOwner { return "Anfitrión" }
        return ownerFirstName.map { "de \($0)" } ?? "Miembro"
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(tint.opacity(0.20)).frame(width: 72, height: 72)
                Text(group.emoji ?? "🎁")
                    .font(.system(size: 30))
            }
            .overlay(Circle().strokeBorder(metallicRing, lineWidth: 2.5))
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.75).blur(radius: 0.5).padding(1.5))
            .shadow(color: tint.opacity(0.35), radius: 3, x: 0, y: 2)

            VStack(spacing: 2) {
                Text(displayTitle)
                    .font(GSFont.body(13, weight: .bold))
                    .foregroundStyle(GSPalette.noche)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(group.memberIds.count) · \(roleText)")
                    .font(GSFont.caption(9))
                    .foregroundStyle(GSPalette.grafito)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}

#Preview {
    NavigationStack { GroupsListView() }
}
