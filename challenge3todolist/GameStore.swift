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
            growTimer = Timer.scheduledTimer(withTimeInterval: Theme.tickSeconds, repeats: true) { [weak self] _ in
                self?.advance()
            }
        }
        if d.object(forKey: "points") == nil { d.set(Theme.startingPoints, forKey: "points") }
        points = d.integer(forKey: "points")
        inventory = (d.dictionary(forKey: "garden.inventory") as? [String: Int]) ?? [:]
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
        guard points >= price else { return false }
        points -= price
        add(id)
        save()
        return true
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
    // How fast a tile grows (1 = normal, more with a sprinkler in the 3x3 area around it)
    func speed(forKey key: String) -> Double {
        let spot = tileCoords(key)
        var speed = 1.0
        for dc in -1...1 {
            for dr in -1...1 {
                if let tier = tiles[tileKey(spot.col + dc, spot.row + dr)]?.sprinkler,
                   let sp = Catalog.sprinkler(tier: tier) {
                    speed = max(speed, sp.speed)
                }
            }
        }
        return speed
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
        ticks += 1
        if ticks % 20 == 0 { save() }
    }

    // ---- harvesting ----
    func harvest() -> Int {
        var updated = tiles
        var n = 0
        for (key, tile) in tiles where isReady(tile) {
            if let seed = tile.seed {
                add("crop:\(seed)")
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
}
