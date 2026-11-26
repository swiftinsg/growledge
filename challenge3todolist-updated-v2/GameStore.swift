//
//  GameStore.swift
//  The app
//

import SwiftUI
import Combine

// =====================================================================
// MARK: - 3. ITEMS + STORE  (inventory, points, plants; saved automatically)
// =====================================================================
// Item ids look like:  "seed:carrot"   "crop:carrot"   "gear:3"
struct ItemInfo {
    let id: String
    var kind: String { id.components(separatedBy: ":").first ?? "" }
    var name: String { id.components(separatedBy: ":").dropFirst().joined(separator: ":") }
    var imageName: String { kind == "gear" ? "sprinkler" : name }
    var displayName: String {
        if kind == "gear", let tier = Int(name), let sp = Catalog.sprinkler(tier: tier) { return sp.name }
        return name.capitalized
    }
}

func tileKey(_ col: Int, _ row: Int) -> String { "\(col),\(row)" }
func tileCoords(_ key: String) -> (col: Int, row: Int) {
    let p = key.split(separator: ",").compactMap { Int($0) }
    return p.count == 2 ? (p[0], p[1]) : (0, 0)
}

// Time left (rounds up): "45s" or "3m 5s"
func timeText(_ seconds: Double) -> String {
    let t = max(0, Int(ceil(seconds)))
    return t >= 60 ? "\(t / 60)m \(t % 60)s" : "\(t)s"
}

// Time already grown (rounds down)
func elapsedText(_ seconds: Double) -> String {
    let t = max(0, Int(floor(seconds)))
    return t >= 60 ? "\(t / 60)m \(t % 60)s" : "\(t)s"
}

struct Tile: Codable {
    var seed: String?
    var sprinkler: Int?
    var progress: Double = 0
}

final class GameStore: ObservableObject {
    static let shared = GameStore()

    // "points" is the shared currency: the garden shop spends it and
    // finished study sessions (StudyView) add to it.
    @Published var points: Int {
        didSet { UserDefaults.standard.set(points, forKey: "points") }
    }
    @Published var inventory: [String: Int]
    @Published var tiles: [String: Tile]
    /// Each harvested crop gets its own random weight, which changes how
    /// much it sells for. One FIFO queue of weights per crop id.
    @Published var cropWeights: [String: [Double]]
    /// Set briefly whenever a tornado destroys a crop, so the Garden screen
    /// can show a warning and the tornado art, then clears itself.
    @Published var disasterEvent: String? = nil
    private var ticks = 0

    // Plants grow all the time, not only while the garden screen is open
    private var growTimer: Timer?

    // When growth was last applied. Saved together with the tiles, so time
    // spent with the app closed or in the background still counts.
    private var lastUpdate: Date

    init() {
        let d = UserDefaults.standard
        lastUpdate = (d.object(forKey: "garden.lastUpdate") as? Date) ?? .now
        defer {
            // Catch up on the time the app was closed, then keep ticking
            advance()
            // Scheduled on the .common run loop mode (not the default one) so
            // the garden keeps growing even while the user is scrolling,
            // dragging, or navigating on another tab — not just while idle
            // on the Garden screen itself.
            let timer = Timer(timeInterval: Theme.tickSeconds, repeats: true) { [weak self] _ in
                self?.advance()
            }
            RunLoop.main.add(timer, forMode: .common)
            growTimer = timer
        }
        if d.object(forKey: "points") == nil { d.set(Theme.startingPoints, forKey: "points") }
        points = d.integer(forKey: "points")
        inventory = (d.dictionary(forKey: "garden.inventory") as? [String: Int]) ?? [:]
        cropWeights = (d.dictionary(forKey: "garden.cropWeights") as? [String: [Double]]) ?? [:]
        if let data = d.data(forKey: "garden.tiles"),
           let saved = try? JSONDecoder().decode([String: Tile].self, from: data) {
            tiles = saved
        } else {
            tiles = [:]
        }
    }

    func save() {
        let d = UserDefaults.standard
        d.set(inventory, forKey: "garden.inventory")
        d.set(cropWeights, forKey: "garden.cropWeights")
        d.set(try? JSONEncoder().encode(tiles), forKey: "garden.tiles")
        d.set(lastUpdate, forKey: "garden.lastUpdate")
    }

    // ---- inventory ----
    func count(_ id: String) -> Int { inventory[id] ?? 0 }
    func add(_ id: String) { inventory[id, default: 0] += 1 }
    func remove(_ id: String) {
        let c = count(id)
        inventory[id] = c > 1 ? c - 1 : nil
    }

