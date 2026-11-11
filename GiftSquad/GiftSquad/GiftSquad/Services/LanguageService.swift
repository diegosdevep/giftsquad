import Foundation
import FirebaseFirestore
import SwiftUI

enum GSLanguage: String, CaseIterable, Identifiable {
    case system
    case es
    case en

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: return "Idioma del sistema"
        case .es: return "Español"
        case .en: return "Inglés"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .es: return "🇦🇷"
        case .en: return "🇬🇧"
        }
    }
}

@MainActor
@Observable
final class LanguageService {
    static let shared = LanguageService()

    private static let key = "gs.language"

    var selection: GSLanguage {
        didSet {
            persist()
            Task { await publicarIdioma() }
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key) ?? ""
        selection = GSLanguage(rawValue: stored) ?? .system
    }

    
    var locale: Locale {
        switch selection {
        case .system: return Self.systemLocale
        case .es: return Locale(identifier: "es")
        case .en: return Locale(identifier: "en")
        }
    }

    private static var systemLocale: Locale {
        let code = Locale.preferredLanguages.first ?? "es"
        return code.lowercased().hasPrefix("en") ? Locale(identifier: "en") : Locale(identifier: "es")
    }

    
    var effectiveCode: String {
        locale.language.languageCode?.identifier ?? "es"
    }

    private func persist() {
        UserDefaults.standard.set(selection.rawValue, forKey: Self.key)
    }

    func publicarIdioma() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        do {
            try await Firestore.firestore().collection("users").document(uid)
                .setData(["language": effectiveCode], merge: true)
        } catch {
            Logger.shared.error("publicarIdioma: \(error)")
        }
    }
}

extension LanguageService {
    static func t(_ clave: String.LocalizationValue) -> String {
        String(localized: clave, locale: shared.locale)
    }
}
