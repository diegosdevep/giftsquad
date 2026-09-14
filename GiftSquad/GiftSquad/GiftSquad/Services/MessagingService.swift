import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UIKit
import UserNotifications
import FirebaseAuth

@MainActor
final class MessagingService: NSObject {
    static let shared = MessagingService()

    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            Logger.shared.error("Permiso de notificaciones rechazado: \(error)")
        }
    }

    private func persistToken(_ token: String) async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            try await FirestoreService.shared.user(uid).updateData([
                "fcmTokens": FieldValue.arrayUnion([token])
            ])
        } catch {
            Logger.shared.error("No se pudo guardar fcm token: \(error)")
        }
    }
}

extension MessagingService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor in
            await persistToken(token)
        }
    }
}

extension MessagingService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
