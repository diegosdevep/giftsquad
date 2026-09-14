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

    func confirmDelivery(reservationId: String) async throws {
        _ = try await functions
            .httpsCallable("confirmDelivery")
            .call(["reservationId": reservationId])
    }
}
