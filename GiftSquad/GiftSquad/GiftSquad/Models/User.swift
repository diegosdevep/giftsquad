import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var displayName: String
    var email: String
    var username: String
    var usernameLower: String
    var friendCode: String
    var photoURL: URL?
    var groupIds: [String]
    var createdAt: Date
    var hasCompletedGroupOnboarding: Bool?

    init(
        id: String? = nil,
        displayName: String,
        email: String,
        username: String,
        friendCode: String = Self.makeFriendCode(),
        photoURL: URL? = nil,
        groupIds: [String] = [],
        createdAt: Date = Date(),
        hasCompletedGroupOnboarding: Bool? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.username = username
        self.usernameLower = username.lowercased()
        self.friendCode = friendCode
        self.photoURL = photoURL
        self.groupIds = groupIds
        self.createdAt = createdAt
        self.hasCompletedGroupOnboarding = hasCompletedGroupOnboarding
    }

    static func makeFriendCode(length: Int = 8) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }

    static func makeUsername(from base: String) -> String {
        let cleaned = base
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let root = cleaned.isEmpty ? "usuario" : String(cleaned.prefix(20))
        let suffix = String(Int.random(in: 100...999))
        return "\(root)\(suffix)"
    }
}
