//
//  Backgrounds.swift
//  challenge3todolist
//
//  Shared garden backgrounds and fade-in helpers used by the tabs.
//

import SwiftUI

/// The interactive garden shown behind the Home tab.
struct GardenBackground: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        ZStack {
            GardenPlot(offset: .zero)

            // The seeds, fruits and sprinklers planted in the garden
            ForEach(store.tiles.keys.sorted(), id: \.self) { key in
                if let tile = store.tiles[key] {
                    let spot = tileCoords(key)
                    TileContent(tile: tile, speed: store.speed(forKey: key))
                        .position(
                            x: (CGFloat(spot.col) + 0.5) * Theme.tileSize,
                            y: (CGFloat(spot.row) + 0.5) * Theme.tileSize
                        )
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// The same garden as the Home tab, used behind the other tabs.
struct AppBackground: View {
    var body: some View {
        GardenPlot(offset: .zero)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Fades and lifts content in, staggered by `order`.
private struct FadeIn: ViewModifier {
    let order: Int
    @Environment(\.tabIsVisible) private var tabIsVisible
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onChange(of: tabIsVisible, initial: true) { _, visible in
                if visible {
                    withAnimation(.easeOut(duration: 0.4).delay(Double(order) * 0.08)) { shown = true }
                } else {
                    shown = false
                }
            }
    }
}

/// Lets a tab's root view tell its `fadeIn` children when it appears.
private struct TabIsVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var tabIsVisible: Bool {
        get { self[TabIsVisibleKey.self] }
        set { self[TabIsVisibleKey.self] = newValue }
    }
}

private struct TabFadeRoot: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .environment(\.tabIsVisible, visible)
            .onAppear { visible = true }
            .onDisappear { visible = false }
    }
}

extension View {
    /// Staggered fade-in for a piece of content; `order` sets the delay.
    func fadeIn(order: Int) -> some View {
        modifier(FadeIn(order: order))
    }

    /// Mark a tab's root so its `fadeIn` children replay each time the tab appears.
    func tabFadeRoot() -> some View {
        modifier(TabFadeRoot())
    }
}
