import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @AppStorage("gs_hasSeenAppIntro") private var hasSeenAppIntro = false
    @State private var showIntro = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                GroupsListView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Grupos", systemImage: "person.3.fill")
            }
            .tag(0)

            NavigationStack {
                MyWishlistView()
            }
            .tabItem {
                Label("Mi lista", systemImage: "gift.fill")
            }
            .tag(1)

            NavigationStack {
                ActiveEventsView()
            }
            .tabItem {
                Label("Reservas", systemImage: "hand.raised.fill")
            }
            .tag(2)

            NavigationStack {
                SecretSantaListView()
            }
            .tabItem {
                Label("A. Invisible", systemImage: "theatermasks.fill")
            }
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Perfil", systemImage: "person.crop.circle")
            }
            .tag(4)
        }
        .tint(GSPalette.mandarina)
        .toolbarBackground(GSPalette.crema, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .onAppear {
            if !hasSeenAppIntro { showIntro = true }
        }
        .sheet(isPresented: $showIntro) {
            AppIntroView(onFinish: {
                hasSeenAppIntro = true
                showIntro = false
            })
            .interactiveDismissDisabled()
        }
    }
}

#Preview {
    MainTabView()
}
