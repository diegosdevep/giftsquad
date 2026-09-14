import AuthenticationServices
import SwiftUI

struct SignInView: View {
    private enum LoadingProvider { case apple, google }

    @State private var loadingProvider: LoadingProvider?
    @State private var errorMessage: String?
    @State private var errorDismissTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let waveTopHeight = geo.size.height * 0.34
                let waveBottomHeight = geo.size.height * 0.24

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
                        .frame(height: waveTopHeight)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)

                    GSBottomWave()
                        .fill(
                            LinearGradient(
                                colors: [GSPalette.menta, GSPalette.oceano],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: waveBottomHeight)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            VStack(spacing: 10) {
                                Image("AppLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 132, height: 132)
                                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                                Text("GIFTSQUAD")
                                    .font(GSFont.caption(12))
                                    .tracking(2)
                                    .foregroundStyle(GSPalette.mandarina)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 4)

                            Text("Ingresá")
                                .font(GSFont.display(32))
                                .foregroundStyle(GSPalette.noche)

                            Text("Sin usuario ni contraseña — entrá con la cuenta que ya usás.")
                                .font(GSFont.body(14))
                                .foregroundStyle(GSPalette.grafito)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(GSFont.caption(13))
                                    .foregroundStyle(GSPalette.alerta)
                                    .transition(.opacity)
                            }

                            Spacer(minLength: 40)

                            VStack(spacing: 14) {
                                AppleSignInPillButton(isLoading: loadingProvider == .apple) {
                                    Task { await appleSignIn() }
                                }
                                .disabled(loadingProvider == .google)
                                GoogleSignInPillButton(isLoading: loadingProvider == .google) {
                                    Task { await googleSignIn() }
                                }
                                .disabled(loadingProvider == .apple)
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, waveTopHeight - 46)
                        .padding(.bottom, 24)
                    }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func showError(_ message: String) {
        errorDismissTask?.cancel()
        withAnimation { errorMessage = message }
        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { errorMessage = nil }
        }
    }

    private func googleSignIn() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            showError("No se pudo abrir Google Sign-In")
            return
        }
        loadingProvider = .google
        errorDismissTask?.cancel()
        errorMessage = nil
        defer { loadingProvider = nil }
        do {
            try await AuthService.shared.signInWithGoogle(presenting: root)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func appleSignIn() async {
        loadingProvider = .apple
        errorDismissTask?.cancel()
        errorMessage = nil
        defer { loadingProvider = nil }
        do {
            try await AuthService.shared.signInWithApple()
        } catch let error as ASAuthorizationError where error.code == .canceled {
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private struct AppleSignInPillButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                        Text("Continuar con Apple")
                            .font(GSFont.body(16, weight: .bold))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Color.black))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GoogleSignInPillButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            Group {
                if isLoading {
                    ProgressView().tint(GSPalette.noche)
                } else {
                    HStack(spacing: 10) {
                        Image("googlelogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Continuar con Google")
                            .font(GSFont.body(16, weight: .bold))
                            .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.20))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(GSPalette.grafito.opacity(0.25), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SignInView()
}
