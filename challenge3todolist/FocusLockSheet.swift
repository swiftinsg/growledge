//
//  FocusLockSheet.swift
//  The app
//
//  Settings for locking apps during focus time.
//

import SwiftUI
import FamilyControls

/// Opened from the lock button on the Study page.
struct FocusLockSheet: View {
    @ObservedObject private var lock = FocusLock.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Lock apps while focusing", isOn: enabledBinding)
                } footer: {
                    Text("The apps you choose are blocked during focus time and free again during breaks. Growledge itself is never blocked.")
                }

                if lock.isEnabled {
                    permissionSection
                    appsSection
                }

                Section {
                    Label("Apps unlock when you pause, cancel or end the session, or when a break starts.",
                          systemImage: "lock.open")
                    Label("If you leave Growledge during a focus phase, the apps stay blocked until you open Growledge again after the focus time is over.",
                          systemImage: "info.circle")
                } header: {
                    Text("Good to know")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Focus Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $lock.selection)
            .onAppear { lock.refreshAuthorization() }
        }
        .presentationDetents([.medium, .large])
    }

    /// Turning the lock on asks for Screen Time access straight away.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { lock.isEnabled },
            set: { newValue in
                lock.isEnabled = newValue
                if newValue && !lock.isAuthorized {
                    Task { await lock.requestAuthorization() }
                }
            }
        )
    }

    @ViewBuilder
    private var permissionSection: some View {
        if !lock.isAuthorized {
            Section {
                Button {
                    Task { await lock.requestAuthorization() }
                } label: {
                    Label("Allow Screen Time access", systemImage: "hand.raised")
                }

                if let message = lock.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.footnote)
            } header: {
                Text("Permission needed")
            } footer: {
                Text("iOS needs your permission before an app can block other apps.")
            }
        }
    }

    private var appsSection: some View {
        Section {
            Button {
                showingPicker = true
            } label: {
                HStack {
                    Label("Choose apps to block", systemImage: "square.grid.2x2")
                    Spacer()
                    Text(summary)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!lock.isAuthorized)
        } footer: {
            if lock.isAuthorized && !lock.hasSelection {
                Text("Nothing is blocked until you choose at least one app or category.")
            }
        }
    }

    private var summary: String {
        var parts: [String] = []
        let apps = lock.selection.applicationTokens.count
        let categories = lock.selection.categoryTokens.count
        let sites = lock.selection.webDomainTokens.count

        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if categories > 0 { parts.append(categories == 1 ? "1 category" : "\(categories) categories") }
        if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }

        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }
}

#Preview {
    FocusLockSheet()
        .preferredColorScheme(.dark)
}