    var sortedInventory: [String] {
        inventory.filter { $0.value > 0 }.keys.sorted { sortOrder($0) < sortOrder($1) }
    }
    private func sortOrder(_ id: String) -> Int {
        let info = ItemInfo(id: id)
        let idx = Catalog.cropNames.firstIndex(of: info.name) ?? (Int(info.name) ?? 0)
        switch info.kind {
        case "seed": return idx
        case "gear": return 1000 + idx
        default: return 2000 + idx
        }
    }

    // ---- buying and selling ----
    @discardableResult
    func buy(_ id: String, price: Int) -> Bool {
        guard points >= price, stockToday(id: id, price: price) > 0 else { return false }
        points -= price
        add(id)
        recordPurchase(id)
        save()
        return true
    }

    // ---- daily shop stock (rarer, pricier items are harder to find) ----
    private static let purchasedKeyPrefix = "stock.purchased."

    private func dayNumber(_ date: Date = .now) -> Int { Int(date.timeIntervalSince1970 / 86400) }

    /// The top amount of `id` that could possibly be in stock today, before
    /// any have been bought. Cheap items are always plentiful; the priciest
    /// items cap out at just 1, so they're often completely sold out.
    private func baseStock(price: Int) -> Int {
        switch price {
        case ..<1_000: return 99
        case ..<10_000: return 20
        case ..<100_000: return 8
        case ..<1_000_000: return 3
        default: return 1
        }
    }

    /// How many units of `id` are left to buy today. Resets every midnight;
    /// deterministic for the day, so everyone sees the same stock without
    /// needing to save anything beyond how much has already been bought.
    func stockToday(id: String, price: Int) -> Int {
        let base = baseStock(price: price)
        var hasher = Hasher()
        hasher.combine(dayNumber())
        hasher.combine(id)
        let total = Int(UInt(bitPattern: hasher.finalize()) % UInt(base + 1))
        let purchased = UserDefaults.standard.integer(forKey: Self.purchasedKeyPrefix + "\(dayNumber()).\(id)")
        return max(0, total - purchased)
    }

    private func recordPurchase(_ id: String) {
        let key = Self.purchasedKeyPrefix + "\(dayNumber()).\(id)"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }

    // seeds can't be sold (nil). Everything else sells for 50%.
    func sellValue(_ id: String) -> Int? {
        let info = ItemInfo(id: id)
        switch info.kind {
        case "crop":
            guard let crop = Catalog.cropByName[info.name] else { return nil }
            return Int(Double(crop.price) * Theme.sellRate)
        case "gear":
            guard let tier = Int(info.name), let sp = Catalog.sprinkler(tier: tier) else { return nil }
            return Int(Double(sp.price) * Theme.sellRate)
        default:
            return nil
        }
    }

    func sell(_ id: String) -> Int? {
        guard count(id) > 0, let value = sellValue(id) else { return nil }
        remove(id)
        points += value
        save()
        return value
    }

    // ---- planting ----
    func place(_ id: String, col: Int, row: Int) -> Bool {
        guard count(id) > 0 else { return false }
        let key = tileKey(col, row)
        if let t = tiles[key], t.seed != nil || t.sprinkler != nil { return false }
        let info = ItemInfo(id: id)
        if info.kind == "seed", Catalog.cropByName[info.name] != nil {
            tiles[key] = Tile(seed: info.name, sprinkler: nil, progress: 0)
        } else if info.kind == "gear", let tier = Int(info.name), Catalog.sprinkler(tier: tier) != nil {
            tiles[key] = Tile(seed: nil, sprinkler: tier, progress: 0)
        } else {
            return false
        }
        remove(id)
        save()
        return true
    }

    func isReady(_ tile: Tile) -> Bool {
        guard let seed = tile.seed, let crop = Catalog.cropByName[seed] else { return false }
        return tile.progress >= crop.growSeconds
    }

    var readyCount: Int { tiles.values.filter { isReady($0) }.count }

    // ---- growing ----
    // How fast a tile grows: the season sets a baseline (rain speeds things
    // up, snow/winter slows them down), and a nearby sprinkler multiplies
    // that further (the best sprinkler in the surrounding 3x3 area wins).
    func speed(forKey key: String) -> Double {
        let spot = tileCoords(key)
        var sprinklerSpeed = 1.0
        for dc in -1...1 {
            for dr in -1...1 {
                if let tier = tiles[tileKey(spot.col + dc, spot.row + dr)]?.sprinkler,
                   let sp = Catalog.sprinkler(tier: tier) {
                    sprinklerSpeed = max(sprinklerSpeed, sp.speed)
                }
            }
        }
        return Season.current.growthMultiplier * sprinklerSpeed
    }

