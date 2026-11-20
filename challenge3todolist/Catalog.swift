//
//  Catalog.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 2. CATALOG  (all products, prices and growth times)
// =====================================================================
struct Crop: Identifiable {
    let name: String
    let price: Int
    let growSeconds: Double
    /// How the seed packet, the growing plant and the fruit are drawn (see FruitArt.swift).
    var style: FruitStyle = .fallback
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
    // Prices go from 10 to 1,000,000,000 and growth from 10 minutes to 10 days
    // automatically, spread across this list. Every name must be unique.
    private static let fruitDefs: [(name: String, style: FruitStyle)] = [
        ("dewdrop berry",    FruitStyle(shape: .drop,    primary: Color(hex: 0x4FB3E8), secondary: Color(hex: 0xD6F1FF))),
        ("mossglow pear",    FruitStyle(shape: .pear,    primary: Color(hex: 0x6DBE45), secondary: Color(hex: 0xDDF7B0))),
        ("ember fig",        FruitStyle(shape: .pear,    primary: Color(hex: 0xD9482B), secondary: Color(hex: 0xFFB36B))),
        ("moonbloom plum",   FruitStyle(shape: .orb,     primary: Color(hex: 0x6C4AB6), secondary: Color(hex: 0xC9B8F5))),
        ("frostmelon",       FruitStyle(shape: .orb,     primary: Color(hex: 0x3FC1B5), secondary: Color(hex: 0xE0FFFA), leaf: false)),
        ("sunscale citrus",  FruitStyle(shape: .orb,     primary: Color(hex: 0xF29B1D), secondary: Color(hex: 0xFFE08A))),
        ("stormberry",       FruitStyle(shape: .cluster, primary: Color(hex: 0x4A6FA5), secondary: Color(hex: 0xA9C7F0), leaf: false)),
        ("pixie apple",      FruitStyle(shape: .orb,     primary: Color(hex: 0xE0529C), secondary: Color(hex: 0xFFB3DA))),
        ("dragon fruit",     FruitStyle(shape: .spiral,  primary: Color(hex: 0xD81E5B), secondary: Color(hex: 0x7BD389))),
        ("phoenix flame",    FruitStyle(shape: .flame,   primary: Color(hex: 0xE63B2E), secondary: Color(hex: 0xFFD166), leaf: false)),
        ("nova starfruit",   FruitStyle(shape: .star,    primary: Color(hex: 0xF2B705), secondary: Color(hex: 0xFFF6C2), leaf: false)),
        ("unicorn peach",    FruitStyle(shape: .orb,     primary: Color(hex: 0xF08CC8), secondary: Color(hex: 0xCDB4FF))),
        ("mermaid pearl",    FruitStyle(shape: .orb,     primary: Color(hex: 0x2EC4B6), secondary: Color(hex: 0xF1FFFD), leaf: false)),
        ("ruby crystal",     FruitStyle(shape: .crystal, primary: Color(hex: 0xC1121F), secondary: Color(hex: 0xFF8FA3), leaf: false)),
        ("nebula grape",     FruitStyle(shape: .cluster, primary: Color(hex: 0x7B2CBF), secondary: Color(hex: 0x5E8BFF))),
        ("golden apple",     FruitStyle(shape: .orb,     primary: Color(hex: 0xE5A800), secondary: Color(hex: 0xFFF3B0))),
        ("ambrosia lotus",   FruitStyle(shape: .lotus,   primary: Color(hex: 0xFF6FAE), secondary: Color(hex: 0xFFE3A3), leaf: false)),
        ("void berry",       FruitStyle(shape: .orb,     primary: Color(hex: 0x3A2263), secondary: Color(hex: 0xB45CFF), leaf: false)),
        ("aurora melon",     FruitStyle(shape: .spiral,  primary: Color(hex: 0x2FCB88), secondary: Color(hex: 0xA56BFF))),
        ("yggdrasil fruit",  FruitStyle(shape: .spiral,  primary: Color(hex: 0x2D6A4F), secondary: Color(hex: 0xE3B93B))),
        ("celestial peach",  FruitStyle(shape: .orb,     primary: Color(hex: 0xFFB38A), secondary: Color(hex: 0xFFFFFF)))
    ]

