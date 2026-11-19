//
//  Catalog.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 2. CATALOG  (all products, prices and growth times)
// =====================================================================
struct Crop: Identifiable {
    let name: String            // = the image name (unless systemIcon is set)
    let price: Int
    let growSeconds: Double
    /// When set, this crop has no artwork asset and is drawn as a coloured
    /// SF Symbol instead (used for limited-time event crops).
    var systemIcon: String? = nil
    var iconColor: Color = Theme.good
    /// Event crops only exist in the shop during their season (see `Catalog.availableEventCrops`).
    var event: SeasonalEvent? = nil
    var id: String { name }
}

struct Sprinkler: Identifiable {
    let tier: Int
    let name: String
    let price: Int
    let speed: Double           // growth speed multiplier
    let color: Color
    var id: Int { tier }
}

enum Catalog {
    // ORDER MATTERS: first = cheapest + fastest, last = most expensive + slowest.
    // Prices go from 10 to 1,000,000,000 and growth from 1 second to 30 minutes
    // automatically, spread across this list. Reorder, add or remove names freely.
    // (Every name must be unique.)
    static let cropNames: [String] = [
        // edibles
        "carrot", "cabbage", "raddish", "eggplant", "apple", "banana", "orange",
        "peanut", "egg", "pineapple", "coconut", "sugar cane", "cocoa", "chocolate",
        "fried chicken",
        // memes (oldest to newest)
        "doge", "obama", "donald trump", "pawn", "the rook", "ronaldo", "the skeleton",
        "backrooms scaryyy", "beluga", "jamal", "ishowspeed", "rudi", "ben",
        "tung tung tung sahur", "brr brr patapim", "iphone duo",
        "macbook proled xdr display",
        "carterpcs"
    ]

    static let minPrice = 10.0
    static let maxPrice = 1_000_000_000.0
    static let minGrowSeconds = 600.0       // 10 minutes
    static let maxGrowSeconds = 864000.0    // 10 days

    static let crops: [Crop] = {
        let n = cropNames.count
        return cropNames.enumerated().map { i, name in
            let t = n > 1 ? Double(i) / Double(n - 1) : 0
            let raw = minPrice * pow(maxPrice / minPrice, t)
            let step = pow(10.0, floor(log10(raw)) - 1)          // keep 2 digits, e.g. 4,800
            let price = Int((raw / step).rounded() * step)
            let grow = (minGrowSeconds * pow(maxGrowSeconds / minGrowSeconds, t)).rounded()
            return Crop(name: name, price: price, growSeconds: max(1, grow))
        }
    }()

    // ---- Halloween (Oct 1 – Nov 19): 2 limited seeds using your own art ----
    static let halloweenCrops: [Crop] = [
        Crop(name: "pumpkin", price: 18_000, growSeconds: 2_400, event: .halloween),
        Crop(name: "pumpkin t", price: 42_000, growSeconds: 5_400, event: .halloween)
    ]

    // ---- Christmas (Nov 20 – Jan 8): 4 limited seeds, drawn as icons ----
    static let christmasCrops: [Crop] = [
        Crop(name: "gift berry", price: 20_000, growSeconds: 2_700,
             systemIcon: "gift.fill", iconColor: Color(red: 0.85, green: 0.25, blue: 0.30), event: .christmas),
        Crop(name: "starlight fruit", price: 35_000, growSeconds: 3_600,
             systemIcon: "star.fill", iconColor: Color(red: 0.95, green: 0.82, blue: 0.35), event: .christmas),
        Crop(name: "frosted pine cone", price: 50_000, growSeconds: 4_500,
             systemIcon: "snowflake", iconColor: Color(red: 0.55, green: 0.85, blue: 0.95), event: .christmas),
        Crop(name: "cocoa bloom", price: 70_000, growSeconds: 5_400,
             systemIcon: "cup.and.saucer.fill", iconColor: Color(red: 0.70, green: 0.48, blue: 0.30), event: .christmas)
    ]

    /// All crops currently buyable from the shop: the regular rotation plus
    /// whichever seasonal event (if any) is running right now.
    static var availableEventCrops: [Crop] {
        switch SeasonalEvent.current {
        case .halloween: return halloweenCrops
        case .christmas: return christmasCrops
        case .none: return []
        }
    }

    // uniquingKeysWith so a duplicate name can never crash the app
    static let cropByName: [String: Crop] = {
        let all = crops + halloweenCrops + christmasCrops
        return Dictionary(all.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    // 7 sprinkler tiers. They speed up plants in the 3x3 area around them.
    static let sprinklers: [Sprinkler] = [
        Sprinkler(tier: 1, name: "Tiny Sprinkler",     price: 500,         speed: 1.5, color: .green),
        Sprinkler(tier: 2, name: "Super Sprinkler",    price: 5_000,       speed: 2,   color: .blue),
        Sprinkler(tier: 3, name: "Mega Sprinkler",     price: 50_000,      speed: 3,   color: .purple),
        Sprinkler(tier: 4, name: "Ultra Sprinkler",    price: 500_000,     speed: 5,   color: .orange),
        Sprinkler(tier: 5, name: "Rainbow Sprinkler",  price: 5_000_000,   speed: 10,  color: .pink),
        Sprinkler(tier: 6, name: "Galaxy Sprinkler",   price: 25_000_000,  speed: 16,  color: .indigo),
        Sprinkler(tier: 7, name: "Celestial Sprinkler", price: 100_000_000, speed: 25, color: .yellow)
    ]

    static func sprinkler(tier: Int) -> Sprinkler? {
        sprinklers.first { $0.tier == tier }
    }
}
