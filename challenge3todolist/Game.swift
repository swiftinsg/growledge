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
    @State private var holding = false
    @State private var toast: String?
    @State private var dragging: DragInfo?
    @State private var gardenFrame: CGRect = .zero
    @State private var showingBuy = false

    private var plotOffset: CGSize {
        Theme.centeredGardenOffset(in: gardenFrame.size)
    }
    @State private var showingSell = false
    @AppStorage("hasPlantedOnce") private var hasPlantedOnce = false

    var body: some View {
        ZStack {
            // ---------- Garden: fixed 3x3 ground + plants ----------
            ZStack {
                GardenPlot(offset: plotOffset)

                // Tap any ready tile to harvest just that one crop.
                GardenTilesLayer(store: store, offset: plotOffset, onTapTile: harvestOne)

                // Weather (snow, rain or sun rays)
                WeatherLayer()

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
            // Measured over the whole screen (safe areas included), because that
            // is the space the plots are drawn in. Using the smaller safe-area
            // frame shifted every plot's drop zone down by ~60pt.
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { gardenFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, new in gardenFrame = new }
                }
                .ignoresSafeArea()
            )
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
        .overlay(alignment: .topTrailing) {
            InventoryBar(dragging: $dragging, onPlantAll: { plantAll() }) { id, point in
                plant(id, atGlobal: point)
            }
            .padding(.trailing, 6)
            .padding(.top, 90)
            .padding(.bottom, 150)
        }

        // Harvest all: only worth having when 2+ plants are ready (there are only 9 plots)
        .overlay(alignment: .bottom) {
            if store.readyCount >= 2 {
                ButtonLook(title: "Hold to Harvest All (\(store.readyCount))", icon: "hand.tap.fill", width: 300, height: 50)
                    .scaleEffect(holding ? 0.92 : 1)
                    .animation(.spring(duration: 0.25), value: holding)
                    .onLongPressGesture(minimumDuration: 0.7, perform: {
                        harvest()
                    }, onPressingChanged: { pressing in
                        holding = pressing
                    })
                    .padding(.bottom, 96)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: store.readyCount >= 2)

        // Buy + Sell side by side along the bottom. Plain Buttons that push the
        // screen themselves, each with one gesture recognizer.
        .overlay(alignment: .bottom) {
            HStack(spacing: 16) {
                Button {
                    Haptics.tap()
                    SoundPlayer.shopBell()
                    showingBuy = true
                } label: {
                    ButtonLook(title: "Buy", icon: "cart.fill", width: 170, height: 56)
                }
                .bouncy(haptic: false)

                Button {
                    Haptics.tap()
                    SoundPlayer.pop()
                    showingSell = true
                } label: {
                    ButtonLook(title: "Sell", icon: "dollarsign.circle.fill", width: 170, height: 56)
                }
                .bouncy(haptic: false)
            }
            .padding(.bottom, 24)
        }

        // The icon that follows your finger (keep this LAST so it is on top)
        .overlay { DragGhost(drag: dragging) }
        .navigationDestination(isPresented: $showingBuy) { BuyScreen() }
        .navigationDestination(isPresented: $showingSell) { SellScreen() }
    }

    // ---------- Actions ----------

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
        // No blanket "ignore the right edge" rule: the bar overlaps the garden's
        // right-hand column, and that column must stay plantable.
        guard !id.hasPrefix("crop:") else {
            Haptics.warning()
            showToast("That's a harvested crop — sell it. Plant seeds instead")
            return
        }
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
        // The garden is fixed, so bulk planting considers every one of its nine cells.
        var cells: [(col: Int, row: Int)] = []
        for row in 0..<Theme.gardenRows {
            for col in 0..<Theme.gardenCols where !isOccupied((col, row)) {
                cells.append((col, row))
            }
        }

        let planted = store.plantAll(in: cells)
        if planted > 0 {
            Haptics.success()
            SoundPlayer.plant()
            withAnimation { hasPlantedOnce = true }
            let left = store.seedsInBag.reduce(0) { $0 + store.count($1) }
            showToast("Planted \(planted) seed\(planted == 1 ? "" : "s")" + (left > 0 ? " — \(left) left, no more room in the garden" : ""))
        } else {
            Haptics.warning()
            showToast("No empty spots in the garden")
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
                showToast("\(sp.name) · \(shortTimeText(left)) left")
            }
            return
        }
        guard let seed = tile.seed, let crop = Catalog.cropByName[seed] else { return }
        guard store.isReady(tile) else {
            let left = (crop.growSeconds - tile.progress) / store.speed(forKey: key)
            showToast("\(crop.name.capitalized) · \(shortTimeText(left)) left")
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
