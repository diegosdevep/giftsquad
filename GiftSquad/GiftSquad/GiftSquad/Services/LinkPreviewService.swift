import Foundation

struct LinkPreview {
    var url: URL
    var title: String?
    var description: String?
    var imageURL: URL?
    var price: Double?
    var originalPrice: Double?
    var currency: String?
    var category: String?
}

@MainActor
final class LinkPreviewService {
    static let shared = LinkPreviewService()

    private static let browserUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    
    private static func acceptLanguage(for url: URL) -> String {
        let byTLD: [(suffix: String, language: String)] = [
            (".co.uk", "en-GB,en"), (".com.br", "pt-BR,pt"), (".co.jp", "ja-JP,ja"),
            (".com.mx", "es-MX,es"), (".com.ar", "es-AR,es"), (".com.au", "en-AU,en"),
            (".com.tr", "tr-TR,tr"), (".com.be", "fr-BE,nl-BE"), (".com.co", "es-CO,es"),
            (".de", "de-DE,de"), (".es", "es-ES,es"), (".fr", "fr-FR,fr"),
            (".it", "it-IT,it"), (".nl", "nl-NL,nl"), (".dk", "da-DK,da"),
            (".se", "sv-SE,sv"), (".pl", "pl-PL,pl"), (".no", "nb-NO,nb"),
            (".ch", "de-CH,de"), (".at", "de-AT,de"), (".ie", "en-IE,en"),
            (".pt", "pt-PT,pt"), (".cl", "es-CL,es"), (".in", "en-IN,en")
        ]
        guard let host = url.host?.lowercased() else { return "en-US,en;q=0.9" }
        
        for entry in byTLD.sorted(by: { $0.suffix.count > $1.suffix.count })
        where host.hasSuffix(entry.suffix) {
            return "\(entry.language);q=0.9,en;q=0.8"
        }
        return "en-US,en;q=0.9"
    }

    private static func esAmazon(_ url: URL?) -> Bool {
        url?.host?.lowercased().contains("amazon.") ?? false
    }

    
    private static func descargar(_ url: URL, marketplace: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(Self.acceptLanguage(for: marketplace), forHTTPHeaderField: "Accept-Language")
        
        if Self.esAmazon(marketplace), let currency = Self.currencyFromHost(marketplace) {
            request.httpShouldHandleCookies = false
            request.setValue("i18n-prefs=\(currency)", forHTTPHeaderField: "Cookie")
        }
        return try await URLSession.shared.data(for: request)
    }

    func fetch(_ url: URL) async throws -> LinkPreview {
        var (data, response) = try await Self.descargar(url, marketplace: url)
        var resolvedURL = response.url ?? url

        
        if Self.esAmazon(resolvedURL), !Self.esAmazon(url) {
            (data, response) = try await Self.descargar(resolvedURL, marketplace: resolvedURL)
            resolvedURL = response.url ?? resolvedURL
        }

        guard let html = String(data: data, encoding: .utf8) else {
            return LinkPreview(url: url)
        }

        let product = Self.extractJSONLDProduct(html)
        let offer: (price: Double?, currency: String?) = product.map { Self.offerFields(from: $0) } ?? (nil, nil)
        let jsonImage = product.flatMap { Self.imageURLString(from: $0) }

        let isAmazon = resolvedURL.host?.contains("amazon.") ?? false
        let amazonImage = isAmazon ? Self.extractAmazonImage(html) : nil
        let amazonPrice: (price: Double?, currency: String?) = isAmazon ? Self.extractAmazonPrice(html) : (nil, nil)
        let amazonOriginalPrice: Double? = isAmazon ? Self.extractAmazonOriginalPrice(html) : nil
        let amazonCategory = isAmazon ? Self.extractAmazonBreadcrumbCategory(html) : nil
        let amazonDescription = isAmazon ? Self.extractAmazonFirstBullet(html) : nil

        let isMercadoLibre = (resolvedURL.host?.contains("mercadolibre.") ?? false)
            || (resolvedURL.host?.contains("mercadolivre.") ?? false)
        let mercadoLibreOriginalPrice: Double? = isMercadoLibre
            ? Self.extractMercadoLibreOriginalPrice(html)
            : nil

        let rawTitle = (product?["name"] as? String)
            ?? Self.extractMeta(html, property: "og:title")
            ?? Self.extractTitleTag(html)
        let rawDescription = (product?["description"] as? String)
            ?? Self.extractMeta(html, property: "og:description")
            ?? amazonDescription
        let rawCategory = (product?["category"] as? String) ?? amazonCategory

        let price = offer.price
            ?? Self.extractMeta(html, property: "product:price:amount").flatMap(Self.parseDecimal)
            ?? amazonPrice.price
        
        let listPrice = amazonOriginalPrice ?? mercadoLibreOriginalPrice
        let originalPrice = listPrice.flatMap { list in
            guard let price, list > price else { return nil as Double? }
            return list
        }

        return LinkPreview(
            url: url,
            title: rawTitle.map { Self.cleanTitle(Self.decodeHTMLEntities($0)) },
            description: rawDescription.map(Self.decodeHTMLEntities),
            imageURL: (jsonImage ?? Self.extractMeta(html, property: "og:image") ?? amazonImage)
                .flatMap { Self.absoluteURL($0, relativeTo: resolvedURL) },
            price: price,
            originalPrice: originalPrice,
            currency: offer.currency
                ?? Self.extractMeta(html, property: "product:price:currency")
                ?? amazonPrice.currency
                ?? Self.currencyFromHost(resolvedURL),
            category: rawCategory.map(Self.decodeHTMLEntities)
        )
    }

