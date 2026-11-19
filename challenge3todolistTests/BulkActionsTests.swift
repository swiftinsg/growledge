import Testing
@testable import challenge3todolist

/// These use a throwaway `GameStore` with its own in-memory garden and bag.
@MainActor
@Suite(.serialized)
struct BulkActionsTests {
    private func emptyStore() -> GameStore {
        let store = GameStore()
        store.tiles = [:]
        store.inventory = [:]
        store.cropHarvests = [:]
        return store
    }

    private func cells(_ n: Int) -> [(col: Int, row: Int)] {
        (0..<n).map { (col: $0, row: 0) }
    }

    @Test func plantAllFillsEmptySpotsAndUsesUpSeeds() {
        let store = emptyStore()
        store.inventory = ["seed:carrot": 3]
        #expect(store.plantAll(in: cells(5)) == 3)
        #expect(store.tiles.count == 3)
        #expect(store.count("seed:carrot") == 0)
    }

    @Test func plantAllStopsWhenSpotsRunOut() {
        let store = emptyStore()
        store.inventory = ["seed:carrot": 5]
        #expect(store.plantAll(in: cells(2)) == 2)
        #expect(store.count("seed:carrot") == 3)
    }

    @Test func plantAllSkipsTakenSpotsAndLeavesGearAlone() {
        let store = emptyStore()
        store.tiles = ["0,0": Tile(seed: "carrot")]
        store.inventory = ["seed:carrot": 2, "gear:1": 1]
        #expect(store.plantAll(in: cells(3)) == 2)
        #expect(store.tiles["0,0"]?.seed == "carrot")
        #expect(store.tiles["1,0"]?.seed == "carrot")
        #expect(store.tiles["2,0"]?.seed == "carrot")
        #expect(store.count("gear:1") == 1)
    }

    @Test func plantAllWithNoSeedsPlantsNothing() {
        let store = emptyStore()
        #expect(store.plantAll(in: cells(3)) == 0)
        #expect(store.tiles.isEmpty)
    }

    @Test func sellAllSellsEveryCropButKeepsSeedsAndGear() {
        let store = emptyStore()
        let base = store.sellValue("crop:carrot")!
        store.inventory = ["crop:carrot": 2, "seed:carrot": 4, "gear:1": 1]
        store.cropHarvests = ["crop:carrot": [
            HarvestedUnit(weight: 1.0, mutation: .none),
            HarvestedUnit(weight: 2.0, mutation: .none)
        ]]
        let summary = store.allCropsSaleSummary()
        #expect(summary.count == 2)
        #expect(summary.total == base + base * 2)

        let before = store.points
        let sold = store.sellAllCrops()
        #expect(sold.count == 2)
        #expect(sold.total == summary.total)
        #expect(store.points == before + sold.total)
        #expect(store.count("crop:carrot") == 0)
        #expect(store.cropHarvests["crop:carrot"] == nil)
        #expect(store.count("seed:carrot") == 4)
        #expect(store.count("gear:1") == 1)
    }

    @Test func sellAllWithNoCropsDoesNothing() {
        let store = emptyStore()
        store.inventory = ["seed:carrot": 1]
        let before = store.points
        #expect(store.sellAllCrops().count == 0)
        #expect(store.points == before)
    }
}
