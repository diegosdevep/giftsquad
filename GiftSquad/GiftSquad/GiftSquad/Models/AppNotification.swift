import Foundation
import FirebaseFirestore

enum AppNotificationKind: String, Codable {
    case newWishlistItem
    case upcomingEvent
    case secretSantaDrawn
    case reservationFreed
    case generic
}

struct AppNotification: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var kind: AppNotificationKind
    var title: String
    var body: String
    var deepLink: String?
    var isRead: Bool
    var createdAt: Date

    init(
        id: String? = nil,
        userId: String,
        kind: AppNotificationKind,
        title: String,
        body: String,
        deepLink: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.kind = kind
        self.title = title
        self.body = body
        self.deepLink = deepLink
        self.isRead = isRead
        self.createdAt = createdAt
    }
}
