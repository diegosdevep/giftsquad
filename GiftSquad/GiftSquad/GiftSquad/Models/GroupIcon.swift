import Foundation

enum GroupIcon {
    static let fallback = "gift.fill"

    static let catalog: [String] = [
        "gift.fill", "party.popper.fill", "birthday.cake.fill", "balloon.fill", "sparkles",
        "star.fill", "crown.fill", "trophy.fill", "wineglass.fill", "fireworks",
        "heart.fill", "figure.2.and.child.holdinghands", "person.3.fill", "house.fill", "teddybear.fill",
        "stroller.fill", "hands.clap.fill", "bed.double.fill",
        "tree.fill", "snowflake", "leaf.fill", "sun.max.fill", "moon.stars.fill",
        "flame.fill", "bolt.fill", "beach.umbrella.fill", "cloud.sun.fill",
        "briefcase.fill", "graduationcap.fill", "book.fill", "pencil.and.ruler.fill", "laptopcomputer",
        "building.2.fill", "stethoscope", "wrench.and.screwdriver.fill", "paintbrush.fill",
        "gamecontroller.fill", "headphones", "music.note", "film.fill", "camera.fill",
        "tv.fill", "theatermasks.fill", "paintpalette.fill", "popcorn.fill", "guitars.fill",
        "figure.run", "dumbbell.fill", "sportscourt.fill", "soccerball", "basketball.fill",
        "bicycle", "figure.hiking", "figure.yoga",
        "airplane", "car.fill", "tram.fill", "sailboat.fill", "tent.fill",
        "mountain.2.fill", "globe.americas.fill", "suitcase.fill",
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill", "bag.fill",
        "mug.fill", "carrot.fill",
        "pawprint.fill", "hare.fill", "tortoise.fill", "bird.fill", "fish.fill",
        "lightbulb.fill", "bell.fill", "key.fill", "flag.fill", "shippingbox.fill",
        "tshirt.fill", "hands.sparkles.fill", "giftcard.fill"
    ]

    private static let legacy: [(emoji: String, symbol: String)] = [
        ("\u{1F468}", "figure.2.and.child.holdinghands"),
        ("\u{1F469}", "figure.2.and.child.holdinghands"),
        ("\u{1F46A}", "figure.2.and.child.holdinghands"),
        ("\u{1FAC2}", "figure.2.and.child.holdinghands"),
        ("\u{1F381}", "gift.fill"),
        ("\u{1F389}", "party.popper.fill"),
        ("\u{1F38A}", "party.popper.fill"),
        ("\u{1F973}", "party.popper.fill"),
        ("\u{1F388}", "balloon.fill"),
        ("\u{1F384}", "tree.fill"),
        ("\u{1F385}", "tree.fill"),
        ("\u{1F382}", "birthday.cake.fill"),
        ("\u{1F370}", "birthday.cake.fill"),
        ("\u{1F9C1}", "birthday.cake.fill"),
        ("\u{1F49D}", "heart.fill"),
        ("\u{1F49E}", "heart.fill"),
        ("\u{1F495}", "heart.fill"),
        ("\u{1F497}", "heart.fill"),
        ("\u{1F496}", "heart.fill"),
        ("\u{1F498}", "heart.fill"),
        ("\u{1F491}", "heart.fill"),
        ("\u{1F48F}", "heart.fill"),
        ("\u{1F48D}", "heart.fill"),
        ("\u{2764}", "heart.fill"),
        ("\u{1F984}", "sparkles"),
        ("\u{2728}", "sparkles"),
        ("\u{1F31F}", "star.fill"),
        ("\u{2B50}", "star.fill"),
        ("\u{1F3E0}", "house.fill"),
        ("\u{1F3E1}", "house.fill"),
        ("\u{1F4BC}", "briefcase.fill"),
        ("\u{1F3E2}", "building.2.fill"),
        ("\u{1F37C}", "stroller.fill"),
        ("\u{1F476}", "stroller.fill"),
        ("\u{1F393}", "graduationcap.fill")
    ]

    static func symbol(icon: String?, emoji: String?) -> String {
        if let icon, catalog.contains(icon) { return icon }
        if let emoji {
            let scalars = Set(emoji.unicodeScalars)
            let match = legacy.first { item in
                item.emoji.unicodeScalars.first.map(scalars.contains) ?? false
            }
            if let match { return match.symbol }
        }
        return fallback
    }
}
