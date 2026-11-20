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

/// A cosmetic (and price-changing) mutation a crop can come out with when
/// harvested. Mostly metals, rarer the shinier — plus two "spoiled" ones
/// that knock the price down instead.
enum Mutation: String, Codable, CaseIterable {
    case none
    case copper, bronze, silver, gold, platinum, titanium, mercury, chrome
    case rotten, infested

    /// Multiplies the crop's sell price on top of its weight.
    var priceMultiplier: Double {
        switch self {
        case .none: 1.0
        case .copper: 1.2
        case .bronze: 1.45
        case .silver: 1.85
        case .gold: 2.5
        case .platinum: 3.5
        case .titanium: 5.0
        case .mercury: 8.0
        case .chrome: 13.0
        case .rotten: 0.35
        case .infested: 0.2
        }
    }

    /// How common this mutation is when a crop is harvested — bigger number,
    /// more common. The shinier metals are deliberately very rare.
    var rarity: Double {
        switch self {
        case .none: 52
        case .copper: 15
        case .bronze: 10
        case .silver: 6.5
        case .gold: 3.5
        case .platinum: 1.8
        case .titanium: 0.9
        case .mercury: 0.3
        case .chrome: 0.1
        case .rotten: 6.5
        case .infested: 3.4
        }
    }

    var label: String {
        switch self {
        case .none: ""
        case .copper: "Copper"
        case .bronze: "Bronzed"
        case .silver: "Silver"
        case .gold: "Golden"
        case .platinum: "Platinum"
        case .titanium: "Titanium"
        case .mercury: "Mercurial"
        case .chrome: "Chrome"
        case .rotten: "Rotten"
        case .infested: "Infested"
        }
    }

    /// Tint laid over the crop's artwork so a mutation is visible at a glance.
    var tint: Color? {
        switch self {
        case .none: nil
        case .copper: Color(red: 0.85, green: 0.53, blue: 0.30)
        case .bronze: Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: Color(red: 0.78, green: 0.80, blue: 0.84)
        case .gold: Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: Color(red: 0.90, green: 0.92, blue: 0.96)
        case .titanium: Color(red: 0.58, green: 0.63, blue: 0.68)
        case .mercury: Color(red: 0.78, green: 0.83, blue: 0.88)
        case .chrome: Color(red: 0.80, green: 0.95, blue: 1.0)
        case .rotten: Color(red: 0.40, green: 0.34, blue: 0.14)
        case .infested: Color(red: 0.45, green: 0.55, blue: 0.16)
        }
    }

    /// A random mutation, weighted by `rarity`. Overwhelmingly `.none`.
    static func random() -> Mutation {
        let total = allCases.reduce(0.0) { $0 + $1.rarity }
        var r = Double.random(in: 0..<total)
        for m in allCases {
            if r < m.rarity { return m }
            r -= m.rarity
        }
        return .none
    }
}

/// One harvested unit of a crop: its random weight and whatever mutation it
/// came out with. A FIFO queue of these per crop id is what the Sell screen
/// draws from.
struct HarvestedUnit: Codable {
    var weight: Double
    var mutation: Mutation = .none
}

// =====================================================================
// MARK: - Achievements  (one-time unlocks for lifetime milestones)
// =====================================================================

