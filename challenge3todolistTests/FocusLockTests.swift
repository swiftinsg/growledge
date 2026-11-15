import Foundation
import Testing
import FamilyControls
@testable import challenge3todolist

@MainActor
struct FocusLockTests {
    /// A throw-away UserDefaults so tests never touch the app's real settings.
    private func makeDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func appsAreOnlyBlockedWhenEverythingIsInPlace() {
        for enabled in [false, true] {
            for authorized in [false, true] {
                for hasSelection in [false, true] {
                    let expected = enabled && authorized && hasSelection
                    #expect(FocusLock.shouldLock(enabled: enabled,
                                                 authorized: authorized,
                                                 hasSelection: hasSelection) == expected)
                }
            }
        }
    }

    @Test func aFreshLockIsOffAndHasNothingChosen() {
        let lock = FocusLock(defaults: makeDefaults())

        #expect(!lock.isEnabled)
        #expect(!lock.hasSelection)
        #expect(!lock.isReady)
    }

    @Test func lockIsNotReadyWithoutPermissionOrApps() {
        let lock = FocusLock(defaults: makeDefaults())
        lock.isEnabled = true

        // Nothing chosen (and no Screen Time permission in tests) -> never blocks
        #expect(!lock.isReady)
    }

    @Test func switchStateIsSavedBetweenLaunches() {
        let defaults = makeDefaults()
        FocusLock(defaults: defaults).isEnabled = true

        #expect(FocusLock(defaults: defaults).isEnabled)
    }

    @Test func emptyChoiceIsSavedAndLoadedBack() {
        let defaults = makeDefaults()
        let first = FocusLock(defaults: defaults)
        first.selection = FamilyActivitySelection()

        let second = FocusLock(defaults: defaults)
        #expect(!second.hasSelection)
        #expect(second.selection.applicationTokens.isEmpty)
    }
}
