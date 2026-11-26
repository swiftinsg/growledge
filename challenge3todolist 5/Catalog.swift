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

/// Hand-made animations for a crop. Each is a file in the app bundle WITH its
/// extension, so GIFs and MP4s can be mixed freely (see AnimatedSprite.swift).
/// Any that are missing are simply skipped.
struct CropAnim {
    /// Plays when the seed is planted.
    var planting: String? = nil
    /// Plays when the seed turns into a sapling.
    var seedToSapling: String? = nil
    /// Plays when the sapling turns into the grown plant.
    var saplingToTree: String? = nil

    struct Item: Identifiable {
        let title: String
        let file: String
        var id: String { file }
    }

    /// The animations this crop has, in the order they happen.
    var all: [Item] {
        var items: [Item] = []
        if let planting { items.append(Item(title: "Planting", file: planting)) }
        if let seedToSapling { items.append(Item(title: "Seed to sapling", file: seedToSapling)) }
        if let saplingToTree { items.append(Item(title: "Sapling to plant", file: saplingToTree)) }
        return items
    }
}

struct Crop: Identifiable {
    let name: String
    let price: Int
    let growSeconds: Double
    /// How the seed packet, the growing plant and the fruit are drawn (see FruitArt.swift).
    var style: FruitStyle = .fallback
    /// Pixel pictures, when we have them.
    var art: CropArt? = nil
    /// Event crops only exist in the shop during their season (see `Catalog.availableEventCrops`).
    var event: SeasonalEvent? = nil
    /// GIF / MP4 animations, when we have them.
    var anim: CropAnim? = nil
    /// What an average harvested crop sells for, as a multiple of the seed
    /// price. Always above 1, so growing something is always worth it.
    var sellMultiplier: Double = 1.5
    var id: String { name }

    /// Base sell price of one average crop (before weight and mutation).
    var sellPrice: Int { max(1, Int((Double(price) * sellMultiplier).rounded())) }
    /// Coins earned per hour of waiting, for one plot, on an average crop.
    var profitPerHour: Double { Double(sellPrice - price) / (growSeconds / 3600) }
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
    // Only crops that have hand-made pixel art are in the game. To add a crop,
    // draw it, add a row to `cropRows` (price, grow time) and a row to `pixelArt`.
    // Every name must be unique.
    //
    // THE ECONOMY, in one place:
    //  - A seed costs `price`. An average crop sells for price x sellMultiplier
    //    (1.5x for the first crop, creeping up to about 2.3x for the last, because
    //    waiting longer should pay better).
    //  - Each harvest has a random weight (0.7x - 1.4x) and a small chance of a
    //    shiny mutation, so a crop never sells for less than its seed (apart
    //    from the rare Rotten / Infested ones).
    //  - Grow times run from 5 minutes to 24 hours, so there is always something
    //    worth planting before a study session, and something for overnight.
    private static let cropRows: [(name: String, price: Int, grow: Double, style: FruitStyle)] = [
        ("dewdrop berry",   15,     300,    FruitStyle(shape: .drop,    primary: Color(hex: 0x4FB3E8), secondary: Color(hex: 0xD6F1FF))),
        ("mossglow pear",   45,     720,    FruitStyle(shape: .pear,    primary: Color(hex: 0x6DBE45), secondary: Color(hex: 0xDDF7B0))),
        ("ember fig",       110,    1_500,  FruitStyle(shape: .pear,    primary: Color(hex: 0xD9482B), secondary: Color(hex: 0xFFB36B))),
        ("moonbloom plum",  250,    2_700,  FruitStyle(shape: .orb,     primary: Color(hex: 0x6C4AB6), secondary: Color(hex: 0xC9B8F5))),
        ("sunscale citrus", 550,    5_400,  FruitStyle(shape: .orb,     primary: Color(hex: 0xF29B1D), secondary: Color(hex: 0xFFE08A))),
        ("phoenix flame",   1_200,  10_800, FruitStyle(shape: .flame,   primary: Color(hex: 0xE63B2E), secondary: Color(hex: 0xFFD166), leaf: false)),
        ("unicorn peach",   2_600,  16_200, FruitStyle(shape: .orb,     primary: Color(hex: 0xF08CC8), secondary: Color(hex: 0xCDB4FF))),
        ("mermaid pearl",   5_500,  21_600, FruitStyle(shape: .orb,     primary: Color(hex: 0x2EC4B6), secondary: Color(hex: 0xF1FFFD), leaf: false)),
        ("ruby crystal",    11_000, 32_400, FruitStyle(shape: .crystal, primary: Color(hex: 0xC1121F), secondary: Color(hex: 0xFF8FA3), leaf: false)),
        ("golden apple",    22_000, 43_200, FruitStyle(shape: .orb,     primary: Color(hex: 0xE5A800), secondary: Color(hex: 0xFFF3B0))),
        ("aurora melon",    45_000, 64_800, FruitStyle(shape: .spiral,  primary: Color(hex: 0x2FCB88), secondary: Color(hex: 0xA56BFF))),
        ("celestial peach", 90_000, 86_400, FruitStyle(shape: .orb,     primary: Color(hex: 0xFFB38A), secondary: Color(hex: 0xFFFFFF)))
    ]