    static let cropNames: [String] = fruitDefs.map(\.name)

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
            return Crop(name: name, price: price, growSeconds: max(1, grow), style: fruitDefs[i].style)
        }
    }()

    // ---- Halloween (Oct 1 – Nov 19): 2 limited seeds ----
    static let halloweenCrops: [Crop] = [
        Crop(name: "ghostlight pumpkin", price: 18_000, growSeconds: 2_400,
             style: FruitStyle(shape: .orb, primary: Color(hex: 0xF57C00), secondary: Color(hex: 0xFFD08A)), event: .halloween),
        Crop(name: "witchfire gourd", price: 42_000, growSeconds: 5_400,
             style: FruitStyle(shape: .flame, primary: Color(hex: 0x7B2CBF), secondary: Color(hex: 0x9EF01A), leaf: false), event: .halloween)
    ]

    // ---- Christmas (Nov 20 – Jan 8): 4 limited seeds ----
    static let christmasCrops: [Crop] = [
        Crop(name: "gift berry", price: 20_000, growSeconds: 2_700,
             style: FruitStyle(shape: .cluster, primary: Color(hex: 0xD9404D), secondary: Color(hex: 0xFFD6D9)), event: .christmas),
        Crop(name: "starlight fruit", price: 35_000, growSeconds: 3_600,
             style: FruitStyle(shape: .star, primary: Color(hex: 0xF2C94C), secondary: Color(hex: 0xFFFBE0), leaf: false), event: .christmas),
        Crop(name: "frosted pine cone", price: 50_000, growSeconds: 4_500,
             style: FruitStyle(shape: .crystal, primary: Color(hex: 0x4FC3E8), secondary: Color(hex: 0xE6FAFF), leaf: false), event: .christmas),
        Crop(name: "cocoa bloom", price: 70_000, growSeconds: 5_400,
             style: FruitStyle(shape: .lotus, primary: Color(hex: 0x8D5A3A), secondary: Color(hex: 0xF3D9B5), leaf: false), event: .christmas)
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

    // ---- Saves from before the garden rework ----

    /// The crop names used before the garden got its mythical fruits, cheapest first.
    private static let legacyCropNames: [String] = [
        "carrot", "cabbage", "raddish", "eggplant", "apple", "banana", "orange",
        "peanut", "egg", "pineapple", "coconut", "sugar cane", "cocoa", "chocolate",
        "fried chicken",
        "doge", "obama", "donald trump", "pawn", "the rook", "ronaldo", "the skeleton",
        "backrooms scaryyy", "beluga", "jamal", "ishowspeed", "rudi", "ben",
        "tung tung tung sahur", "brr brr patapim", "iphone duo",
        "macbook proled xdr display",
        "carterpcs"
    ]

    /// The current name for a crop saved under an old name, so plants and
    /// seeds from older saves turn into the fruit at the same price tier.
    /// Names that are already current come back unchanged.
    static func currentCropName(for name: String) -> String {
        if cropByName[name] != nil { return name }
        switch name {
        case "pumpkin": return "ghostlight pumpkin"
        case "pumpkin t": return "witchfire gourd"
        default: break
        }
        guard let old = legacyCropNames.firstIndex(of: name) else { return name }
        let position = Double(old) / Double(legacyCropNames.count - 1)
        return cropNames[Int((position * Double(cropNames.count - 1)).rounded())]
    }

    /// Same, for an item id such as "seed:carrot" or "crop:carrot".
    static func currentItemID(for id: String) -> String {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0] == "seed" || parts[0] == "crop" else { return id }
        return "\(parts[0]):\(currentCropName(for: parts[1]))"
    }
}