/// A one-time milestone. `isUnlocked` reads whatever `GameStore` stat (or
/// `StudyLogStore` streak) it needs at the moment it's checked.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let isUnlocked: (GameStore) -> Bool

    static let all: [Achievement] = [
        Achievement(id: "first_harvest", title: "First Harvest", detail: "Harvest your very first crop.", icon: "leaf.fill") {
            $0.lifetimeCropsHarvested >= 1
        },
        Achievement(id: "green_thumb", title: "Green Thumb", detail: "Harvest 100 crops in total.", icon: "leaf.circle.fill") {
            $0.lifetimeCropsHarvested >= 100
        },
        Achievement(id: "master_farmer", title: "Master Farmer", detail: "Harvest 1,000 crops in total.", icon: "crown.fill") {
            $0.lifetimeCropsHarvested >= 1000
        },
        Achievement(id: "shiny_hunter", title: "Shiny Hunter", detail: "Discover a Titanium, Mercurial or Chrome mutation.", icon: "sparkles") { store in
            store.discoveredMutations.contains { entry in
                let parts = entry.split(separator: "|")
                guard parts.count == 2, let m = Mutation(rawValue: String(parts[1])) else { return false }
                return [.titanium, .mercury, .chrome].contains(m)
            }
        },
        Achievement(id: "collector", title: "Collector", detail: "Discover 10 different mutations.", icon: "square.grid.3x3.fill") {
            $0.discoveredMutations.count >= 10
        },
        Achievement(id: "study_novice", title: "Study Novice", detail: "Study for a total of 30 minutes.", icon: "book.fill") {
            $0.lifetimeStudySeconds >= 1800
        },
        Achievement(id: "study_veteran", title: "Study Veteran", detail: "Study for a total of 10 hours.", icon: "graduationcap.fill") {
            $0.lifetimeStudySeconds >= 36_000
        },
        Achievement(id: "task_crusher", title: "Task Crusher", detail: "Finish 50 to-do tasks.", icon: "checkmark.seal.fill") {
            $0.lifetimeTasksCompleted >= 50
        },
        Achievement(id: "week_warrior", title: "Week Warrior", detail: "Keep a 7-day study streak.", icon: "flame.fill") { _ in
            StudyLogStore.shared.currentStreak() >= 7
        },
        Achievement(id: "rich_farmer", title: "Rich Farmer", detail: "Earn 100,000 coins in total.", icon: "dollarsign.circle.fill") {
            $0.lifetimeCoinsEarned >= 100_000
        }
    ]
}

// =====================================================================
// MARK: - Daily Quests  (a few small rotating goals, reset every day)
// =====================================================================

enum QuestKind: String {
    case harvest, study, tasks, plant
}

struct QuestTemplate: Identifiable {
    let id: String
    let kind: QuestKind
    let target: Double
    let title: String
    let icon: String
    let reward: Int
}

enum DailyQuests {
    /// The full pool of possible quests — 3 are picked from this (deterministically,
    /// so everyone sees the same 3 all day) each day.
    static let pool: [QuestTemplate] = [
        QuestTemplate(id: "harvest10", kind: .harvest, target: 10, title: "Harvest 10 crops", icon: "basket.fill", reward: 200),
        QuestTemplate(id: "harvest25", kind: .harvest, target: 25, title: "Harvest 25 crops", icon: "basket.fill", reward: 450),
        QuestTemplate(id: "study15", kind: .study, target: 15, title: "Study for 15 minutes", icon: "book.fill", reward: 250),
        QuestTemplate(id: "study30", kind: .study, target: 30, title: "Study for 30 minutes", icon: "book.fill", reward: 500),
        QuestTemplate(id: "tasks2", kind: .tasks, target: 2, title: "Finish 2 to-do tasks", icon: "checkmark.circle.fill", reward: 200),
        QuestTemplate(id: "tasks4", kind: .tasks, target: 4, title: "Finish 4 to-do tasks", icon: "checkmark.circle.fill", reward: 400),
        QuestTemplate(id: "plant5", kind: .plant, target: 5, title: "Plant 5 seeds", icon: "leaf.fill", reward: 150)
    ]
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
    /// Each harvested crop gets its own random weight and mutation, which
    /// together change how much it sells for. One FIFO queue per crop id.
    @Published var cropHarvests: [String: [HarvestedUnit]]
    /// Set briefly whenever a tornado destroys a crop, so the Garden screen
    /// can show a warning and the tornado art, then clears itself.
    @Published var disasterEvent: String? = nil
    private var ticks = 0

