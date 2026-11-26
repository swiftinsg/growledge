//
//  Game.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 5. THE GAME SCREEN  (garden + buttons; the only place for game buttons)
// =====================================================================
enum ShopType: String, Identifiable {
    case seeds = "Seeds"
    case gears = "Gears"
    var id: String { rawValue }
}

// NOTE: Game must be shown inside a NavigationStack (ContentView's home tab
// provides one) so the Buy and Sell navigation links work.
struct Game: View {
    /// Only set when the garden is shown on top of something else; as its own
    /// tab there is nothing to exit.
    var onExit: (() -> Void)? = nil

    @ObservedObject private var store = GameStore.shared
    @State private var plotOffset = CGSize.zero
    @State private var savedOffset = CGSize.zero
    @State private var holding = false
    @State private var hasCentered = false
    @State private var toast: String?
    @State private var dragging: DragInfo?
    @State private var gardenFrame: CGRect = .zero
    @State private var showingBuy = false
    @State private var showingSell = false
    @AppStorage("hasPlantedOnce") private var hasPlantedOnce = false

    var body: some View {
        ZStack {
            // ---------- Garden: ground + plants + rain + drag to move ----------
            ZStack {
                GardenPlot(offset: plotOffset)

                // Tap any ready tile to harvest just that one crop.
                GardenTilesLayer(store: store, offset: plotOffset, onTapTile: harvestOne)

                // Highlight exactly where the dragged plant will land —
                // filled, not just outlined, so it's unmistakable while dragging.
                if let d = dragging, gardenFrame != .zero {
                    let spot = tileAt(d.location)
                    let willFit = Theme.isInGarden(col: spot.col, row: spot.row) && !isOccupied(spot)
                    RoundedRectangle(cornerRadius: 12)
                        .fill((willFit ? Theme.good : Theme.bad).opacity(0.28))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(willFit ? Theme.good : Theme.bad, lineWidth: 3))
                        .frame(width: Theme.tileSize - 6, height: Theme.tileSize - 6)
                        .position(
                            x: (CGFloat(spot.col) + 0.5) * Theme.tileSize + plotOffset.width,
                            y: (CGFloat(spot.row) + 0.5) * Theme.tileSize + plotOffset.height
                        )
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
            .readFrame($gardenFrame)
            .onChange(of: gardenFrame.size) { _, size in
                // Start at the top of the garden, inside the panning limits.
                guard size != .zero, !hasCentered else { return }
                hasCentered = true
                plotOffset = clamped(CGSize(width: 0, height: 80))
                savedOffset = plotOffset
            }
            .simultaneousGesture(panGesture)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            store.advance()
            // Music only plays while you're actually in the garden game —
            // not on the Home tab behind it.
            MusicPlayer.shared.playPlaylist(Music.gardenPlaylist)
        }
        .onDisappear {
            store.save()
            // Leaving the game back to Home should leave things quiet again.
            MusicPlayer.shared.fadeOutAndStop()
        }
        


        // One-time nudge until the player plants their first seed.
        .overlay(alignment: .bottom) {
            if !hasPlantedOnce && dragging == nil {
                Label("Press and drag a seed from the right onto the garden to plant it", systemImage: "hand.draw.fill")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.card.opacity(0.95)))
                    .overlay(Capsule().stroke(Theme.panelBorder, lineWidth: 1))
                    .padding(.horizontal, 60)
                    .padding(.bottom, 170)
                    .transition(.opacity)
            }
        }

        // ==================================================
        // BUTTONS AND HUD: each .overlay is one spot on screen
        // ==================================================

        // Exit (top left)
        .overlay(alignment: .topLeading) {
            if let onExit {
                GameButton(icon: "xmark", width: 50, height: 50) { onExit() }
                    .padding()
            }
        }

