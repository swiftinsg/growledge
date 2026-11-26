//
//  AdminMode.swift
//  challenge3todolist
//
//  A password-protected helper mode for testing: free seeds, instant growth
//  and extra coins. Open it by pressing and holding the coin counter.
//
//  This is a convenience for the developers, not real security: anyone who
//  can read the app's code could find the password's hash. It is never saved,
//  so admin mode switches itself off every time the app restarts.
//

import SwiftUI
import CryptoKit
import Combine

@MainActor
final class AdminMode: ObservableObject {
    static let shared = AdminMode()

    /// SHA-256 of the password (the password itself is not stored in the app).
    /// To change it: `printf '%s' 'new-password' | shasum -a 256`
    static let passwordHash = "8b65ff450c04fc4731a1c2c0f18e9dd08967750df5d5892c5f804f51f58015ed"

    /// True once the right password was entered. Deliberately not persisted.
    @Published private(set) var isActive = false

    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func isCorrect(_ password: String) -> Bool {
        hash(password) == passwordHash
    }

    /// Switches admin mode on if the password is right.
    @discardableResult
    func unlock(password: String) -> Bool {
        guard Self.isCorrect(password) else { return false }
        isActive = true
        return true
    }

    func lock() { isActive = false }
}

extension GameStore {
    /// What a shop item costs right now: nothing in admin mode.
    func effectivePrice(_ price: Int) -> Int {
        AdminMode.shared.isActive ? 0 : price
    }

    /// Adds `count` of every seed (the regular ones and any running event's).
    func adminGiveAllSeeds(count: Int) {
        let crops = Catalog.crops + Catalog.availableEventCrops
        for crop in crops {
            inventory["seed:\(crop.name)", default: 0] += count
        }
        save()
    }

    /// Makes every planted crop ready to harvest right now.
    func adminGrowAll() {
        for (key, tile) in tiles {
            guard let seed = tile.seed, let crop = Catalog.cropByName[seed] else { continue }
            var grown = tile
            grown.progress = crop.growSeconds
            tiles[key] = grown
        }
        save()
    }

    /// Free coins that don't count toward the "coins earned" achievement.
    func adminAddCoins(_ amount: Int) {
        points += amount
        save()
    }
}

/// The password prompt, then (once unlocked) the admin tools.
struct AdminSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var admin = AdminMode.shared
    @ObservedObject private var store = GameStore.shared
    @State private var password = ""
    @State private var wrong = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if admin.isActive { tools } else { login }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private var login: some View {
        Form {
            Section("Password") {
                SecureField("Enter the admin password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(tryUnlock)
                if wrong {
                    Text("Wrong password").foregroundStyle(.red)
                }
            }
            Button("Unlock", action: tryUnlock)
                .disabled(password.isEmpty)
        }
    }

    private var tools: some View {
        Form {
            Section("Seeds") {
                Text("Admin mode is on: every seed in the shop is free and never sold out.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Give 10 of every seed") {
                    store.adminGiveAllSeeds(count: 10)
                    message = "Added 10 of every seed."
                }
                Button("Grow every planted crop now") {
                    store.adminGrowAll()
                    message = "All crops are ready to harvest."
                }
            }
            Section("Coins") {
                Button("Add \(Theme.coin) 1,000,000") {
                    store.adminAddCoins(1_000_000)
                    message = "Added 1,000,000 coins."
                }
            }
            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
            Section {
                Button("Turn admin mode off", role: .destructive) {
                    admin.lock()
                    password = ""
                    message = nil
                }
            }
        }
    }

    private func tryUnlock() {
        wrong = !admin.unlock(password: password)
        password = ""
    }
}
