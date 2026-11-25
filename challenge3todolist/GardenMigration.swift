//
//  GardenMigration.swift
//  challenge3todolist
//
//  Turns a garden saved before the mythical-fruit rework into the new
//  fruits, so nobody loses their plants, seeds or crops.
//

import Foundation

enum GardenMigration {
    /// Seeds and crops in the bag, under their current names (counts add up
    /// when several old crops turn into the same new one).
    static func inventory(_ old: [String: Int]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (id, count) in old { result[Catalog.currentItemID(for: id), default: 0] += count }
        return result
    }

    /// The weights and mutations of harvested crops, under current names.
    static func harvests(_ old: [String: [HarvestedUnit]]) -> [String: [HarvestedUnit]] {
        var result: [String: [HarvestedUnit]] = [:]
        for (id, units) in old { result[Catalog.currentItemID(for: id), default: []] += units }
        return result
    }

    /// Planted tiles, with each seed under its current name.
    static func tiles(_ old: [String: Tile], now: Date = Date()) -> [String: Tile] {
        fitToGrid(renamed(old, now: now))
    }

    /// Plants saved in a bigger garden than today's fixed grid are moved into
    /// empty plots inside it (top row first). If the grid is full they stay
    /// where they were rather than being lost.
    static func fitToGrid(_ tiles: [String: Tile]) -> [String: Tile] {
        func inside(_ key: String) -> Bool {
            let c = tileCoords(key); return Theme.isInGarden(col: c.col, row: c.row)
        }
        var result = tiles.filter { inside($0.key) }
        let strays = tiles.keys.filter { !inside($0) }.sorted {
            let a = tileCoords($0), b = tileCoords($1)
            return a.row == b.row ? a.col < b.col : a.row < b.row
        }
        var free = (0..<Theme.gardenRows).flatMap { r in (0..<Theme.gardenCols).map { c in tileKey(c, r) } }
            .filter { result[$0] == nil }
            .makeIterator()
        var next = free.next()
        for key in strays {
            if let spot = next, let tile = tiles[key] { result[spot] = tile; next = free.next() }
            else { result[key] = tiles[key] }
        }
        return result
    }

    private static func renamed(_ old: [String: Tile], now: Date) -> [String: Tile] {
        old.mapValues { tile in
            var tile = tile
            if let seed = tile.seed { tile.seed = Catalog.currentCropName(for: seed) }
            // Sprinklers saved before they could run out get a fresh full duration
            if let tier = tile.sprinkler, tile.sprinklerEnds == nil, let sp = Catalog.sprinkler(tier: tier) {
                tile.sprinklerEnds = now.addingTimeInterval(sp.duration)
            }
            return tile
        }
    }

    /// "cropName|mutation" entries of the Mutation Dex, under current names.
    static func discoveredMutations(_ old: Set<String>) -> Set<String> {
        Set(old.map { entry in
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return entry }
            return "\(Catalog.currentCropName(for: parts[0]))|\(parts[1])"
        })
    }
}
