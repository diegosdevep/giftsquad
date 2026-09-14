import SwiftUI
import FirebaseAppCheck
import FirebaseCore
import GoogleSignIn

@main
struct GiftSquadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 300 * 1024 * 1024,
            directory: nil
        )
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    MessagingService.shared.configure()
                    await MessagingService.shared.requestAuthorizationAndRegister()
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
    }
}
