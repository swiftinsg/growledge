//
//  Catalog.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 2. CATALOG  (all products, prices and growth times)
// =====================================================================
/// Hand-made pixel pictures for a crop (names of images in the asset catalog).
/// Any that are missing fall back to the drawn art in FruitArt.swift.
struct CropArt {
    /// The seed (shown in the bag and the shop).
    var seed: String? = nil
    /// The harvested fruit.
    var fruit: String? = nil
    /// The young plant while it grows.
    var sapling: String? = nil
    /// The grown plant, shown when it is ready to harvest.
    var tree: String? = nil
}

struct Crop: Identifiable {
    let name: String
    let price: Int
    let growSeconds: Double
    /// How the seed packet, the growing plant and the fruit are drawn (see FruitArt.swift).
    var style: FruitStyle = .fallback
    /// Pixel pictures, when we have them.
    var art: CropArt? = nil
    var id: String { name }
}

struct Sprinkler: Identifiable {
    let tier: Int
    let name: String
    let price: Int
    let speed: Double           // growth speed multiplier
    /// How long it keeps working after it is placed; better ones last longer.
    let duration: TimeInterval
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

    /// The pixel art we have so far. Anything missing falls back to drawn art.
    private static let pixelArt: [String: CropArt] = [
        "dewdrop berry":   CropArt(seed: "dewdropberryseed", fruit: "dewdropberryfruit", sapling: "dewdropberrysapling", tree: "dewdropfruit"),
        "mossglow pear":   CropArt(seed: "mossglowpearseed", fruit: "mossglowpearfruit", sapling: "mossglowpearsapling", tree: "mossglowpearseedtree"),
        "ember fig":       CropArt(seed: "emberfigseed", fruit: "emberfigfruit", sapling: "emberfigsapling", tree: "emberfigtree"),
        "moonbloom plum":  CropArt(seed: "moonbloomplumseed", fruit: "moonbloomplumfruit"),
        "sunscale citrus": CropArt(seed: "sunscalecitrusseed", fruit: "sunscalecitrusfruit", sapling: "sunscalecitrussapling", tree: "sunscalercitrustree"),
        "phoenix flame":   CropArt(seed: "pheonixflameseed", fruit: "pheonixflamefruit", sapling: "pheonixflamesapling", tree: "pheonixflametree"),
        "unicorn peach":   CropArt(seed: "unicornpeachseed", fruit: "unicornpeachfruit", sapling: "unicornpeachsapling"),
        "mermaid pearl":   CropArt(fruit: "mermaidpearlfruit", sapling: "pixil-frame-0 (62)", tree: "mermaidpearltree"),
        "ruby crystal":    CropArt(seed: "rubycrystalseeds", fruit: "rubycrystalfruit", sapling: "rubycrystalsapling", tree: "rubysrystaltree"),
        "golden apple":    CropArt(seed: "goldenappleseed", fruit: "goldenapplefruit", tree: "goldenappletree"),
        "aurora melon":    CropArt(seed: "auroramelonseeds", fruit: "auroramelonfruit", sapling: "auroramelonsapling", tree: "auroramelontree"),
        "celestial peach": CropArt(seed: "celestialpeachseed", fruit: "celestialpeachfruit", sapling: "celestialpeachsapling", tree: "celestialpeachtree")
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
            return Crop(name: name, price: price, growSeconds: max(1, grow), style: fruitDefs[i].style, art: pixelArt[name])
        }
    }()

    // uniquingKeysWith so a duplicate name can never crash the app
    static let cropByName: [String: Crop] = {
        return Dictionary(crops.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    // 7 sprinkler tiers. They speed up plants in the 3x3 area around them.
    static let sprinklers: [Sprinkler] = [
        Sprinkler(tier: 1, name: "Tiny Sprinkler",     price: 500,         speed: 1.5, duration: 15 * 60, color: .green),
        Sprinkler(tier: 2, name: "Super Sprinkler",    price: 5_000,       speed: 2, duration: 30 * 60, color: .blue),
        Sprinkler(tier: 3, name: "Mega Sprinkler",     price: 50_000,      speed: 3, duration: 60 * 60, color: .purple),
        Sprinkler(tier: 4, name: "Ultra Sprinkler",    price: 500_000,     speed: 5, duration: 2 * 3600, color: .orange),
        Sprinkler(tier: 5, name: "Rainbow Sprinkler",  price: 5_000_000,   speed: 10, duration: 4 * 3600, color: .pink),
        Sprinkler(tier: 6, name: "Galaxy Sprinkler",   price: 25_000_000,  speed: 16, duration: 8 * 3600, color: .indigo),
        Sprinkler(tier: 7, name: "Celestial Sprinkler", price: 100_000_000, speed: 25, duration: 24 * 3600, color: .yellow)
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
        // The limited-edition pumpkins are gone; their plants become regular crops.
        switch name {
        case "pumpkin", "ghostlight pumpkin": return "ember fig"
        case "pumpkin t", "witchfire gourd": return "phoenix flame"
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

/// "15m", "1h", "24h": how long a sprinkler works.
func sprinklerDurationText(_ seconds: TimeInterval) -> String {
    let minutes = Int((seconds / 60).rounded())
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
}
