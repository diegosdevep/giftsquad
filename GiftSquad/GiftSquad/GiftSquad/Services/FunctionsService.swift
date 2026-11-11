import Foundation
import FirebaseFunctions

@MainActor
final class FunctionsService {
    static let shared = FunctionsService()
    private let functions: Functions

    private init() {
        self.functions = Functions.functions(region: "southamerica-east1")
    }

    func drawSecretSanta(eventId: String) async throws {
        _ = try await functions
            .httpsCallable("drawSecretSanta")
            .call(["eventId": eventId])
    }

    /// Devuelve el id del grupo al que se sumó el usuario. La búsqueda por código
    /// se hace en el servidor: un no-miembro no tiene permiso para leer grupos.
    func joinGroupByCode(_ inviteCode: String) async throws -> String {
        let result = try await functions
            .httpsCallable("joinGroupByCode")
            .call(["inviteCode": inviteCode])
        guard let data = result.data as? [String: Any],
              let groupId = data["groupId"] as? String else {
            throw AppError.firestore("Respuesta inesperada del servidor")
        }
        return groupId
    }

    func confirmDelivery(reservationId: String) async throws {
        _ = try await functions
            .httpsCallable("confirmDelivery")
            .call(["reservationId": reservationId])
    }

    func deleteAccount() async throws {
        _ = try await functions
            .httpsCallable("deleteAccount")
            .call()
    }
}
