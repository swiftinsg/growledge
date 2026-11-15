import Foundation
import Testing
@testable import challenge3todolist

/// The tests change `GameStore.tiles` in memory only, and call `tick` just a
/// few times (it saves every 20th tick), so the app's saved garden is not touched.
@MainActor
struct GardenGrowthTests {
    private let carrotGrowSeconds = Catalog.cropByName["carrot"]!.growSeconds

    @Test func plantGrowsByTheTimePassed() {
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: "carrot")]

        store.tick(10)

        #expect(store.tiles["1,1"]?.progress == 10)
    }

    @Test func neighbouringSprinklerSpeedsGrowthUp() {
        let store = GameStore()
        store.tiles = [
            "1,1": Tile(seed: "carrot"),
            "0,1": Tile(sprinkler: 1)               // tier 1 = 1.5x
        ]

        store.tick(10)

        #expect(store.tiles["1,1"]?.progress == 15)
        #expect(store.tiles["0,1"]?.progress == 0)  // sprinklers don't grow
    }

    @Test func sprinklerTooFarAwayDoesNothing() {
        let store = GameStore()
        store.tiles = [
            "1,1": Tile(seed: "carrot"),
            "3,3": Tile(sprinkler: 5)
        ]

        #expect(store.speed(forKey: "1,1") == 1)
    }

    @Test func sprinklersDoNotStackTheBestOneWins() {
        let store = GameStore()
        store.tiles = [
            "1,1": Tile(seed: "carrot"),
            "0,0": Tile(sprinkler: 1),
            "2,2": Tile(sprinkler: 2)               // tier 2 = 2x
        ]

        #expect(store.speed(forKey: "1,1") == 2)
    }

    @Test func growthStopsWhenThePlantIsReady() {
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: "carrot")]

        store.tick(carrotGrowSeconds * 10)

        #expect(store.tiles["1,1"]?.progress == carrotGrowSeconds)
        #expect(store.isReady(store.tiles["1,1"]!))
    }

    @Test func plantIsNotReadyBeforeItIsFullyGrown() {
        let store = GameStore()
        let almost = Tile(seed: "carrot", progress: carrotGrowSeconds - 1)

        #expect(!store.isReady(almost))
        #expect(store.isReady(Tile(seed: "carrot", progress: carrotGrowSeconds)))
    }

    @Test func emptyTilesAndSprinklersAreNeverReady() {
        let store = GameStore()
        #expect(!store.isReady(Tile()))
        #expect(!store.isReady(Tile(sprinkler: 3, progress: 1_000_000)))
    }

    @Test func unknownSeedsAreIgnoredInsteadOfCrashing() {
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: "not-a-crop")]

        store.tick(10)

        #expect(store.tiles["1,1"]?.progress == 0)
    }

    @Test func zeroTimePassedChangesNothing() {
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: "carrot", progress: 5)]

        store.tick(0)

        #expect(store.tiles["1,1"]?.progress == 5)
    }
}

@MainActor
struct WeatherTests {
    private func drop(opacity: Double) -> RainDrop {
        RainDrop(x: 0, speed: 1, length: 1, phase: 0, opacity: opacity)
    }

    @Test func dropsAreSplitIntoThreeBrightnessGroups() {
        let range = 0.0...1.0
        #expect(drop(opacity: 0.0).group(in: range) == 0)
        #expect(drop(opacity: 0.32).group(in: range) == 0)
        #expect(drop(opacity: 0.5).group(in: range) == 1)
        #expect(drop(opacity: 0.67).group(in: range) == 2)
        #expect(drop(opacity: 1.0).group(in: range) == 2)   // the top edge stays in range
    }

    @Test func valuesOutsideTheRangeAreClamped() {
        #expect(drop(opacity: -1).group(in: 0.0...1.0) == 0)
        #expect(drop(opacity: 5).group(in: 0.0...1.0) == 2)
    }

    @Test func everyRainDropFallsInAValidGroup() {
        for rain in RainLayer.drops {
            #expect((0...2).contains(rain.group(in: RainLayer.opacityRange)))
        }
        #expect(RainLayer.drops.count == Theme.rainDropCount)
    }
}

@MainActor
struct CatalogTests {
    @Test func cropNamesAreUnique() {
        #expect(Set(Catalog.cropNames).count == Catalog.cropNames.count)
        #expect(Catalog.cropByName.count == Catalog.cropNames.count)
    }

    @Test func pricesAndGrowthTimesGoUpAlongTheList() {
        let crops = Catalog.crops
        for (earlier, later) in zip(crops, crops.dropFirst()) {
            #expect(later.price >= earlier.price)
            #expect(later.growSeconds >= earlier.growSeconds)
        }
    }

    @Test func listSpansTheConfiguredRange() {
        #expect(Catalog.crops.first?.price == 10)
        #expect(Catalog.crops.first?.growSeconds == Catalog.minGrowSeconds)
        #expect(Catalog.crops.last?.price == 1_000_000_000)
        #expect(Catalog.crops.last?.growSeconds == Catalog.maxGrowSeconds)
    }

    @Test func sprinklerTiersAreFoundByTier() {
        #expect(Catalog.sprinkler(tier: 1)?.name == "Tiny Sprinkler")
        #expect(Catalog.sprinkler(tier: 99) == nil)
    }
}

@MainActor
struct TaskModelTests {
    @Test func noSubjectIsGreyWithAStableId() {
        #expect(Subject.none.color == .gray)
        #expect(Subject.none.id == UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    }

    @Test func greyIsNotOfferedWhenCreatingASubject() {
        #expect(!SubjectColor.choices.contains(.gray))
        #expect(SubjectColor.choices.count == SubjectColor.allCases.count - 1)
    }

    @Test func newTaskStartsUnfinishedAndUnpaid() {
        let task = Reminder(title: "Read", dueDate: .now, subject: .none)
        #expect(!task.isCompleted)
        #expect(!task.rewarded)
    }
}