    static let cropNames: [String] = cropRows.map(\.name)

    /// The pixel art we have. Names are the image sets in Assets.xcassets.
    /// Anything missing falls back to drawn art.
    private static let pixelArt: [String: CropArt] = [
        "dewdrop berry":   CropArt(seed: "dewdropberryseed", sapling: "dewdropberrysapling", tree: "dewdropfruit"),
        "mossglow pear":   CropArt(seed: "mossglowpearseed", sapling: "mossglowpearsapling", tree: "mossglowpearseedtree"),
        "ember fig":       CropArt(seed: "emberfigseed", tree: "emberfigtree"),
        "moonbloom plum":  CropArt(seed: "moonbloomplumseed"),
        "sunscale citrus": CropArt(seed: "sunscalecitrusseed", sapling: "sunscalecitrussapling", tree: "sunscalercitrustree"),
        "phoenix flame":   CropArt(seed: "pheonixflameseed", sapling: "pheonixflamesapling", tree: "pheonixflametree"),
        "unicorn peach":   CropArt(seed: "unicornpeachseed", sapling: "unicornpeachsapling"),
        "mermaid pearl":   CropArt(sapling: "pixil-frame-0 (62)", tree: "mermaidpearltree"),
        "ruby crystal":    CropArt(seed: "rubycrystalseeds", sapling: "rubycrystalsapling", tree: "rubysrystaltree"),
        "golden apple":    CropArt(seed: "goldenappleseed", tree: "goldenappletree"),
        "aurora melon":    CropArt(seed: "auroramelonseeds", sapling: "auroramelonsapling", tree: "auroramelontree"),
        "celestial peach": CropArt(seed: "celestialpeachseed", sapling: "celestialpeachsapling", tree: "celestialpeachtree")
    ]

    /// Your animations. Files can be .gif or .mp4 (or .mov / .m4v).
    private static let animations: [String: CropAnim] = [
        "dewdrop berry":   CropAnim(planting: "plantingdewdropberryseed.mp4", seedToSapling: "dewdropberryseedtosapling.mp4", saplingToTree: "dewdropsaplingtodewdroptree.mp4"),
        "mossglow pear":   CropAnim(planting: "mossglowpearplantingseeed.mp4", seedToSapling: "mossglowpearseedtosapling.mp4", saplingToTree: "mossglowpearsaplingtotree.mp4"),
        "ember fig":       CropAnim(planting: "emberfigseedplanting.gif", seedToSapling: "emberfigseedtosapling.gif", saplingToTree: "emberfigsaplingtotree.gif"),
        "moonbloom plum":  CropAnim(planting: "moonbloomplumseedplanting.gif"),
        "sunscale citrus": CropAnim(planting: "sunscalecitrusseed.gif", seedToSapling: "sunscale.gif", saplingToTree: "sunscalecitrussaplingtotree.gif"),
        "phoenix flame":   CropAnim(planting: "pheonixflameplantingseed.gif", seedToSapling: "pheonixflameseedtosapling.gif", saplingToTree: "pheonixflamesaplingtotree.gif"),
        "unicorn peach":   CropAnim(planting: "unicornpeachseedplanting.gif", seedToSapling: "unicornsseedtosapling.gif", saplingToTree: "unicornpearlsaplingtotree.gif"),
        "mermaid pearl":   CropAnim(planting: "mermaidpearlseedplanting.gif", seedToSapling: "mermaidpearlseedtospaling.gif", saplingToTree: "mermaidpearlsaplingtotree.gif"),
        "ruby crystal":    CropAnim(planting: "rubycrystal.gif", seedToSapling: "rubycrystalseedtoplant.gif", saplingToTree: "rubycrystalsaplingtotree.gif"),
        "golden apple":    CropAnim(planting: "goldenappleseedplanting.gif", seedToSapling: "goldenappleseedtotree.gif", saplingToTree: "goldenapplesaplingtotree.gif"),
        "aurora melon":    CropAnim(planting: "auroramelonseed.gif", seedToSapling: "auroramelonsaplingtoseed.gif", saplingToTree: "auroramelonsaplingtotree.gif"),
        "celestial peach": CropAnim(planting: "celestialpeachplanting.gif", seedToSapling: "celestialpeachseedtosapling.gif", saplingToTree: "celestialpeachsaplingtotree.gif")
    ]