        // Weather readout (top right)
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                // Read-only — the weather changes on its own, nobody picks it.
                WeatherBadge()
            }
            .padding()
        }

        // Points + messages (top center)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                PointsPill()
                if let toast {
                    Text(toast)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.card.opacity(0.95)))
                        .overlay(Capsule().stroke(Theme.panelBorder, lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.top, 12)
        }

        // Inventory bar (right side)
        .overlay(alignment: .trailing) {
            InventoryBar(dragging: $dragging, onPlantAll: { plantAll() }) { id, point in
                plant(id, atGlobal: point)
            }
            .padding(.trailing, 6)
            .padding(.top, 90)
            .padding(.bottom, 150)
        }

        // Harvest: press and HOLD (bottom left)
        .overlay(alignment: .bottomLeading) {
            ButtonLook(title: "Hold to Harvest All", icon: "hand.tap.fill", width: 220, height: 56)
                .overlay(alignment: .topTrailing) {
                    if store.readyCount > 0 {
                        Text("\(store.readyCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(Theme.good))
                            .offset(x: 8, y: -8)
                    }
                }
                .scaleEffect(holding ? 0.92 : 1)
                .animation(.spring(duration: 0.25), value: holding)
                .onLongPressGesture(minimumDuration: 0.7, perform: {
                    harvest()
                }, onPressingChanged: { pressing in
                    holding = pressing
                })
                .padding()
        }

        // Buy + Sell (bottom right, stacked). Plain Buttons that push the
        // screen themselves, each with one gesture recognizer, spaced well
        // apart — the old NavigationLink-plus-overlapping-gesture pairing
        // here is what made taps land on the wrong button.
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 18) {
                Button {
                    Haptics.tap()
                    SoundPlayer.shopBell()
                    showingBuy = true
                } label: {
                    ButtonLook(title: "Buy", icon: "cart.fill", width: 120, height: 46)
                }
                .bouncy(haptic: false)

                Button {
                    Haptics.tap()
                    SoundPlayer.pop()
                    showingSell = true
                } label: {
                    ButtonLook(title: "Sell", icon: "dollarsign.circle.fill", width: 120, height: 46)
                }
                .bouncy(haptic: false)
            }
            .padding()
        }

        // The icon that follows your finger (keep this LAST so it is on top)
        .overlay { DragGhost(drag: dragging) }
        .navigationDestination(isPresented: $showingBuy) { BuyScreen() }
        .navigationDestination(isPresented: $showingSell) { SellScreen() }
    }

    // ---------- Actions ----------
    var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                plotOffset = clamped(CGSize(
                    width: savedOffset.width + value.translation.width,
                    height: savedOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in
                savedOffset = plotOffset
            }
    }

    /// Stops panning at the garden's edges, so you never scroll onto empty
    /// ground. The margins leave room for the buttons at the top and bottom.
    func clamped(_ offset: CGSize) -> CGSize {
        CGSize(
            width: clamp(offset.width, content: CGFloat(Theme.gardenCols) * Theme.tileSize,
                         view: gardenFrame.width, before: 0, after: 92),
            height: clamp(offset.height, content: CGFloat(Theme.gardenRows) * Theme.tileSize,
                          view: gardenFrame.height, before: 80, after: 160)
        )
    }

    private func clamp(_ value: CGFloat, content: CGFloat, view: CGFloat,
                       before: CGFloat, after: CGFloat) -> CGFloat {
        let lowest = view - after - content   // far edge of the garden reached
        let highest = before                  // near edge of the garden reached
        // Smaller than the screen: no panning, just centred in the free space.
        if lowest > highest { return before + (view - before - after - content) / 2 }
        return min(max(value, lowest), highest)
    }

    // Which tile is under a point on the screen
    func tileAt(_ point: CGPoint) -> (col: Int, row: Int) {
        let x = point.x - gardenFrame.minX - plotOffset.width
        let y = point.y - gardenFrame.minY - plotOffset.height
        return (Int(floor(x / Theme.tileSize)), Int(floor(y / Theme.tileSize)))
    }

    // Whether a tile already has something planted on it.
    func isOccupied(_ spot: (col: Int, row: Int)) -> Bool {
        let t = store.tiles[tileKey(spot.col, spot.row)]
        return t?.seed != nil || t?.sprinkler != nil
    }

    func plant(_ id: String, atGlobal point: CGPoint) {
        guard gardenFrame != .zero else { return }
        // ignore drops on top of the inventory bar
        guard point.x < gardenFrame.maxX - 92 else { return }

        let spot = tileAt(point)
        if store.place(id, col: spot.col, row: spot.row) {
            Haptics.tap()
            SoundPlayer.plant()
            withAnimation { hasPlantedOnce = true }
        } else {
            Haptics.warning()
            showToast("That spot is taken, or it can't go here")
        }
    }

    /// Plants the seeds in your bag onto the empty tiles you can see, left to
    /// right and top to bottom, keeping clear of the buttons and the bag.
    func plantAll() {
        guard gardenFrame != .zero else { return }
        guard !store.seedsInBag.isEmpty else {
            Haptics.warning()
            showToast("You have no seeds — buy some first")
            return
        }
        let ts = Theme.tileSize
        // The part of the screen that is clear of the HUD, the bag on the
        // right and the buttons along the bottom.
        let area = CGRect(x: 0, y: 80, width: gardenFrame.width - 92, height: gardenFrame.height - 80 - 160)
        let firstCol = Int(floor(-plotOffset.width / ts)) - 1
        let lastCol = Int(ceil((area.maxX - plotOffset.width) / ts)) + 1
        let firstRow = Int(floor((area.minY - plotOffset.height) / ts)) - 1
        let lastRow = Int(ceil((area.maxY - plotOffset.height) / ts)) + 1

        var cells: [(col: Int, row: Int)] = []
        for row in firstRow...lastRow {
            for col in firstCol...lastCol {
                let center = CGPoint(x: (CGFloat(col) + 0.5) * ts + plotOffset.width,
                                     y: (CGFloat(row) + 0.5) * ts + plotOffset.height)
                if area.contains(center) && !isOccupied((col, row)) {
                    cells.append((col, row))
                }
            }
        }

        let planted = store.plantAll(in: cells)
        if planted > 0 {
            Haptics.success()
            SoundPlayer.plant()
            withAnimation { hasPlantedOnce = true }
            let left = store.seedsInBag.reduce(0) { $0 + store.count($1) }
            showToast("Planted \(planted) seed\(planted == 1 ? "" : "s")" + (left > 0 ? " — \(left) left, no more room in view" : ""))
        } else {
            Haptics.warning()
            showToast("No empty spots in view")
        }
    }

    func harvest() {
        let result = store.harvest()
        if result.count > 0 { Haptics.success() } else { Haptics.warning() }
        if let best = result.bestMutation, best != .none {
            // A rare pull gets its own bigger sound on top of the usual one.
            SoundPlayer.harvest()
            SoundPlayer.mutation()
            showToast("Harvested \(result.count) crop\(result.count == 1 ? "" : "s") — ✨ a \(best.label) one!")
        } else {
            SoundPlayer.harvest()
            showToast(result.count > 0 ? "Harvested \(result.count) crop\(result.count == 1 ? "" : "s")" : "Nothing is ready yet")
        }
    }

    /// Tapping a ready plant harvests just that one. Tapping a growing plant or
    /// a sprinkler shows how long it has left.
    func harvestOne(_ key: String) {
        guard let tile = store.tiles[key] else { return }
        if let tier = tile.sprinkler, let sp = Catalog.sprinkler(tier: tier) {
            if let left = store.sprinklerTimeLeft(tile) {
                showToast("\(sp.name) · \(timeText(left)) left")
            }
            return
        }
        guard let seed = tile.seed, let crop = Catalog.cropByName[seed] else { return }
        guard store.isReady(tile) else {
            let left = (crop.growSeconds - tile.progress) / store.speed(forKey: key)
            showToast("\(crop.name.capitalized) · \(timeText(left)) left")
            return
        }
        if let result = store.harvestTile(key) {
            Haptics.success()
            SoundPlayer.harvest()
            if result.mutation != .none {
                SoundPlayer.mutation()
                showToast("✨ Harvested a \(result.mutation.label) crop!")
            } else {
                showToast("Harvested 1 crop")
            }
        }
    }

    func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { toast = nil }
        }
    }
}

// What is drawn on a planted plot: just the plant, nothing around it.
struct TileContent: View {
    let tile: Tile

    var body: some View {
        if let seed = tile.seed, let crop = Catalog.cropByName[seed] {
            PlantStageView(crop: crop,
                           progress: min(tile.progress / crop.growSeconds, 1),
                           size: Theme.tileSize)
                .animation(.easeOut(duration: 0.4), value: tile.progress >= crop.growSeconds)
        }
    }
}

/// Shows the current weather as a little read-only pill. It refreshes itself
/// every few seconds so the random change is visible without reopening the screen.
private struct WeatherBadge: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            let season = Season.current
            // Icon-only — a quiet status indicator, not a second button, so
            // it doesn't visually compete with the Relocate button above it.
            Image(systemName: season.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.card.opacity(0.9)))
                .overlay(Circle().stroke(Theme.panelBorder, lineWidth: 1))
                .accessibilityLabel(season.label)
        }
    }
}

#Preview {
    NavigationStack {
        Game()
    }
}
