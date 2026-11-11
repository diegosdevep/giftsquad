import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var auth = AuthService.shared
    @State private var language = LanguageService.shared
    @State private var errorMessage: String?
    @State private var showEditUsername = false
    @State private var showShareCode = false
    @State private var showDeleteAccount = false
    @State private var isDeletingAccount = false

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
                                NotificationSettingsView()
                            } label: {
                                GSRow(icon: "bell.badge", iconColor: GSPalette.mandarina, title: "Preferencias de notificaciones")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GSSectionLabel(title: "Idioma")
                        GSCard {
                            ForEach(Array(GSLanguage.allCases.enumerated()), id: \.element.id) { indice, idioma in
                                if indice > 0 { GSDivider() }
                                Button {
                                    language.selection = idioma
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(idioma.flag).font(.system(size: 20))
                                        Text(idioma.displayName)
                                            .font(GSFont.body(15, weight: .semibold))
                                            .foregroundStyle(GSPalette.noche)
                                        Spacer()
                                        if language.selection == idioma {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(GSPalette.mandarina)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
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
                        }
                    }

                    GSCard {
                        Button(role: .destructive) {
                            Task {
                                await MessagingService.shared.unregisterForSignOut()
                                do {
                                    try AuthService.shared.signOut()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
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
                        GSDivider()
                        Button(role: .destructive) {
                            showDeleteAccount = true
                        } label: {
                            GSRow(
                                icon: "person.crop.circle.badge.xmark",
                                iconColor: GSPalette.alerta,
                                title: "Eliminar mi cuenta",
                                subtitle: "Borra tu cuenta y tus datos para siempre",
                                showChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeletingAccount)
                        .opacity(isDeletingAccount ? 0.5 : 1)
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
                        GSBanner(message: LocalizedStringKey(stringLiteral: errorMessage), isError: true)
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
        .gsConfirmDialog(
            isPresented: $showDeleteAccount,
            icon: "person.crop.circle.badge.xmark",
            title: "¿Eliminar tu cuenta?",
            message: "Se borran tu perfil, tu lista de deseos y tus reservas. Los grupos que creaste se eliminan para todos, pero nadie pierde sus productos: vuelven a su lista privada. No se puede deshacer.",
            confirmTitle: "Eliminar cuenta",
            onConfirm: { Task { await deleteAccount() } }
        )
        .gsErrorAlert(message: $errorMessage)
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await FunctionsService.shared.deleteAccount()
            // La cuenta de Auth ya no existe: el signOut local es solo para que
            // el listener dispare y la app vuelva al login sin esperar.
            try? AuthService.shared.signOut()
        } catch {
            errorMessage = error.localizedDescription
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
                            GSBanner(message: LocalizedStringKey(stringLiteral: errorMessage), isError: true)
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
