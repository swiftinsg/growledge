//
//  FocusLock.swift
//  The app
//
//  Blocks the apps the user chose while a focus phase is running (breaks are
//  free). Built on Apple's Screen Time API: FamilyControls to ask permission and
//  pick apps, ManagedSettings to put a "shield" over them.
//

import SwiftUI
import Combine
import FamilyControls
import ManagedSettings

@MainActor
final class FocusLock: ObservableObject {
    static let shared = FocusLock()

    private static let enabledKey = "focusLock.enabled"
    private static let selectionKey = "focusLock.selection"

    private let defaults: UserDefaults

    /// The "Lock apps while focusing" switch.
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { Self.releaseShield() }
        }
    }

    /// The apps, categories and websites the user picked (saved between launches).
    @Published var selection: FamilyActivitySelection {
        didSet { saveSelection() }
    }

    /// Whether the user allowed Screen Time access.
    @Published private(set) var authorization: AuthorizationStatus

    /// A message to show when asking for permission failed.
    @Published var errorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        if let data = defaults.data(forKey: Self.selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - State

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    var isAuthorized: Bool { authorization == .approved }

    /// True when starting a focus phase will really block apps.
    var isReady: Bool {
        Self.shouldLock(enabled: isEnabled, authorized: isAuthorized, hasSelection: hasSelection)
    }

    /// Apps are only blocked when the user switched the lock on, allowed Screen
    /// Time access and picked something to block.
    nonisolated static func shouldLock(enabled: Bool, authorized: Bool, hasSelection: Bool) -> Bool {
        enabled && authorized && hasSelection
    }

    // MARK: - Permission

    func refreshAuthorization() {
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    /// Asks for Screen Time access (the system shows its own prompt).
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            errorMessage = nil
        } catch {
            errorMessage = "Screen Time access wasn't granted. It needs a real iPhone and your permission."
        }
        refreshAuthorization()
    }

    // MARK: - Blocking

    /// Puts the shield over the chosen apps (does nothing unless `isReady`).
    func lock() {
        guard isReady else { return }
        let store = ManagedSettingsStore()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func unlock() {
        Self.releaseShield()
    }

    /// Removes every block. The system keeps the shield after the app closes,
    /// so this is also called at launch: closing the app can never leave the
    /// phone locked.
    nonisolated static func releaseShield() {
        ManagedSettingsStore().clearAllSettings()
    }

    private func saveSelection() {
        defaults.set(try? JSONEncoder().encode(selection), forKey: Self.selectionKey)
    }
}

/// Owned by the timer screen. When that screen goes away for good (the user
/// leaves the Study page), this is released and the apps are unlocked, even
/// if a focus phase was still running.
final class FocusLockSession: ObservableObject {
    deinit {
        FocusLock.releaseShield()
    }
}
