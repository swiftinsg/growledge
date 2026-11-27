//
//  BulkActions.swift
//  challenge3todolist
//
//  "Plant all" and "Sell all" — the one-tap versions of dragging seeds onto
//  the garden one by one and dragging crops into the sell tray one by one.
//

import Foundation

extension GameStore {
    // MARK: - Plant all

    /// The seeds in the bag, in the same order the inventory bar shows them.
    var seedsInBag: [String] {
        sortedInventory.filter { ItemInfo(id: $0).kind == "seed" && count($0) > 0 }
    }

    /// Plants seeds from the bag onto the empty spots in `cells`, in order,
    /// until either the seeds or the spots run out. Occupied spots are
    /// skipped. Returns how many seeds were planted.
    @discardableResult
    func plantAll(in cells: [(col: Int, row: Int)]) -> Int {
        var seeds = seedsInBag
        var planted = 0
        for cell in cells {
            guard let id = seeds.first else { break }
            if place(id, col: cell.col, row: cell.row) {
                planted += 1
                if count(id) == 0 { seeds.removeFirst() }
            }
        }
        return planted
    }

    // MARK: - Sell all

    /// What every crop in the bag would sell for right now, worked out the
    /// same way as selling them one at a time (weight and mutation count).
    func allCropsSaleSummary() -> (count: Int, total: Int) {
        var count = 0
        var total = 0
        for id in sortedInventory where ItemInfo(id: id).kind == "crop" {
            let sale = cropSale(id)
            count += sale.count
            total += sale.total
        }
        return (count, total)
    }

    /// Sells every crop in the bag at once and pays out the total. Seeds and
    /// sprinklers are never sold. Returns what was sold and the coins earned.
    @discardableResult
    func sellAllCrops() -> (count: Int, total: Int) {
        var count = 0
        var total = 0
        for id in sortedInventory where ItemInfo(id: id).kind == "crop" {
            let sale = cropSale(id)
            count += sale.count
            total += sale.total
            inventory[id] = nil
            cropHarvests[id] = nil
        }
        guard count > 0 else { return (0, 0) }
        earn(total)   // also saves
        return (count, total)
    }

    /// How many of one crop are in the bag and what they are worth together.
    private func cropSale(_ id: String) -> (count: Int, total: Int) {
        let owned = count(id)
        guard owned > 0, let base = sellValue(id) else { return (0, 0) }
        let units = cropHarvests[id] ?? []
        var total = 0
        for unit in units.prefix(owned) {
            total += max(1, Int((Double(base) * unit.weight * unit.mutation.priceMultiplier).rounded()))
        }
        // Crops with no saved weight (very old saves) sell at the base price.
        total += max(0, owned - units.count) * base
        return (owned, total)
    }
}
