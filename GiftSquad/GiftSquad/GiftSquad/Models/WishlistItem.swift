import Foundation
import FirebaseFirestore
import SwiftUI

enum ItemPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, wantALot, high
    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Me gustaría"
        case .medium: return "Lo quiero"
        case .wantALot: return "Lo quiero mucho"
        case .high: return "¡Lo necesito!"
        }
    }

    var color: Color {
        switch self {
        case .low: return GSPalette.menta
        case .medium: return GSPalette.durazno
        case .wantALot: return GSPalette.mandarina
        case .high: return GSPalette.alerta
        }
    }
}

struct ItemVariant: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var label: String
    var note: String?
}

struct WishlistItem: Codable, Identifiable, Hashable {
    @DocumentID var id: String?

    var ownerId: String
    var groupIds: [String]

    var name: String
    var descriptionText: String?
    var imageURL: URL?
    var price: Double?
    var originalPrice: Double?
    var currency: String
    var link: URL?
    var additionalLinks: [URL]?
    var category: String?
    var priority: ItemPriority
    var variants: [ItemVariant]
    var alternatives: [String]

    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        ownerId: String,
        groupIds: [String] = [],
        name: String,
        descriptionText: String? = nil,
        imageURL: URL? = nil,
        price: Double? = nil,
        originalPrice: Double? = nil,
        currency: String = "ARS",
        link: URL? = nil,
        additionalLinks: [URL]? = nil,
        category: String? = nil,
        priority: ItemPriority = .medium,
        variants: [ItemVariant] = [],
        alternatives: [String] = [],
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.groupIds = groupIds
        self.name = name
        self.descriptionText = descriptionText
        self.imageURL = imageURL
        self.price = price
        self.originalPrice = originalPrice
        self.currency = currency
        self.link = link
        self.additionalLinks = additionalLinks
        self.category = category
        self.priority = priority
        self.variants = variants
        self.alternatives = alternatives
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var allLinks: [URL] {
        ([link].compactMap { $0 }) + (additionalLinks ?? [])
    }

    var discountPercent: Int? {
        guard let price, let originalPrice, originalPrice > price else { return nil }
        return Int(((originalPrice - price) / originalPrice * 100).rounded())
    }
}

/// Vive en /items/{itemId}/private/notes, no como campo del ítem, para que
/// solo el dueño pueda leerlas (ver firestore.rules).
struct ItemPrivateNotes: Codable {
    var text: String
}
