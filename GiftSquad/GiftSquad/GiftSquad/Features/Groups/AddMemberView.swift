import SwiftUI

struct AddMemberView: View {
    let group: GiftGroup
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var isSearching = false
    @State private var isAdding = false
    @State private var found: AppUser?
    @State private var searched = false
    @State private var errorMessage: String?
    @State private var addedName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Agregar amigo")
                            .font(GSFont.display(26))
                            .foregroundStyle(GSPalette.noche)
                        Text("Buscalo por @usuario, email o su código de amigo.")
                            .font(GSFont.body(14))
                            .foregroundStyle(GSPalette.grafito)

                        GSCard {
                            HStack(spacing: 12) {
                                GSUnderlineField(icon: "magnifyingglass") {
                                    TextField("", text: $query, prompt: gsPlaceholder("@usuario, email o código"))
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .onSubmit { Task { await search() } }
                                }
                                if isSearching {
                                    ProgressView().tint(GSPalette.oceano)
                                }
                            }
                            .padding(16)
                        }

                        GSPrimaryButton(
                            title: "Buscar",
                            isLoading: isSearching,
                            isEnabled: !isSearching && !query.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await search() }
                        }

                        if let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
                        }
                        if let addedName {
                            GSBanner(message: "Sumaste a \(addedName) al grupo.", isError: false)
                        }

                        if let found {
                            VStack(alignment: .leading, spacing: 8) {
                                GSSectionLabel(title: "Encontrado")
                                GSCard {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle().fill(GSPalette.oceano.opacity(0.12)).frame(width: 44, height: 44)
                                            if let photoURL = found.photoURL {
                                                AsyncImage(url: photoURL) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image.resizable().scaledToFill()
                                                    default:
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 18, weight: .semibold))
                                                            .foregroundStyle(GSPalette.oceano)
                                                    }
                                                }
                                                .frame(width: 44, height: 44)
                                                .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(GSPalette.oceano)
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(found.displayName)
                                                .font(GSFont.body(15, weight: .bold))
                                                .foregroundStyle(GSPalette.noche)
                                            Text("@\(found.username)")
                                                .font(GSFont.caption(12))
                                                .foregroundStyle(GSPalette.grafito)
                                        }
                                        Spacer()
                                        addButton
                                    }
                                    .padding(16)
                                }
                            }
                        } else if searched && !isSearching {
                            Text("No encontramos a nadie con ese dato.")
                                .font(GSFont.body(14))
                                .foregroundStyle(GSPalette.grafito)
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(GSPalette.grafito)
                }
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if let id = found?.id, group.memberIds.contains(id) {
            Text("Ya está")
                .font(GSFont.caption(11))
                .foregroundStyle(GSPalette.grafito)
        } else if found?.id == AuthService.shared.currentUserId {
            Text("Sos vos")
                .font(GSFont.caption(11))
                .foregroundStyle(GSPalette.grafito)
        } else {
            Button {
                Task { await add() }
            } label: {
                if isAdding {
                    ProgressView().tint(GSPalette.menta)
                } else {
                    Text("Agregar")
                        .font(GSFont.body(13, weight: .bold))
                        .foregroundStyle(GSPalette.menta)
                }
            }
            .buttonStyle(.plain)
            .disabled(isAdding)
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        addedName = nil
        found = nil
        defer {
            isSearching = false
            searched = true
        }
        do {
            found = try await FirestoreService.shared.findUser(matching: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add() async {
        guard let member = found, let groupId = group.id else { return }
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }
        do {
            try await FirestoreService.shared.addMember(member, toGroupId: groupId)
            addedName = member.displayName
            found = nil
            query = ""
            searched = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
