import SwiftUI
import UIKit
import LinkPresentation

/// Textos para compartir la app por WhatsApp, Mensajes, mail, etc.
/// El link de la App Store hace que WhatsApp muestre la vista previa con el logo de la app.
enum GSShare {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6815764999")!

    static func invitacionGrupo(nombre: String, codigo: String) -> String {
        [
            LanguageService.t("🎁 ¡Sumate a mi grupo \(nombre) en GiftSquad!"),
            LanguageService.t("Ahí armamos nuestras listas de deseos y coordinamos los regalos sin arruinar ninguna sorpresa."),
            "",
            LanguageService.t("1️⃣ Descargá la app: \(appStoreURL.absoluteString)"),
            LanguageService.t("2️⃣ Entrá a Grupos, tocá + y elegí \"Sumarme con código\"."),
            LanguageService.t("3️⃣ Ingresá el código: *\(codigo)*"),
        ].joined(separator: "\n")
    }

    static func codigoAmigo(_ codigo: String) -> String {
        [
            LanguageService.t("🎁 ¡Agregame en GiftSquad!"),
            LanguageService.t("Es la app que uso para armar listas de deseos y coordinar regalos con amigos y familia."),
            "",
            LanguageService.t("1️⃣ Descargá la app: \(appStoreURL.absoluteString)"),
            LanguageService.t("2️⃣ Con mi código de amigo me podés sumar a un grupo o a un Amigo Invisible: *\(codigo)*"),
        ].joined(separator: "\n")
    }
}

/// Contenido a compartir con el logo de la app en el encabezado del menú de compartir.
final class GSShareItem: NSObject, UIActivityItemSource {
    let text: String
    let title: String
    let subtitle: String

    init(text: String, title: String, subtitle: String) {
        self.text = text
        self.title = title
        self.subtitle = subtitle
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        // Se usa como segunda línea del encabezado.
        metadata.originalURL = URL(fileURLWithPath: subtitle)
        if let logo = UIImage(named: "AppLogo") {
            metadata.iconProvider = NSItemProvider(object: logo)
        }
        return metadata
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    init(items: [Any]) {
        self.items = items
    }

    init(text: String, title: String, subtitle: String) {
        self.items = [GSShareItem(text: text, title: title, subtitle: subtitle)]
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
