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

    func fetch(_ url: URL) async throws -> LinkPreview {
        var request = URLRequest(url: url)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("es-AR,es;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            return LinkPreview(url: url)
        }
        let resolvedURL = response.url ?? url

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

        return LinkPreview(
            url: url,
            title: rawTitle.map { Self.cleanTitle(Self.decodeHTMLEntities($0)) },
            description: rawDescription.map(Self.decodeHTMLEntities),
            imageURL: (jsonImage ?? Self.extractMeta(html, property: "og:image") ?? amazonImage)
                .flatMap { Self.absoluteURL($0, relativeTo: resolvedURL) },
            price: offer.price
                ?? Self.extractMeta(html, property: "product:price:amount").flatMap(Double.init)
                ?? amazonPrice.price,
            originalPrice: amazonOriginalPrice ?? mercadoLibreOriginalPrice,
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

    private static func extractAmazonPrice(_ html: String) -> (price: Double?, currency: String?) {
        guard let regex = try? NSRegularExpression(pattern: #"class="a-offscreen">([^<]+)<"#) else {
            return (nil, nil)
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let r = Range(match.range(at: 1), in: html) else { return (nil, nil) }
        return Self.parseAmazonPriceString(String(html[r]))
    }

    private static func extractAmazonOriginalPrice(_ html: String) -> Double? {
        guard let regex = try? NSRegularExpression(
            pattern: #"data-a-strike="true"[^>]*>[\s\S]{0,150}?class="a-offscreen">([^<]+)<"#
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return Self.parseAmazonPriceString(String(html[r])).price
    }

    private static func parseAmazonPriceString(_ rawText: String) -> (price: Double?, currency: String?) {
        let raw = Self.decodeHTMLEntities(rawText).trimmingCharacters(in: .whitespacesAndNewlines)

        let currency: String?
        if raw.contains("€") { currency = "EUR" }
        else if raw.contains("$") { currency = "USD" }
        else if raw.contains("£") { currency = "GBP" }
        else if raw.uppercased().contains("EUR") { currency = "EUR" }
        else if raw.uppercased().contains("USD") { currency = "USD" }
        else if raw.uppercased().contains("GBP") { currency = "GBP" }
        else { currency = nil }

        let numeric = raw.filter { $0.isNumber || $0 == "," || $0 == "." }
        let normalized: String
        if let commaIdx = numeric.lastIndex(of: ","), let dotIdx = numeric.lastIndex(of: "."), commaIdx > dotIdx {
            normalized = numeric.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if numeric.contains(",") {
            normalized = numeric.replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = numeric
        }
        return (Double(normalized), currency)
    }

    private static func currencyFromHost(_ url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let byTLD: [String: String] = [
            "amazon.es": "EUR", "amazon.de": "EUR", "amazon.fr": "EUR",
            "amazon.it": "EUR", "amazon.nl": "EUR", "amazon.se": "EUR",
            "amazon.pl": "EUR", "amazon.com.be": "EUR", "amazon.ie": "EUR",
            "amazon.com": "USD", "amazon.ca": "CAD",
            "amazon.co.uk": "GBP",
            "amazon.com.mx": "MXN", "amazon.com.br": "BRL",
            "amazon.co.jp": "JPY", "amazon.in": "INR",
            "amazon.com.au": "AUD",
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
        case let s as String: price = Double(s)
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