    /// Grows plants by the real time since the last update. Also called when
    /// the app returns to the foreground, where the timer was paused.
    func advance() {
        let now = Date()
        let dt = max(0, now.timeIntervalSince(lastUpdate))
        lastUpdate = now
        tick(dt)
    }

    func tick(_ dt: Double) {
        var updated = tiles
        var changed = false
        for (key, tile) in tiles {
            guard let seed = tile.seed, let crop = Catalog.cropByName[seed],
                  tile.progress < crop.growSeconds else { continue }
            updated[key]?.progress = min(crop.growSeconds, tile.progress + dt * speed(forKey: key))
            changed = true
        }
        if changed { tiles = updated }
        maybeStrikeTornado(dt: dt)
        ticks += 1
        if ticks % 20 == 0 { save() }
    }

    // ---- natural disaster: tornadoes during storms ----
    /// Any sprinkler placed next to a crop shields it from a tornado — one
    /// more reason to invest in sprinklers besides growth speed.
    private func isProtected(_ key: String) -> Bool {
        let spot = tileCoords(key)
        for dc in -1...1 {
            for dr in -1...1 {
                if tiles[tileKey(spot.col + dc, spot.row + dr)]?.sprinkler != nil { return true }
            }
        }
        return false
    }

    /// A rare chance, only during rainy/stormy weather, that a tornado
    /// destroys one unprotected, already-growing crop. Never strikes a tile
    /// planted in the last 5 seconds, so it can't ruin a fresh plant on the spot.
    private func maybeStrikeTornado(dt: Double) {
        guard Season.current == .rainy else { return }
        let chancePerSecond = 0.00035
        guard Double.random(in: 0...1) < chancePerSecond * dt else { return }

        let candidates = tiles.filter { key, tile in
            tile.seed != nil && tile.progress > 5 && !isProtected(key)
        }
        guard let (key, tile) = candidates.randomElement(), let seed = tile.seed else { return }
        tiles[key] = nil
        let name = Catalog.cropByName[seed]?.name.capitalized ?? "crop"
        disasterEvent = "🌪️ A tornado destroyed your \(name)! Sprinklers protect nearby crops."
        save()
    }

    // ---- harvesting ----
    /// Harvests every ready tile at once (the "Hold to Harvest" button).
    func harvest() -> Int {
        var updated = tiles
        var n = 0
        for (key, tile) in tiles where isReady(tile) {
            if let seed = tile.seed {
                addHarvestedCrop(seed)
                updated[key] = nil
                n += 1
            }
        }
        if n > 0 {
            tiles = updated
            save()
        }
        return n
    }

    /// Harvests just the one tile at `key`, if it's ready. Lets the player
    /// pick a single crop instead of collecting everything at once.
    @discardableResult
    func harvestTile(_ key: String) -> Bool {
        guard let tile = tiles[key], isReady(tile), let seed = tile.seed else { return false }
        addHarvestedCrop(seed)
        tiles[key] = nil
        save()
        return true
    }

    /// Adds one unit of a harvested crop with its own random weight
    /// (0.7x–1.4x), which later changes how much it sells for.
    private func addHarvestedCrop(_ seed: String) {
        let id = "crop:\(seed)"
        add(id)
        cropWeights[id, default: []].append(Double.random(in: 0.7...1.4))
    }

    // ---- selling via the drag-to-tray Sell screen ----
    /// Pulls one unit of `id` out of inventory for the sell tray. Returns its
    /// weight (1.0 for anything that isn't a crop) and the price it would
    /// sell for right now — or nil if there isn't one, or it can't be sold.
    func takeForTray(_ id: String) -> (weight: Double, unitPrice: Int)? {
        guard count(id) > 0, let base = sellValue(id) else { return nil }
        let info = ItemInfo(id: id)
        var weight = 1.0
        if info.kind == "crop" {
            var q = cropWeights[id] ?? []
            if !q.isEmpty {
                weight = q.removeFirst()
                cropWeights[id] = q
            }
        }
        remove(id)
        let unitPrice = info.kind == "crop" ? max(1, Int((Double(base) * weight).rounded())) : base
        save()
        return (weight, unitPrice)
    }

    /// Puts an item taken for the tray back into inventory (the player
    /// removed it from the tray before selling).
    func returnFromTray(_ id: String, weight: Double) {
        add(id)
        if ItemInfo(id: id).kind == "crop" {
            cropWeights[id, default: []].append(weight)
        }
        save()
    }
}
