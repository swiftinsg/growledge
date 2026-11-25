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
    /// When set, tapping a plant tells the caller (to harvest it, or to show
    /// how long it has left).
    var onTapTile: ((String) -> Void)? = nil

    private func center(_ key: String) -> CGPoint {
        let spot = tileCoords(key)
        return CGPoint(x: (CGFloat(spot.col) + 0.5) * Theme.tileSize + offset.width,
                       y: (CGFloat(spot.row) + 0.5) * Theme.tileSize + offset.height)
    }

    /// Top row first, so a tall tree in a lower row is drawn in front of the
    /// one above it.
    private var orderedKeys: [String] {
        store.tiles.keys.sorted {
            let a = tileCoords($0), b = tileCoords($1)
            return a.row == b.row ? a.col < b.col : a.row < b.row
        }
    }

    var body: some View {
        ZStack {
            // The area each working sprinkler waters (under the plants)
            ForEach(orderedKeys.filter { store.tiles[$0]?.sprinkler != nil }, id: \.self) { key in
                if let tile = store.tiles[key], let tier = tile.sprinkler, let sp = Catalog.sprinkler(tier: tier) {
                    SprinklerArea(sprinkler: sp, timeLeft: store.sprinklerTimeLeft(tile))
                        .position(center(key))
                        .allowsHitTesting(false)
                }
            }

            // The plants themselves, and nothing else
            ForEach(orderedKeys.filter { store.tiles[$0]?.seed != nil }, id: \.self) { key in
                if let tile = store.tiles[key] {
                    TileContent(tile: tile)
                        .contentShape(Rectangle())
                        .position(center(key))
                        .onTapGesture { onTapTile?(key) }
                        .allowsHitTesting(onTapTile != nil)
                }
            }

            // How long each plant still needs, just below it (on top of everything)
            ForEach(orderedKeys.filter { store.tiles[$0]?.seed != nil }, id: \.self) { key in
                if let tile = store.tiles[key], let crop = Catalog.cropByName[tile.seed ?? ""] {
                    GrowTimeLabel(timeLeft: store.isReady(tile) ? nil
                                  : (crop.growSeconds - tile.progress) / max(store.speed(forKey: key), 0.01),
                                  speed: store.speed(forKey: key))
                        .position(x: center(key).x, y: center(key).y + Theme.tileSize / 2 - 9)
                        .allowsHitTesting(false)
                }
            }

            // Tapping a sprinkler's middle plot shows how long it has left
            ForEach(orderedKeys.filter { store.tiles[$0]?.sprinkler != nil }, id: \.self) { key in
                Color.clear
                    .frame(width: Theme.tileSize, height: Theme.tileSize)
                    .contentShape(Rectangle())
                    .position(center(key))
                    .onTapGesture { onTapTile?(key) }
                    .allowsHitTesting(onTapTile != nil)
            }
        }
    }
}

/// "3h 20m" under a growing plant, or "Ready" once it can be harvested.
struct GrowTimeLabel: View {
    let timeLeft: Double?
    /// Growth speed right now (1 = normal). Above 1, a sprinkler or the
    /// weather is speeding the plant up, and the label says so.
    var speed: Double = 1

    private var boosted: Bool { timeLeft != nil && speed > 1.001 }

    var body: some View {
        HStack(spacing: 3) {
            if boosted { Image(systemName: "bolt.fill") }
            Text(timeLeft.map(shortTimeText) ?? "Ready")
            if boosted { Text("×\(speed.formatted(.number.precision(.fractionLength(0...1))))") }
        }
        .font(.system(size: 11, weight: .semibold).monospacedDigit())
        .foregroundStyle(boosted ? Color.black : .white)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(boosted ? Theme.gold : (timeLeft == nil ? Theme.good : Color.black).opacity(0.55)))
    }
}

/// The 3x3 area a sprinkler waters, including a visible sprinkler at its center.
struct SprinklerArea: View {
    let sprinkler: Sprinkler
    let timeLeft: TimeInterval?

    var body: some View {
        let side = Theme.tileSize * 3 - 6
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(sprinkler.color.opacity(0.16))
            RoundedRectangle(cornerRadius: 18)
                .stroke(sprinkler.color.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            VStack(spacing: 2) {
                Image(systemName: "sprinkler.and.droplets.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 2)
                    .padding(8)
                    .background(Circle().fill(sprinkler.color))

                if let timeLeft {
                    Text(shortTimeText(timeLeft))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(sprinkler.color.opacity(0.7)))
                }
            }
        }
        .frame(width: side, height: side)
    }
}

/// The garden shown behind the Home tab. Tapping it opens the full garden game.
struct GardenBackground: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        GeometryReader { geo in
            let offset = Theme.centeredGardenOffset(in: geo.size)
            ZStack {
                GardenPlot(offset: offset)
                GardenTilesLayer(store: store, offset: offset)
            }
        }
        .ignoresSafeArea()
        // Catch the garden up the moment the Home tab appears, so it never
        // looks frozen after time spent on another tab.
        // NOTE: deliberately no music here — Home is just a preview of the
        // garden. Music only starts once the garden is opened (see Game.swift's onAppear).
        .onAppear {
            store.advance()
        }
    }
}

/// The ordinary system background, the same as the Study and History pages,
/// used behind the Hub and its detail pages.
struct AppBackground: View {
    var body: some View {
        Color(.systemBackground)
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
