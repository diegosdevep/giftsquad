import Foundation
import FirebaseFirestore

struct GiftHistoryEntry: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var groupId: String
    var itemId: String
    var itemName: String
    var recipientId: String
    var amount: Double?
    var currency: String
    var occasion: String?
    var deliveredAt: Date
    var isRevealed: Bool

    init(
        id: String? = nil,
        groupId: String,
        itemId: String,
        itemName: String,
        recipientId: String,
        amount: Double? = nil,
        currency: String = "ARS",
        occasion: String? = nil,
        deliveredAt: Date = Date(),
        isRevealed: Bool = false
    ) {
        self.id = id
        self.groupId = groupId
        self.itemId = itemId
        self.itemName = itemName
        self.recipientId = recipientId
        self.amount = amount
        self.currency = currency
        self.occasion = occasion
        self.deliveredAt = deliveredAt
        self.isRevealed = isRevealed
    }
}
