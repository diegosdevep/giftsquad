import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var auth = AuthService.shared
    @State private var errorMessage: String?
    @State private var showEditUsername = false
    @State private var showShareCode = false

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
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(spacing: 10) {
                            avatarView
                            Text(auth.appUser?.displayName ?? auth.currentUser?.email ?? "Usuario")
                                .font(GSFont.display(20))
                                .foregroundStyle(GSPalette.noche)
                            if let email = auth.appUser?.email {
                                Text(email)
                                    .font(GSFont.caption(12))
                                    .foregroundStyle(GSPalette.grafito)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, waveHeight - 64)

                        VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Tu código GiftSquad")
                        GSCard {
                            Button {
                                showEditUsername = true
                            } label: {
                                GSRow(
                                    icon: "at",
                                    iconColor: GSPalette.oceano,
                                    title: "@\(auth.appUser?.username ?? "…")",
                                    subtitle: "Así te buscan por usuario"
                                )
                            }
                            .buttonStyle(.plain)
                            GSDivider()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Código de amigo")
                                        .font(GSFont.body(15, weight: .semibold))
                                        .foregroundStyle(GSPalette.noche)
                                    Text("Compartilo para que te agreguen a un grupo")
                                        .font(GSFont.caption(11))
                                        .foregroundStyle(GSPalette.grafito)
                                }
                                Spacer()
                                Text(auth.appUser?.friendCode ?? "········")
                                    .font(.system(.body, design: .monospaced).weight(.bold))
                                    .foregroundStyle(GSPalette.mandarina)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            GSDivider()
                            Button {
                                showShareCode = true
                            } label: {
                                GSRow(
                                    icon: "square.and.arrow.up",
                                    iconColor: GSPalette.durazno,
                                    title: "Compartir mi código",
                                    showChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Cuenta")
                        GSCard {
                            NavigationLink {
                                MyReservationsView()
                            } label: {
                                GSRow(icon: "hand.raised.fill", iconColor: GSPalette.durazno, title: "Mis reservas")
                            }
                            .buttonStyle(.plain)
                            GSDivider()
                            NavigationLink {
                                Text("Notificaciones (pendiente)")
                            } label: {
                                GSRow(icon: "bell.badge", iconColor: GSPalette.mandarina, title: "Preferencias de notificaciones")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Acerca de")
                        GSCard {
                            HStack {
                                Text("Versión")
                                    .font(GSFont.body(15, weight: .semibold))
                                    .foregroundStyle(GSPalette.noche)
                                Spacer()
                                Text(appVersion)
                                    .font(GSFont.body(14))
                                    .foregroundStyle(GSPalette.grafito)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            GSDivider()
                            Link(destination: URL(string: "https://github.com/")!) {
                                GSRow(icon: "doc.text", iconColor: GSPalette.grafito, title: "Documento de alcance")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    GSCard {
                        Button(role: .destructive) {
                            do {
                                try AuthService.shared.signOut()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } label: {
                            GSRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                iconColor: GSPalette.alerta,
                                title: "Cerrar sesión",
                                showChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text("GiftSquad")
                            .font(GSFont.body(12, weight: .bold))
                            .foregroundStyle(GSPalette.grafito)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                    if let errorMessage {
                        GSBanner(message: errorMessage, isError: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Perfil")
        .sheet(isPresented: $showEditUsername) {
            EditUsernameView()
        }
        .sheet(isPresented: $showShareCode) {
            if let code = auth.appUser?.friendCode {
                ShareSheet(items: ["Agregame en GiftSquad con mi código: \(code)"])
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(GSPalette.crema)
                .frame(width: 108, height: 108)
            if let url = auth.appUser?.photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarFallbackIcon
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            } else {
                avatarFallbackIcon
            }
        }
        .shadow(color: GSPalette.noche.opacity(0.16), radius: 10, y: 4)
    }

    private var avatarFallbackIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [GSPalette.menta, GSPalette.oceano],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
            Image(systemName: "person.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct EditUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = AuthService.shared.appUser?.username ?? ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GSPalette.crema.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Tu @usuario")
                            .font(GSFont.display(24))
                            .foregroundStyle(GSPalette.noche)
                        Text("Con esto te van a poder buscar para sumarte a un grupo.")
                            .font(GSFont.body(14))
                            .foregroundStyle(GSPalette.grafito)

                        GSCard {
                            GSUnderlineField(icon: "at") {
                                TextField("", text: $username, prompt: gsPlaceholder("usuario"))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding(16)
                        }

                        if let errorMessage {
                            GSBanner(message: errorMessage, isError: true)
                        }

                        GSPrimaryButton(
                            title: "Guardar",
                            isLoading: isSaving,
                            isEnabled: !isSaving && isValid
                        ) {
                            Task { await save() }
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(GSPalette.grafito)
                }
            }
        }
    }

    private var isValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 24
    }

    private func save() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await FirestoreService.shared.updateUsername(trimmed, for: uid)
            await AuthService.shared.refreshAppUser()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
}
