import Foundation
import FirebaseFirestore

enum ReservationStatus: String, Codable {
    case reserved
    case purchased
    case released

    var message: String {
        switch self {
        case .reserved: return "Reservado por alguien del grupo."
        case .purchased: return "Ya fue entregado."
        case .released: return "Disponible."
        }
    }

    var shortLabel: String {
        switch self {
        case .reserved: return "Reservado"
        case .purchased: return "Entregado"
        case .released: return "Liberado"
        }
    }

    var isActive: Bool { self != .released }
}

struct Reservation: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var itemId: String
    var itemOwnerId: String
    var groupId: String
    var reservedBy: String
    var status: ReservationStatus
    var reservedAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        itemId: String,
        itemOwnerId: String,
        groupId: String,
        reservedBy: String,
        status: ReservationStatus = .reserved,
        reservedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.itemOwnerId = itemOwnerId
        self.groupId = groupId
        self.reservedBy = reservedBy
        self.status = status
        self.reservedAt = reservedAt
        self.updatedAt = updatedAt
    }
}
