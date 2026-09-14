import SwiftUI

struct RootView: View {
    @State private var auth = AuthService.shared

    var body: some View {
        Group {
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
        .animation(.default, value: auth.currentUserId)
        .animation(.default, value: auth.appUser?.hasCompletedGroupOnboarding)
        .preferredColorScheme(.light)
    }
}

#Preview {
    RootView()
}