    // ---- lifetime + daily stats (Mutation Dex, Daily Quests, Achievements) ----
    /// "cropName|mutationRawValue" for every mutation ever discovered, so the
    /// Mutation Dex can show it even after the crop itself has been sold.
    @Published var discoveredMutations: Set<String> = []
    @Published var unlockedAchievements: Set<String> = []
    /// "dayNumber.questID" for quests already claimed today (and every day
    /// before — tiny strings, never worth pruning).
    @Published var claimedQuestIDs: Set<String> = []
    @Published var lifetimeCropsHarvested = 0
    @Published var lifetimeTasksCompleted = 0
    @Published var lifetimeStudySeconds: Double = 0
    @Published var lifetimeCoinsEarned = 0
    @Published var dailyCropsHarvested = 0
    @Published var dailyTasksCompleted = 0
    @Published var dailyStudySeconds: Double = 0
    @Published var dailySeedsPlanted = 0
    private var dailyStatsDay = 0
    /// Set the moment a new achievement unlocks, so any screen can show a
    /// celebratory banner; the view that shows it clears this back to nil.
    @Published var pendingAchievementUnlock: Achievement?

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
        if let data = d.data(forKey: "garden.cropHarvests"),
           let saved = try? JSONDecoder().decode([String: [HarvestedUnit]].self, from: data) {
            cropHarvests = saved
        } else if let legacy = d.dictionary(forKey: "garden.cropWeights") as? [String: [Double]] {
            // Carries over weights saved before mutations existed.
            cropHarvests = legacy.mapValues { $0.map { HarvestedUnit(weight: $0, mutation: .none) } }
        } else {
            cropHarvests = [:]
        }
        if let data = d.data(forKey: "garden.tiles"),
           let saved = try? JSONDecoder().decode([String: Tile].self, from: data) {
            tiles = saved
        } else {
            tiles = [:]
        }

        discoveredMutations = Set((d.array(forKey: "stats.discoveredMutations") as? [String]) ?? [])
        unlockedAchievements = Set((d.array(forKey: "stats.unlockedAchievements") as? [String]) ?? [])
        claimedQuestIDs = Set((d.array(forKey: "stats.claimedQuestIDs") as? [String]) ?? [])
        lifetimeCropsHarvested = d.integer(forKey: "stats.lifetimeCropsHarvested")
        lifetimeTasksCompleted = d.integer(forKey: "stats.lifetimeTasksCompleted")
        lifetimeStudySeconds = d.double(forKey: "stats.lifetimeStudySeconds")
        lifetimeCoinsEarned = d.integer(forKey: "stats.lifetimeCoinsEarned")
        dailyCropsHarvested = d.integer(forKey: "stats.dailyCropsHarvested")
        dailyTasksCompleted = d.integer(forKey: "stats.dailyTasksCompleted")
        dailyStudySeconds = d.double(forKey: "stats.dailyStudySeconds")
        dailySeedsPlanted = d.integer(forKey: "stats.dailySeedsPlanted")
        // Not calling dayNumber() here — it's an instance method, and every
        // stored property must already have a value before `self` can be
        // used, so the same "days since 1970" math is inlined instead.
        dailyStatsDay = d.object(forKey: "stats.dailyStatsDay") != nil
            ? d.integer(forKey: "stats.dailyStatsDay")
            : Int(Date().timeIntervalSince1970 / 86400)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(inventory, forKey: "garden.inventory")
        d.set(try? JSONEncoder().encode(cropHarvests), forKey: "garden.cropHarvests")
        d.set(try? JSONEncoder().encode(tiles), forKey: "garden.tiles")
        d.set(lastUpdate, forKey: "garden.lastUpdate")

