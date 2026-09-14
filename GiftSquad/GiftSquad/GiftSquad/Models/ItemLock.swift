import Foundation
import FirebaseFirestore

struct ItemLock: Codable, Identifiable {
    @DocumentID var id: String?
    var itemId: String
    var itemOwnerId: String
    var groupIds: [String]
    var kind: String
    var createdAt: Date
}
