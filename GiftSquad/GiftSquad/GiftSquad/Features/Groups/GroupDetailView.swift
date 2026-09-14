import SwiftUI
import FirebaseFirestore

struct GroupMemberRef: Hashable {
    let group: GiftGroup
    let member: AppUser
}

struct GroupDetailView: View {
    @State private var group: GiftGroup
    @State private var members: [AppUser] = []
    @State private var isLoadingMembers = true
    @State private var selectedMember: AppUser?
    @State private var showShare = false
    @State private var showAddMember = false
    @State private var showEditGroup = false
    @State private var showDeleteConfirm = false
    @State private var showLeaveConfirm = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(group: GiftGroup) {
        _group = State(initialValue: group)
    }

    private var isOwner: Bool { group.ownerId == AuthService.shared.currentUserId }
    private var memberLabel: String {
        group.memberIds.count == 1 ? "1 miembro" : "\(group.memberIds.count) miembros"
    }
    private var ownerName: String? {
        members.first(where: { $0.id == group.ownerId })?.displayName
    }

    var body: some View {
        GeometryReader { geo in
            let waveHeight = max(geo.size.height * 0.22, 150)

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
                    VStack(alignment: .leading, spacing: 22) {
                        heroHeader(waveHeight: waveHeight)

                        VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Miembros")
                        if isLoadingMembers {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(0..<6, id: \.self) { _ in
                                        VStack(spacing: 8) {
                                            GSSkeleton(cornerRadius: 32).frame(width: 64, height: 64)
                                            GSSkeleton().frame(width: 44, height: 10)
                                        }
                                    }
                                }
                                .padding(.trailing, 4)
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                                        let isMe = member.id == AuthService.shared.currentUserId
                                        let isHost = member.id == group.ownerId
                                        if isMe {
                                            GroupMemberTile(member: member, isMe: true, isHost: isHost)
                                        } else {
                                            NavigationLink(value: GroupMemberRef(group: group, member: member)) {
                                                GroupMemberTile(member: member, isMe: false, isHost: isHost)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.trailing, 4)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Eventos")
                        GSCard {
                            NavigationLink {
                                HistoryView(group: group)
                            } label: {
                                GSRow(icon: "clock.arrow.circlepath", iconColor: GSPalette.grafito, title: "Historial")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Invitar")
                        GSCard {
                            HStack {
                                Text("Código")
                                    .font(GSFont.body(15, weight: .semibold))
                                    .foregroundStyle(GSPalette.noche)
                                Spacer()
                                Text(group.inviteCode)
                                    .font(.system(.body, design: .monospaced).weight(.bold))
                                    .foregroundStyle(GSPalette.oceano)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            GSDivider()
                            Button {
                                showShare = true
                            } label: {
                                GSRow(
                                    icon: "square.and.arrow.up",
                                    iconColor: GSPalette.durazno,
                                    title: "Compartir invitación",
                                    showChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                            if isOwner {
                                GSDivider()
                                Button {
                                    showAddMember = true
                                } label: {
                                    GSRow(
                                        icon: "person.badge.plus",
                                        iconColor: GSPalette.menta,
                                        title: "Agregar amigo",
                                        showChevron: false
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isOwner {
                    Menu {
                        Button("Editar", systemImage: "pencil") { showEditGroup = true }
                        Button("Eliminar grupo", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(GSPalette.mandarina)
                    }
                    .disabled(isWorking)
                } else {
                    Button {
                        showLeaveConfirm = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(GSPalette.alerta)
                    }
                    .disabled(isWorking)
                }
            }
        }
        .task { await loadMembers() }
        .refreshable { await loadMembers() }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: ["Sumate a \(group.name) en GiftSquad con el código \(group.inviteCode)"])
        }
        .sheet(isPresented: $showAddMember, onDismiss: { Task { await loadMembers() } }) {
            AddMemberView(group: group)
        }
        .sheet(isPresented: $showEditGroup) {
            EditGroupView(group: group) { updated in
                group = updated
            }
        }
        .gsConfirmDialog(
            isPresented: $showDeleteConfirm,
            icon: "trash.fill",
            title: "¿Eliminar \(group.name)?",
            message: "Se va a borrar para todos los miembros. Los ítems y eventos que tenía no se recuperan. No se puede deshacer.",
            confirmTitle: "Eliminar",
            onConfirm: { Task { await performDelete() } }
        )
        .gsConfirmDialog(
            isPresented: $showLeaveConfirm,
            icon: "rectangle.portrait.and.arrow.right",
            title: "¿Salir de \(group.name)?",
            message: "Vas a dejar de ver este grupo y su lista. Podés volver a sumarte con el código de invitación.",
            confirmTitle: "Salir",
            onConfirm: { Task { await performLeave() } }
        )
        .gsErrorAlert(message: $errorMessage)
    }

    private func performDelete() async {
        guard let id = group.id else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await FirestoreService.shared.deleteGroup(id, ownerId: group.ownerId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performLeave() async {
        guard let id = group.id, let uid = AuthService.shared.currentUserId else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await FirestoreService.shared.leaveGroup(id, userId: uid)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func heroHeader(waveHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 92, height: 92)
                Circle()
                    .fill(GSPalette.crema)
                    .frame(width: 80, height: 80)
                Text(group.emoji ?? "🎁")
                    .font(.system(size: 38))
            }
            .shadow(color: GSPalette.noche.opacity(0.14), radius: 10, y: 4)

            Text(group.name)
                .font(GSFont.display(24))
                .foregroundStyle(GSPalette.noche)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: isOwner ? "crown.fill" : "person.2.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(isOwner ? "Anfitrión" : (ownerName.map { "de \($0)" } ?? "Miembro"))
                    .font(GSFont.caption(12))
                Text("· \(memberLabel)")
                    .font(GSFont.caption(12))
                    .foregroundStyle(GSPalette.grafito)
            }
            .foregroundStyle(isOwner ? GSPalette.mandarina : GSPalette.oceano)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill((isOwner ? GSPalette.mandarina : GSPalette.oceano).opacity(0.12))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, waveHeight - 70)
    }

    private func loadMembers() async {
        guard let id = group.id else {
            isLoadingMembers = false
            return
        }
        defer { isLoadingMembers = false }
        do {
            let doc = try await FirestoreService.shared.group(id).getDocument()
            if let fresh = try? doc.data(as: GiftGroup.self) {
                self.group = fresh
            }
        } catch {
            Logger.shared.error("loadMembers refresh group: \(error)")
        }
        guard !group.memberIds.isEmpty else { return }
        do {
            let snap = try await FirestoreService.shared.users()
                .whereField(FieldPath.documentID(), in: group.memberIds)
                .getDocuments()
            let uid = AuthService.shared.currentUserId
            self.members = snap.documents
                .compactMap { try? $0.data(as: AppUser.self) }
                .sorted { ($0.id == uid ? 0 : 1) < ($1.id == uid ? 0 : 1) }
        } catch {
            Logger.shared.error("loadMembers: \(error)")
        }
    }
}

private struct GroupMemberTile: View {
    let member: AppUser
    let isMe: Bool
    let isHost: Bool

    private var firstName: String {
        member.displayName.split(separator: " ").first.map(String.init) ?? member.displayName
    }

    private var ringColor: Color? {
        if isHost { return GSPalette.mandarina }
        if isMe { return GSPalette.oceano }
        return nil
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(GSPalette.grafito.opacity(0.12)).frame(width: 64, height: 64)
                if let url = member.photoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            fallbackIcon
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                } else {
                    fallbackIcon
                }
            }
            .overlay(
                Circle().strokeBorder(ringColor ?? .clear, lineWidth: ringColor != nil ? 3 : 0)
            )
            .overlay(alignment: .bottomTrailing) {
                if isHost {
                    ZStack {
                        Circle().fill(GSPalette.mandarina).frame(width: 20, height: 20)
                        Circle().strokeBorder(GSPalette.crema, lineWidth: 2).frame(width: 20, height: 20)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 3, y: 3)
                }
            }

            Text(isMe ? "Vos" : firstName)
                .font(GSFont.body(12, weight: .bold))
                .foregroundStyle(GSPalette.noche)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(GSPalette.grafito)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
