//
//  Backgrounds.swift
//  challenge3todolist
//
//  Shared garden backgrounds and fade-in helpers used by the tabs.
//

import SwiftUI

/// Draws the planted tiles (seeds, fruits, sprinklers) at the right spot on
/// screen. Shared by the Home background and the Garden game itself, so the
/// two can never drift out of sync with each other.
struct GardenTilesLayer: View {
    @ObservedObject var store: GameStore
    var offset: CGSize = .zero
    /// When set, tapping a ready tile harvests just that one crop.
    var onTapTile: ((String) -> Void)? = nil

    var body: some View {
        ForEach(store.tiles.keys.sorted(), id: \.self) { key in
            if let tile = store.tiles[key] {
                let spot = tileCoords(key)
                TileContent(tile: tile, speed: store.speed(forKey: key))
                    .position(
                        x: (CGFloat(spot.col) + 0.5) * Theme.tileSize + offset.width,
                        y: (CGFloat(spot.row) + 0.5) * Theme.tileSize + offset.height
                    )
                    .onTapGesture {
                        guard store.isReady(tile) else { return }
                        onTapTile?(key)
                    }
                    .allowsHitTesting(onTapTile != nil)
            }
        }
    }
}

/// The interactive garden shown behind the Home tab.
struct GardenBackground: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        ZStack {
            GardenPlot(offset: .zero)
            GardenTilesLayer(store: store)
        }
        .ignoresSafeArea()
        // Catch the garden up the moment the Home tab appears, so it never
        // looks frozen after time spent on another tab.
        .onAppear {
            store.advance()
            MusicPlayer.shared.playPlaylist(Music.gardenPlaylist)
        }
        .onDisappear {
            MusicPlayer.shared.fadeOutAndStop()
        }
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
