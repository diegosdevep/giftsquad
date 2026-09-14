import Foundation
import FirebaseFirestore

struct GiftGroup: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var emoji: String?
    var ownerId: String
    var memberIds: [String]
    var inviteCode: String
    var createdAt: Date

    init(
        id: String? = nil,
        name: String,
        emoji: String? = nil,
        ownerId: String,
        memberIds: [String] = [],
        inviteCode: String = Self.makeInviteCode(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }

    static func makeInviteCode(length: Int = 8) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
