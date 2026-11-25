import Foundation
import Testing
@testable import challenge3todolist

/// The cheapest, fastest-growing crop, used wherever a test just needs "a crop".
private let firstCrop = Catalog.crops[0].name

/// The tests change `GameStore.tiles` in memory only, and call `tick` just a
/// few times (it saves every 20th tick), so the app's saved garden is not touched.
///
/// Growth speed depends on the weather (rain is faster, snow slower) and rain
/// can bring tornadoes, and the real weather follows the clock. So each test
/// pins the weather first. The pin is global, so these tests run one at a time.
@MainActor
@Suite(.serialized)
struct GardenGrowthTests {
    private let carrotGrowSeconds = Catalog.cropByName[firstCrop]!.growSeconds

    private func pin(_ season: Season = .sunny) { Season.forcedForTests = season }
    private func unpin() { Season.forcedForTests = nil }
    private func isClose(_ a: Double?, _ b: Double) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 1e-9
    }

    @Test func plantGrowsByTheTimePassedTimesTheWeather() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: firstCrop)]

        store.tick(10)

        #expect(isClose(store.tiles["1,1"]?.progress, 10 * Season.sunny.growthMultiplier))
    }

    @Test func neighbouringSprinklerSpeedsGrowthUp() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = [
            "1,1": Tile(seed: firstCrop),
            "0,1": Tile(sprinkler: 1)               // tier 1 = 1.5x
        ]

        store.tick(10)

        #expect(isClose(store.tiles["1,1"]?.progress, 10 * Season.sunny.growthMultiplier * 1.5))
        #expect(store.tiles["0,1"]?.progress == 0)  // sprinklers don't grow
    }

    @Test func sprinklerTooFarAwayDoesNothing() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = [
            "1,1": Tile(seed: firstCrop),
            "3,3": Tile(sprinkler: 5)
        ]

        #expect(isClose(store.speed(forKey: "1,1"), Season.sunny.growthMultiplier))
    }

    @Test func sprinklersDoNotStackTheBestOneWins() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = [
            "1,1": Tile(seed: firstCrop),
            "0,0": Tile(sprinkler: 1),
            "2,2": Tile(sprinkler: 2)               // tier 2 = 2x
        ]

        #expect(isClose(store.speed(forKey: "1,1"), Season.sunny.growthMultiplier * 2))
    }

    @Test func rainSpeedsPlantsUpAndSnowSlowsThemDown() {
        defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: firstCrop)]

        pin(.rainy)
        let rainy = store.speed(forKey: "1,1")
        pin(.sunny)
        let sunny = store.speed(forKey: "1,1")
        pin(.snowy)
        let snowy = store.speed(forKey: "1,1")

        #expect(rainy > sunny)
        #expect(sunny > snowy)
        #expect(sunny > 1)          // even sun is a mild bonus
        #expect(snowy < 1)          // winter is slower than the baseline
    }

    @Test func growthStopsWhenThePlantIsReady() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: firstCrop)]

        store.tick(carrotGrowSeconds * 10)

        #expect(store.tiles["1,1"]?.progress == carrotGrowSeconds)
        #expect(store.isReady(store.tiles["1,1"]!))
    }

    @Test func plantIsNotReadyBeforeItIsFullyGrown() {
        let store = GameStore()
        let almost = Tile(seed: firstCrop, progress: carrotGrowSeconds - 1)

        #expect(!store.isReady(almost))
        #expect(store.isReady(Tile(seed: firstCrop, progress: carrotGrowSeconds)))
    }

    @Test func emptyTilesAndSprinklersAreNeverReady() {
        let store = GameStore()
        #expect(!store.isReady(Tile()))
        #expect(!store.isReady(Tile(sprinkler: 3, progress: 1_000_000)))
    }

    @Test func unknownSeedsAreIgnoredInsteadOfCrashing() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: "not-a-crop")]

        store.tick(10)

        #expect(store.tiles["1,1"]?.progress == 0)
    }

    @Test func zeroTimePassedChangesNothing() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: firstCrop, progress: 5)]

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
        // The regular crops and the limited-time event crops share one lookup,
        // so no name may appear twice anywhere.
        let all = Catalog.crops
        #expect(Set(all.map(\.name)).count == all.count)
        #expect(Catalog.cropByName.count == all.count)
    }

    @Test func everyCropCanBeLookedUpByName() {
        for name in Catalog.cropNames {
            #expect(Catalog.cropByName[name]?.name == name)
        }
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

/// Sprinklers stop working after a while, and better ones last longer.
@MainActor
@Suite(.serialized)
struct SprinklerExpiryTests {
    private func pin() { Season.forcedForTests = .sunny }
    private func unpin() { Season.forcedForTests = nil }
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func betterSprinklersLastLongerAndAreFaster() {
        let durations = Catalog.sprinklers.map(\.duration)
        #expect(durations == durations.sorted())
        #expect(Set(durations).count == durations.count)
        let speeds = Catalog.sprinklers.map(\.speed)
        #expect(speeds == speeds.sorted())
    }

    @Test func placingASprinklerSetsWhenItRunsOut() {
        let store = GameStore()
        store.tiles = [:]
        store.inventory = ["gear:3": 1]
        let before = Date()
        #expect(store.place("gear:3", col: 0, row: 0))
        let ends = store.tiles["0,0"]?.sprinklerEnds
        #expect(ends != nil)
        let expected = Catalog.sprinkler(tier: 3)!.duration
        #expect(abs(ends!.timeIntervalSince(before) - expected) < 5)
    }

    @Test func aWorkingSprinklerBoostsGrowth() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: firstCrop),
                       "0,1": Tile(sprinkler: 1, sprinklerEnds: t0.addingTimeInterval(1000))]
        store.tick(10, now: t0)
        #expect(abs((store.tiles["1,1"]?.progress ?? 0) - 10 * Season.sunny.growthMultiplier * 1.5) < 1e-9)
    }

    @Test func anExpiredSprinklerGivesNoBoostAndDisappears() {
        pin(); defer { unpin() }
        let store = GameStore()
        store.tiles = ["1,1": Tile(seed: firstCrop),
                       "0,1": Tile(sprinkler: 1, sprinklerEnds: t0.addingTimeInterval(-60))]
        store.tick(10, now: t0)
        #expect(abs((store.tiles["1,1"]?.progress ?? 0) - 10 * Season.sunny.growthMultiplier) < 1e-9)
        #expect(store.tiles["0,1"] == nil)
    }

    @Test func aSprinklerThatRanOutHalfWayOnlyCountsForItsWorkingPart() {
        pin(); defer { unpin() }
        let store = GameStore()
        // 10 seconds pass; the sprinkler (1.5x) worked for the first 5 of them
        store.tiles = ["1,1": Tile(seed: firstCrop),
                       "0,1": Tile(sprinkler: 1, sprinklerEnds: t0.addingTimeInterval(-5))]
        store.tick(10, now: t0)
        let expected = 10 * Season.sunny.growthMultiplier * 1.25   // average of 1.5x and 1x
        #expect(abs((store.tiles["1,1"]?.progress ?? 0) - expected) < 1e-9)
    }

    @Test func oldSavedSprinklersGetAFreshDuration() {
        let migrated = GardenMigration.tiles(["0,0": Tile(sprinkler: 2)], now: t0)
        #expect(migrated["0,0"]?.sprinklerEnds == t0.addingTimeInterval(Catalog.sprinkler(tier: 2)!.duration))
    }

    @Test func timeLeftCountsDownToZero() {
        let store = GameStore()
        let tile = Tile(sprinkler: 1, sprinklerEnds: t0.addingTimeInterval(100))
        #expect(store.sprinklerTimeLeft(tile, now: t0) == 100)
        #expect(store.sprinklerTimeLeft(tile, now: t0.addingTimeInterval(500)) == 0)
        #expect(store.sprinklerTimeLeft(Tile(sprinkler: 1), now: t0) == nil)
    }
}

