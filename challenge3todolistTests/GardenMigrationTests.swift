import Foundation
import Testing
import UIKit
@testable import challenge3todolist

/// Gardens saved before the mythical-fruit rework must keep working.
@MainActor
struct GardenMigrationTests {
    @Test func oldCropNamesBecomeCurrentCrops() {
        for old in ["carrot", "apple", "doge", "tung tung tung sahur", "carterpcs", "pumpkin", "pumpkin t"] {
            #expect(Catalog.cropByName[Catalog.currentCropName(for: old)] != nil, "\(old) should map to a real crop")
        }
    }

    @Test func theCheapestAndPriciestKeepTheirPlace() {
        #expect(Catalog.currentCropName(for: "carrot") == Catalog.cropNames.first)
        #expect(Catalog.currentCropName(for: "carterpcs") == Catalog.cropNames.last)
    }

    @Test func currentNamesAndUnknownNamesAreLeftAlone() {
        let current = Catalog.cropNames[3]
        #expect(Catalog.currentCropName(for: current) == current)
        #expect(Catalog.currentCropName(for: "made up") == "made up")
        #expect(Catalog.currentItemID(for: "gear:3") == "gear:3")
        #expect(Catalog.currentItemID(for: "seed:carrot") == "seed:\(Catalog.cropNames[0])")
    }

    @Test func savedBagTilesAndHarvestsAreConverted() {
        let first = Catalog.cropNames[0]
        let bag = GardenMigration.inventory(["seed:carrot": 2, "crop:carrot": 1, "gear:2": 4])
        #expect(bag["seed:\(first)"] == 2)
        #expect(bag["crop:\(first)"] == 1)
        #expect(bag["gear:2"] == 4)

        let tiles = GardenMigration.tiles(["1,1": Tile(seed: "carrot", progress: 5), "2,2": Tile(sprinkler: 1)])
        #expect(tiles["1,1"]?.seed == first)
        #expect(tiles["1,1"]?.progress == 5)
        #expect(tiles["2,2"]?.sprinkler == 1)

        let harvests = GardenMigration.harvests(["crop:carrot": [HarvestedUnit(weight: 1.2, mutation: .gold)]])
        #expect(harvests["crop:\(first)"]?.first?.mutation == .gold)

        let dex = GardenMigration.discoveredMutations(["carrot|gold"])
        #expect(dex == ["\(first)|gold"])
    }

    @Test func manyOldCropsMergingIntoOneAddUp() {
        // "carrot" and "cabbage" are the two cheapest, so both become the cheapest fruit or one step up;
        // the total never changes.
        let bag = GardenMigration.inventory(["seed:carrot": 2, "seed:cabbage": 3])
        #expect(bag.values.reduce(0, +) == 5)
    }
}

struct CatalogArtTests {
    @Test func everyCropHasAUniqueNameAndLooks() {
        let all = Catalog.crops + Catalog.halloweenCrops + Catalog.christmasCrops
        #expect(Set(all.map(\.name)).count == all.count)
    }

    @Test func noMemeNamesAreLeftInTheShop() {
        let banned = ["doge", "obama", "trump", "ronaldo", "ishowspeed", "sahur", "patapim", "skibidi", "brainrot"]
        for crop in Catalog.crops + Catalog.halloweenCrops + Catalog.christmasCrops {
            for word in banned { #expect(!crop.name.contains(word)) }
        }
    }

    @Test func everyPixelPictureNamedInTheCatalogExists() {
        for crop in Catalog.crops {
            guard let art = crop.art else { continue }
            for name in [art.seed, art.fruit, art.sapling, art.tree].compactMap({ $0 }) {
                #expect(UIImage(named: name) != nil, "\(crop.name): missing picture \(name)")
            }
        }
    }
}
