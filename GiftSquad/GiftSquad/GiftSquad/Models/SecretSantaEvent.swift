import Foundation
import FirebaseFirestore

enum SecretSantaStatus: String, Codable {
    case draft
    case drawn
    case completed
    case cancelled
}

struct ExclusionRule: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var fromUserId: String
    var toUserId: String
}

struct SecretSantaEvent: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var budget: Double?
    var currency: String
    var exchangeDate: Date?
    var participantIds: [String]
    var exclusions: [ExclusionRule]
    var status: SecretSantaStatus
    var createdBy: String
    var createdAt: Date
    var drawnAt: Date?

    init(
        id: String? = nil,
        name: String,
        description: String? = nil,
        budget: Double? = nil,
        currency: String = "ARS",
        exchangeDate: Date? = nil,
        participantIds: [String] = [],
        exclusions: [ExclusionRule] = [],
        status: SecretSantaStatus = .draft,
        createdBy: String,
        createdAt: Date = Date(),
        drawnAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.budget = budget
        self.currency = currency
        self.exchangeDate = exchangeDate
        self.participantIds = participantIds
        self.exclusions = exclusions
        self.status = status
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.drawnAt = drawnAt
    }
}

struct SharedGiftItem: Codable, Hashable, Identifiable {
    var itemId: String
    var name: String
    var price: Double?
    var currency: String
    var imageURL: URL?
    var id: String { itemId }
}

struct SecretSantaAssignment: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var giverId: String
    var recipientId: String
    var revealedAt: Date?

    init(
        id: String? = nil,
        giverId: String,
        recipientId: String,
        revealedAt: Date? = nil
    ) {
        self.id = id
        self.giverId = giverId
        self.recipientId = recipientId
        self.revealedAt = revealedAt
    }
}