    static let crops: [Crop] = cropRows.enumerated().map { i, row in
        Crop(name: row.name, price: row.price, growSeconds: row.grow, style: row.style,
             art: pixelArt[row.name], anim: animations[row.name],
             // 1.50x for the first crop, up to about 2.27x for the last
             sellMultiplier: 1.5 + 0.07 * Double(i))
    }

    // ---- Seasonal events ----
    // No event crops for now: the Halloween and Christmas seeds had no artwork.
    // Add a Crop(... event: .halloween) here when you draw one and the shop
    // will show it automatically while that event is running.
    static let halloweenCrops: [Crop] = []
    static let christmasCrops: [Crop] = []

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
    // Priced against what they save: a sprinkler covers up to 9 plots, so
    // each tier costs roughly what its extra growth is worth on the crops
    // you can afford at that point.
    static let sprinklers: [Sprinkler] = [
        Sprinkler(tier: 1, name: "Tiny Sprinkler",      price: 300,     speed: 1.5, duration: 15 * 60,  color: .green),
        Sprinkler(tier: 2, name: "Super Sprinkler",     price: 1_500,   speed: 2,   duration: 30 * 60,  color: .blue),
        Sprinkler(tier: 3, name: "Mega Sprinkler",      price: 6_000,   speed: 3,   duration: 60 * 60,  color: .purple),
        Sprinkler(tier: 4, name: "Ultra Sprinkler",     price: 24_000,  speed: 4,   duration: 2 * 3600, color: .orange),
        Sprinkler(tier: 5, name: "Rainbow Sprinkler",   price: 80_000,  speed: 5,   duration: 4 * 3600, color: .pink),
        Sprinkler(tier: 6, name: "Galaxy Sprinkler",    price: 220_000, speed: 6,   duration: 8 * 3600, color: .indigo),
        Sprinkler(tier: 7, name: "Celestial Sprinkler", price: 500_000, speed: 8,   duration: 12 * 3600, color: .yellow)
    ]

    static func sprinkler(tier: Int) -> Sprinkler? {
        sprinklers.first { $0.tier == tier }
    }

    // ---- Saves from before the garden rework ----

    /// The 21 crop names used before the garden was cut down to the crops that
    /// have artwork, cheapest first. Anything saved under a name that no longer
    /// exists becomes the crop at the same price tier.
    private static let previousCropNames: [String] = [
        "dewdrop berry", "mossglow pear", "ember fig", "moonbloom plum", "frostmelon",
        "sunscale citrus", "stormberry", "pixie apple", "dragon fruit", "phoenix flame",
        "nova starfruit", "unicorn peach", "mermaid pearl", "ruby crystal", "nebula grape",
        "golden apple", "ambrosia lotus", "void berry", "aurora melon", "yggdrasil fruit",
        "celestial peach"
    ]

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
        case "pumpkin", "ghostlight pumpkin", "gift berry", "starlight fruit": return "sunscale citrus"
        case "pumpkin t", "witchfire gourd", "frosted pine cone", "cocoa bloom": return "phoenix flame"
        default: break
        }
        if let old = previousCropNames.firstIndex(of: name) {
            return nearestCrop(position: Double(old) / Double(previousCropNames.count - 1))
        }
        guard let old = legacyCropNames.firstIndex(of: name) else { return name }
        return nearestCrop(position: Double(old) / Double(legacyCropNames.count - 1))
    }

    /// The crop that sits `position` (0 = cheapest, 1 = priciest) along the list.
    private static func nearestCrop(position: Double) -> String {
        cropNames[Int((position * Double(cropNames.count - 1)).rounded())]
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

/// Long times in a friendly way: "45s", "5m", "1h 30m", "1d 2h".
func longTimeText(_ seconds: Double) -> String {
    let t = max(0, Int(ceil(seconds)))
    let d = t / 86_400, h = (t % 86_400) / 3_600, m = (t % 3_600) / 60, s = t % 60
    if d > 0 { return h > 0 ? "\(d)d \(h)h" : "\(d)d" }
    if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
    if m > 0 { return (m < 10 && s > 0) ? "\(m)m \(s)s" : "\(m)m" }
    return "\(s)s"
}