    private static func decodeHTMLEntities(_ raw: String) -> String {
        let named: [(String, String)] = [
            ("&amp;", "&"), ("&quot;", "\""), ("&#34;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&euro;", "€"),
            ("&mdash;", "—"), ("&ndash;", "–"),
            ("&rsquo;", "\u{2019}"), ("&lsquo;", "\u{2018}"),
            ("&rdquo;", "\u{201D}"), ("&ldquo;", "\u{201C}")
        ]
        var result = raw
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        guard let regex = try? NSRegularExpression(pattern: "&#x?([0-9A-Fa-f]+);", options: .caseInsensitive) else {
            return result
        }
        let ns = result as NSString
        var output = ""
        var lastEnd = 0
        for match in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
            output += ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            let whole = ns.substring(with: match.range)
            let numStr = ns.substring(with: match.range(at: 1))
            let isHex = whole.lowercased().contains("#x")
            if let code = UInt32(numStr, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                output.append(Character(scalar))
            }
            lastEnd = match.range.location + match.range.length
        }
        output += ns.substring(from: lastEnd)
        return output
    }

    private static func cleanTitle(_ raw: String) -> String {
        var title = raw
        for separator in [" : Amazon", " | Amazon", " - Amazon"] {
            if let range = title.range(of: separator, options: .caseInsensitive) {
                title = String(title[..<range.lowerBound])
            }
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractAmazonBreadcrumbCategory(_ html: String) -> String? {
        guard let idx = html.range(of: "id=\"wayfinding-breadcrumbs_feature_div\"") else { return nil }
        let tail = html[idx.upperBound...]
        guard let closeRange = tail.range(of: "</ul>") else { return nil }
        let snippet = tail[..<closeRange.lowerBound]
        guard let regex = try? NSRegularExpression(
            pattern: #"class="a-link-normal a-color-tertiary"[^>]*>([^<]+)</a>"#
        ) else { return nil }
        let nsSnippet = String(snippet)
        let range = NSRange(nsSnippet.startIndex..., in: nsSnippet)
        let matches = regex.matches(in: nsSnippet, range: range)
        guard let last = matches.last, let r = Range(last.range(at: 1), in: nsSnippet) else { return nil }
        return String(nsSnippet[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractAmazonFirstBullet(_ html: String) -> String? {
        guard let idx = html.range(of: "id=\"feature-bullets\"") else { return nil }
        let tail = html[idx.upperBound...]
        guard let regex = try? NSRegularExpression(
            pattern: #"class="a-list-item">\s*([^<]{6,400}?)\s*</span>"#
        ) else { return nil }
        let nsTail = String(tail.prefix(4000))
        let range = NSRange(nsTail.startIndex..., in: nsTail)
        guard let match = regex.firstMatch(in: nsTail, range: range),
              let r = Range(match.range(at: 1), in: nsTail) else { return nil }
        return String(nsTail[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractAmazonImage(_ html: String) -> String? {
        guard let markerRange = html.range(of: "id=\"landingImage\"") else { return nil }
        let tail = html[markerRange.upperBound...]
        guard let attrRange = tail.range(of: "data-a-dynamic-image=\"") else { return nil }
        let afterAttr = tail[attrRange.upperBound...]
        guard let endQuote = afterAttr.firstIndex(of: "\"") else { return nil }
        let raw = String(afterAttr[..<endQuote])
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [Int]],
              !dict.isEmpty else { return nil }
        return dict.max(by: { ($0.value.first ?? 0) < ($1.value.first ?? 0) })?.key
    }

    
    private static func amazonBuyBoxWindow(_ html: String) -> String {
        let anchors = [
            "corePrice_feature_div",
            "corePrice_desktop",
            "corePriceDisplay_desktop_feature_div",
            "apex_desktop"
        ]
        for anchor in anchors {
            guard let anchorRange = html.range(of: "id=\"\(anchor)\"") else { continue }
            let end = html.index(anchorRange.upperBound, offsetBy: 8000, limitedBy: html.endIndex)
                ?? html.endIndex
            return String(html[anchorRange.upperBound..<end])
        }
        return html
    }

    
    private static func firstAmazonOffscreenNumber(in text: String, regex: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[r])
            if candidate.contains(where: \.isNumber) {
                return candidate
            }
        }
        return nil
    }

    
    private static func amazonBuyBoxJSON(_ html: String) -> String? {
        guard let anchor = html.range(of: "twister-plus-buying-options-price-data") else { return nil }
        let end = html.index(anchor.upperBound, offsetBy: 3000, limitedBy: html.endIndex) ?? html.endIndex
        return String(html[anchor.upperBound..<end])
    }

    private static func firstCapture(_ text: String, _ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func extractAmazonPrice(_ html: String) -> (price: Double?, currency: String?) {
        
        if let blob = Self.amazonBuyBoxJSON(html),
           let amount = Self.firstCapture(blob, #""priceAmount"\s*:\s*([0-9.]+)"#).flatMap(Double.init) {
        
            let currency = Self.firstCapture(blob, #""currencySymbol"\s*:\s*"([^"]+)""#)
                .flatMap { Self.currencyCode(in: Self.decodeHTMLEntities($0)) }
            return (amount, currency)
        }
        guard let regex = try? NSRegularExpression(pattern: #"class="a-offscreen">([^<]+)<"#) else {
            return (nil, nil)
        }
        let window = Self.amazonBuyBoxWindow(html)
        guard let text = Self.firstAmazonOffscreenNumber(in: window, regex: regex) else { return (nil, nil) }
        return Self.parseAmazonPriceString(text)
    }

    
    private static func extractAmazonOriginalPrice(_ html: String) -> Double? {
        guard let anchor = html.range(of: "apex-basisprice-value") else { return nil }
        let end = html.index(anchor.upperBound, offsetBy: 400, limitedBy: html.endIndex) ?? html.endIndex
        let window = String(html[anchor.upperBound..<end])
        guard let regex = try? NSRegularExpression(pattern: #"class="a-offscreen">([^<]+)<"#),
              let text = Self.firstAmazonOffscreenNumber(in: window, regex: regex) else { return nil }
        return Self.parseAmazonPriceString(text).price
    }

    private static func currencyCode(in raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count == 3, trimmed.allSatisfy(\.isLetter) {
            return trimmed.uppercased()
        }
        let bySymbol: [(String, String)] = [
            ("€", "EUR"), ("£", "GBP"), ("zł", "PLN"), ("₺", "TRY"),
            ("₹", "INR"), ("¥", "JPY"), ("R$", "BRL"), ("$", "USD")
        ]
        for (symbol, code) in bySymbol where trimmed.contains(symbol) {
            return code
        }
        let upper = trimmed.uppercased()
        for code in ["EUR", "USD", "GBP", "DKK", "SEK", "NOK", "PLN", "CHF"]
        where upper.contains(code) {
            return code
        }
        
        return nil
    }


    private static func parseDecimal(_ numeric: String) -> Double? {
        let hasComma = numeric.contains(",")
        let hasDot = numeric.contains(".")
        var s = numeric
        if hasComma, hasDot {
            let decimalIsComma = numeric.lastIndex(of: ",")! > numeric.lastIndex(of: ".")!
            s = s.replacingOccurrences(of: decimalIsComma ? "." : ",", with: "")
            s = s.replacingOccurrences(of: decimalIsComma ? "," : ".", with: ".")
        } else if hasComma || hasDot {
            let separator = hasComma ? "," : "."
            let parts = s.components(separatedBy: separator)
            if parts.count > 2 || parts.last?.count == 3 {
                s = s.replacingOccurrences(of: separator, with: "")
            } else {
                s = s.replacingOccurrences(of: separator, with: ".")
            }
        }
        return Double(s)
    }

    private static func parseAmazonPriceString(_ rawText: String) -> (price: Double?, currency: String?) {
        let raw = Self.decodeHTMLEntities(rawText).trimmingCharacters(in: .whitespacesAndNewlines)
        let numeric = raw.filter { $0.isNumber || $0 == "," || $0 == "." }
        return (Self.parseDecimal(numeric), Self.currencyCode(in: raw))
    }

    private static func currencyFromHost(_ url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let byTLD: [String: String] = [
            "amazon.es": "EUR", "amazon.de": "EUR", "amazon.fr": "EUR",
            "amazon.it": "EUR", "amazon.nl": "EUR", "amazon.com.be": "EUR",
            "amazon.ie": "EUR",
            "amazon.se": "SEK", "amazon.pl": "PLN", "amazon.dk": "DKK",
            "amazon.com": "USD", "amazon.ca": "CAD",
            "amazon.co.uk": "GBP",
            "amazon.com.mx": "MXN", "amazon.com.br": "BRL",
            "amazon.co.jp": "JPY", "amazon.in": "INR",
            "amazon.com.au": "AUD", "amazon.com.tr": "TRY",
            "amazon.ae": "AED", "amazon.sa": "SAR", "amazon.eg": "EGP",
            "amazon.sg": "SGD",
            "mercadolibre.com.ar": "ARS", "mercadolibre.com.mx": "MXN",
            "mercadolibre.com.co": "COP", "mercadolibre.cl": "CLP",
            "mercadolibre.com.pe": "PEN", "mercadolibre.com.uy": "UYU",
            "mercadolibre.com.ec": "USD", "mercadolibre.com.bo": "BOB",
            "mercadolibre.com.py": "PYG", "mercadolibre.com.ve": "VES",
            "mercadolivre.com.br": "BRL"
        ]
        for (domain, currency) in byTLD where host.hasSuffix(domain) {
            return currency
        }
        return nil
    }

    private static func extractMercadoLibreOriginalPrice(_ html: String) -> Double? {
        guard let regex = try? NSRegularExpression(
            pattern: #"andes-money-amount--previous[\s\S]{0,300}?andes-money-amount__fraction">([0-9.,]+)<"#
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        let digits = html[r].filter(\.isNumber)
        return digits.isEmpty ? nil : Double(digits)
    }

    private static func absoluteURL(_ raw: String, relativeTo base: URL) -> URL? {
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: raw, relativeTo: base)?.absoluteURL
    }

    private static func extractJSONLDProduct(_ html: String) -> [String: Any]? {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard let r = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonString.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let product = findProduct(in: obj) { return product }
        }
        return nil
    }

    private static func findProduct(in obj: Any) -> [String: Any]? {
        if let dict = obj as? [String: Any] {
            if let type = dict["@type"] as? String, type.lowercased() == "product" {
                return dict
            }
            if let types = dict["@type"] as? [String],
               types.contains(where: { $0.lowercased() == "product" }) {
                return dict
            }
            if let graph = dict["@graph"] as? [Any] {
                for item in graph {
                    if let found = findProduct(in: item) { return found }
                }
            }
            return nil
        }
        if let array = obj as? [Any] {
            for item in array {
                if let found = findProduct(in: item) { return found }
            }
        }
        return nil
    }

    private static func imageURLString(from product: [String: Any]) -> String? {
        if let img = product["image"] as? String { return img }
        if let imgs = product["image"] as? [String] { return imgs.first }
        if let imgObj = product["image"] as? [String: Any] { return imgObj["url"] as? String }
        if let imgArr = product["image"] as? [Any] {
            for item in imgArr {
                if let s = item as? String { return s }
                if let d = item as? [String: Any], let u = d["url"] as? String { return u }
            }
        }
        return nil
    }

    private static func offerFields(from product: [String: Any]) -> (price: Double?, currency: String?) {
        var offer: [String: Any]?
        if let o = product["offers"] as? [String: Any] {
            offer = o
        } else if let arr = product["offers"] as? [Any], let first = arr.first as? [String: Any] {
            offer = first
        }
        guard let offer else { return (nil, nil) }
        let price: Double?
        switch offer["price"] {
        case let n as NSNumber: price = n.doubleValue
        case let s as String: price = Self.parseDecimal(s)
        default: price = nil
        }
        return (price, offer["priceCurrency"] as? String)
    }

    private static func extractMeta(_ html: String, property: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            #"<meta[^>]+property=["']\#(escaped)["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']\#(escaped)["']"#,
            #"<meta[^>]+name=["']\#(escaped)["'][^>]+content=["']([^"']+)["']"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let r = Range(match.range(at: 1), in: html) {
                return String(html[r])
            }
        }
        return nil
    }

    private static func extractTitleTag(_ html: String) -> String? {
        let pattern = #"<title>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, range: range),
           let r = Range(match.range(at: 1), in: html) {
            return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
