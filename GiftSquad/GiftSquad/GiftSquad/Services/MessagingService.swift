import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UIKit
import UserNotifications
import FirebaseAuth

@MainActor
final class MessagingService: NSObject {
    static let shared = MessagingService()

    private static let pushKey = "gs.pushEnabled"

    /// Preferencia del usuario para este iPhone. Por defecto, activadas.
    var isPushEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.pushKey) as? Bool ?? true
    }

    /// true si el usuario bloqueó las notificaciones desde la configuración de iOS.
    func isBlockedBySystem() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// Activa o desactiva las notificaciones push en este iPhone.
    /// Devuelve cómo quedaron (pueden quedar apagadas si iOS las tiene bloqueadas).
    func setPushEnabled(_ enabled: Bool) async -> Bool {
        UserDefaults.standard.set(enabled, forKey: Self.pushKey)
        Messaging.messaging().isAutoInitEnabled = enabled

        if enabled {
            if await isBlockedBySystem() {
                UserDefaults.standard.set(false, forKey: Self.pushKey)
                return false
            }
            await requestAuthorizationAndRegister()
            if let token = try? await Messaging.messaging().token() {
                await persistToken(token)
            }
            return !(await isBlockedBySystem())
        } else {
            // Sin token guardado, el servidor ya no le manda push a este iPhone.
            if let token = try? await Messaging.messaging().token() {
                await removeToken(token)
            }
            try? await Messaging.messaging().deleteToken()
            return false
        }
    }

    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndRegister() async {
        guard isPushEnabled else { return }
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

    /// Guarda el token de este iPhone en el usuario logueado.
    func syncToken() async {
        guard isPushEnabled else { return }
        if let token = try? await Messaging.messaging().token() {
            await persistToken(token)
        }
    }

    /// Al cerrar sesión: este iPhone deja de recibir los avisos de esa cuenta.
    /// Se llama antes de salir, porque después ya no hay permiso para escribir en el usuario.
    func unregisterForSignOut() async {
        if let token = try? await Messaging.messaging().token() {
            await removeToken(token)
        }
    }

    private func persistToken(_ token: String) async {
        guard isPushEnabled, let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await FirestoreService.shared.user(uid).updateData([
                "fcmTokens": FieldValue.arrayUnion([token])
            ])
        } catch {
            Logger.shared.error("No se pudo guardar fcm token: \(error)")
        }
    }

    private func removeToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await FirestoreService.shared.user(uid).updateData([
                "fcmTokens": FieldValue.arrayRemove([token])
            ])
        } catch {
            Logger.shared.error("No se pudo borrar fcm token: \(error)")
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