        d.set(Array(discoveredMutations), forKey: "stats.discoveredMutations")
        d.set(Array(unlockedAchievements), forKey: "stats.unlockedAchievements")
        d.set(Array(claimedQuestIDs), forKey: "stats.claimedQuestIDs")
        d.set(lifetimeCropsHarvested, forKey: "stats.lifetimeCropsHarvested")
        d.set(lifetimeTasksCompleted, forKey: "stats.lifetimeTasksCompleted")
        d.set(lifetimeStudySeconds, forKey: "stats.lifetimeStudySeconds")
        d.set(lifetimeCoinsEarned, forKey: "stats.lifetimeCoinsEarned")
        d.set(dailyCropsHarvested, forKey: "stats.dailyCropsHarvested")
        d.set(dailyTasksCompleted, forKey: "stats.dailyTasksCompleted")
        d.set(dailyStudySeconds, forKey: "stats.dailyStudySeconds")
        d.set(dailySeedsPlanted, forKey: "stats.dailySeedsPlanted")
        d.set(dailyStatsDay, forKey: "stats.dailyStatsDay")
    }

    /// Coins coming IN (a sale, a study reward, a task, a quest) — unlike
    /// spending, this also counts toward `lifetimeCoinsEarned` (for the Rich
    /// Farmer achievement) and re-checks every achievement, since several of
    /// them depend on the stats this money came from.
    func earn(_ amount: Int) {
        guard amount != 0 else { return }
        points += amount
        if amount > 0 { lifetimeCoinsEarned += amount }
        checkAchievements()
        save()
    }

    /// Resets the daily-quest counters the moment the calendar day changes.
    /// Cheap to call often (just one Int comparison) — called from `advance()`
    /// so it's checked constantly without needing its own timer.
    private func ensureDailyReset() {
        let today = dayNumber()
        guard today != dailyStatsDay else { return }
        dailyStatsDay = today
        dailyCropsHarvested = 0
        dailyTasksCompleted = 0
        dailyStudySeconds = 0
        dailySeedsPlanted = 0
        save()
    }

    // ---- achievements ----
    /// Checks every not-yet-unlocked achievement against the current stats,
    /// unlocking (and persisting) any that now qualify. The first newly
    /// unlocked one is surfaced via `pendingAchievementUnlock` for a toast.
    @discardableResult
    func checkAchievements() -> [Achievement] {
        var newly: [Achievement] = []
        for achievement in Achievement.all where !unlockedAchievements.contains(achievement.id) {
            if achievement.isUnlocked(self) {
                unlockedAchievements.insert(achievement.id)
                newly.append(achievement)
            }
        }
        if let first = newly.first {
            pendingAchievementUnlock = first
            Haptics.success()
            SoundPlayer.fanfare()
        }
        if !newly.isEmpty { save() }
        return newly
    }

    // ---- daily quests ----
    /// Today's 3 quests — a deterministic pick from the pool so they're the
    /// same all day (and the same if you reopen the app), without needing to
    /// save which ones were chosen.
    var todayQuests: [QuestTemplate] {
        let today = dayNumber()
        let scored = DailyQuests.pool.map { template -> (QuestTemplate, UInt64) in
            var hasher = Hasher()
            hasher.combine(today)
            hasher.combine(template.id)
            return (template, UInt64(bitPattern: Int64(hasher.finalize())))
        }
        return scored.sorted { $0.1 < $1.1 }.prefix(3).map { $0.0 }
    }

    func questProgress(for kind: QuestKind) -> Double {
        switch kind {
        case .harvest: return Double(dailyCropsHarvested)
        case .study: return dailyStudySeconds / 60
        case .tasks: return Double(dailyTasksCompleted)
        case .plant: return Double(dailySeedsPlanted)
        }
    }

    func isQuestClaimed(_ template: QuestTemplate) -> Bool {
        claimedQuestIDs.contains("\(dayNumber()).\(template.id)")
    }

    /// Pays out a finished quest's reward, once per quest per day.
    @discardableResult
    func claimQuest(_ template: QuestTemplate) -> Bool {
        guard !isQuestClaimed(template), questProgress(for: template.kind) >= template.target else { return false }
        claimedQuestIDs.insert("\(dayNumber()).\(template.id)")
        earn(template.reward)
        return true
    }

    /// Call from wherever a to-do task is finished — updates both the lifetime
    /// and the daily-quest counters, then pays out the usual task reward.
    func completeTaskReward() {
        lifetimeTasksCompleted += 1
        dailyTasksCompleted += 1
        earn(CoinReward.bonusPerTask)
    }

    /// Call from wherever a study session ends — updates both the lifetime
    /// and the daily-quest counters, then pays out the session's coins.
    func completeStudySession(seconds: TimeInterval, coins: Int) {
        lifetimeStudySeconds += seconds
        dailyStudySeconds += seconds
        earn(coins)
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
        earn(value)
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
        if info.kind == "seed" { dailySeedsPlanted += 1 }
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
        ensureDailyReset()
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
    /// Returns how many were harvested, plus the most valuable mutation
    /// among them (if any), so the caller can celebrate a lucky pull.
    @discardableResult
    func harvest() -> (count: Int, bestMutation: Mutation?) {
        var updated = tiles
        var n = 0
        var best: Mutation?
        for (key, tile) in tiles where isReady(tile) {
            if let seed = tile.seed {
                let mutation = addHarvestedCrop(seed)
                if mutation != .none, (best == nil || mutation.priceMultiplier > best!.priceMultiplier) {
                    best = mutation
                }
                updated[key] = nil
                n += 1
            }
        }
        if n > 0 {
            tiles = updated
            save()
        }
        return (n, best)
    }

    /// Harvests just the one tile at `key`, if it's ready. Lets the player
    /// pick a single crop instead of collecting everything at once. Returns
    /// the crop's name and the mutation it came out with, if it was ready.
    @discardableResult
    func harvestTile(_ key: String) -> (name: String, mutation: Mutation)? {
        guard let tile = tiles[key], isReady(tile), let seed = tile.seed else { return nil }
        let mutation = addHarvestedCrop(seed)
        tiles[key] = nil
        save()
        return (seed, mutation)
    }

    /// Adds one unit of a harvested crop with its own random weight
    /// (0.7x–1.4x) and a random mutation, which together change how much it
    /// sells for. Returns the mutation it came out with.
    @discardableResult
    private func addHarvestedCrop(_ seed: String) -> Mutation {
        let id = "crop:\(seed)"
        add(id)
        let mutation = Mutation.random()
        cropHarvests[id, default: []].append(HarvestedUnit(weight: Double.random(in: 0.7...1.4), mutation: mutation))
        lifetimeCropsHarvested += 1
        dailyCropsHarvested += 1
        if mutation != .none {
            // Kept forever (for the Mutation Dex) even after this particular
            // crop is sold — discovery, not current stock.
            discoveredMutations.insert("\(seed)|\(mutation.rawValue)")
        }
        checkAchievements()
        return mutation
    }

    // ---- selling via the drag-to-tray Sell screen ----
    /// Pulls one unit of `id` out of inventory for the sell tray. Returns its
    /// weight (1.0 for anything that isn't a crop), its mutation, and the
    /// price it would sell for right now — or nil if there isn't one, or it
    /// can't be sold.
    func takeForTray(_ id: String) -> (weight: Double, mutation: Mutation, unitPrice: Int)? {
        guard count(id) > 0, let base = sellValue(id) else { return nil }
        let info = ItemInfo(id: id)
        var weight = 1.0
        var mutation = Mutation.none
        if info.kind == "crop" {
            var q = cropHarvests[id] ?? []
            if !q.isEmpty {
                let unit = q.removeFirst()
                weight = unit.weight
                mutation = unit.mutation
                cropHarvests[id] = q
            }
        }
        remove(id)
        let unitPrice = info.kind == "crop"
            ? max(1, Int((Double(base) * weight * mutation.priceMultiplier).rounded()))
            : base
        save()
        return (weight, mutation, unitPrice)
    }

    /// Puts an item taken for the tray back into inventory (the player
    /// removed it from the tray before selling).
    func returnFromTray(_ id: String, weight: Double, mutation: Mutation = .none) {
        add(id)
        if ItemInfo(id: id).kind == "crop" {
            cropHarvests[id, default: []].insert(HarvestedUnit(weight: weight, mutation: mutation), at: 0)
        }
        save()
    }
}
