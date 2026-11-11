import SwiftUI

struct RootView: View {
    @State private var auth = AuthService.shared
    @State private var minimoCumplido = false

    private var mostrandoSplash: Bool {
        !minimoCumplido || auth.isRestoringSession
    }

    var body: some View {
        ZStack {
            contenido

            if mostrandoSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.45), value: mostrandoSplash)
        .animation(.default, value: auth.currentUserId)
        .animation(.default, value: auth.appUser?.hasCompletedGroupOnboarding)
        .preferredColorScheme(.light)
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            minimoCumplido = true
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if auth.isAuthenticated {
            if auth.appUser?.hasCompletedGroupOnboarding == false {
                GroupOnboardingView()
            } else {
                MainTabView()
            }
        } else {
            SignInView()
        }
    }
}

#Preview {
    RootView()
}
