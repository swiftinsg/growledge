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
    static func tiles(_ old: [String: Tile]) -> [String: Tile] {
        old.mapValues { tile in
            var tile = tile
            if let seed = tile.seed { tile.seed = Catalog.currentCropName(for: seed) }
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
