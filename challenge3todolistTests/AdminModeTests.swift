import Testing
@testable import challenge3todolist

@MainActor
@Suite(.serialized)
struct AdminModeTests {
    @Test func wrongPasswordStaysLocked() {
        let admin = AdminMode()
        #expect(!admin.unlock(password: "nope"))
        #expect(!admin.unlock(password: ""))
        #expect(!admin.isActive)
    }

    @Test func rightPasswordUnlocksAndLockTurnsOff() {
        let admin = AdminMode()
        #expect(admin.unlock(password: "growledge-admin"))
        #expect(admin.isActive)
        admin.lock()
        #expect(!admin.isActive)
    }

    @Test func passwordIsCaseSensitive() {
        #expect(!AdminMode.isCorrect("Growledge-Admin"))
    }

    @Test func adminMakesSeedsFreeAndAlwaysInStock() {
        let store = GameStore.shared
        let crop = Catalog.crops[0]
        let id = "seed:\(crop.name)"
        AdminMode.shared.lock()
        #expect(store.effectivePrice(crop.price) == crop.price)

        AdminMode.shared.unlock(password: "growledge-admin")
        defer { AdminMode.shared.lock() }
        #expect(store.effectivePrice(crop.price) == 0)
        #expect(store.stockToday(id: id, price: crop.price) > 0)

        let before = store.points
        let owned = store.count(id)
        #expect(store.buy(id, price: crop.price))
        #expect(store.points == before)
        #expect(store.count(id) == owned + 1)
    }

    @Test func giveAllSeedsAddsEverySeed() {
        let store = GameStore.shared
        let before = store.count("seed:\(Catalog.crops[0].name)")
        store.adminGiveAllSeeds(count: 3)
        for crop in Catalog.crops {
            #expect(store.count("seed:\(crop.name)") >= 3)
        }
        #expect(store.count("seed:\(Catalog.crops[0].name)") == before + 3)
    }
}
