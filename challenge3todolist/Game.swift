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
    var onExit: () -> Void

    @ObservedObject private var store = GameStore.shared
    @State private var plotOffset = CGSize.zero
    @State private var savedOffset = CGSize.zero
    @State private var holding = false
    @State private var toast: String?
    @State private var dragging: DragInfo?
    @State private var gardenFrame: CGRect = .zero
    @State private var showingBuy = false
    @State private var showingSell = false
    @State private var showTornado = false
    @AppStorage("hasPlantedOnce") private var hasPlantedOnce = false

    var body: some View {
        ZStack {
            // ---------- Garden: ground + plants + rain + drag to move ----------
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
                    let willFit = !isOccupied(spot)
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
        .onChange(of: store.disasterEvent) { _, event in
            guard let event else { return }
            Haptics.warning()
            SoundPlayer.alarm()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showTornado = true }
            showToast(event)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { showTornado = false }
                store.disasterEvent = nil
            }
        }

        // The tornado itself, spinning in briefly when it strikes.
        .overlay {
            if showTornado {
                Image("Tornado")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .shadow(radius: 12)
                    .rotationEffect(.degrees(showTornado ? 360 : 0))
                    .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: showTornado)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
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
            GameButton(icon: "xmark", width: 50, height: 50) { onExit() }
                .padding()
        }

        // Relocate + weather readout (top right)
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                GameButton(icon: "location.fill", width: 50, height: 50) { relocate() }
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
                plotOffset = CGSize(
                    width: savedOffset.width + value.translation.width,
                    height: savedOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                savedOffset = plotOffset
            }
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

    /// Tapping a single ready tile harvests just that crop.
    func harvestOne(_ key: String) {
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

    // Slide the garden back to the starting spot
    func relocate() {
        withAnimation(.easeInOut(duration: 0.5)) {
            plotOffset = .zero
            savedOffset = .zero
        }
    }
}

// What is drawn on a planted tile.
// A growing crop shows: a progress bar, how long it has grown (12s / 30s) and how long is left.
struct TileContent: View {
    let tile: Tile
    var speed: Double = 1

    var body: some View {
        Group {
            if let seed = tile.seed, let crop = Catalog.cropByName[seed] {
                let f = min(tile.progress / crop.growSeconds, 1)
                let ready = f >= 1
                let timeLeft = (crop.growSeconds - tile.progress) / speed

                VStack(spacing: 2) {
                    Group {
                        if let icon = crop.systemIcon {
                            ZStack {
                                Circle().fill(crop.iconColor.opacity(0.3))
                                Image(systemName: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(crop.iconColor)
                                    .padding(7)
                            }
                        } else {
                            Image(seed)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: 30, height: 30)
                    .scaleEffect(0.55 + 0.45 * f)
                    .opacity(0.7 + 0.3 * f)

                    // progress bar
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule()
                            .fill(ready ? Theme.good : Theme.accent)
                            .frame(width: 54 * f)
                    }
                    .frame(width: 54, height: 5)

                    if ready {
                        Text("READY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.good)
                    } else {
                        // how long it has grown for / total time
                        Text("\(elapsedText(tile.progress)) / \(timeText(crop.growSeconds))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        // how long is left (faster with a sprinkler)
                        Text(speed > 1 ? "\(timeText(timeLeft)) left  x\(speed.formatted())" : "\(timeText(timeLeft)) left")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(speed > 1 ? Theme.gold : Theme.subtext)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 2)
                .frame(width: Theme.tileSize - 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .animation(.linear(duration: Theme.tickSeconds), value: f)
            } else if let tier = tile.sprinkler, let sp = Catalog.sprinkler(tier: tier) {
                ZStack {
                    Circle().fill(sp.color.opacity(0.4))
                    Image("sprinkler")
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                    Text("x\(sp.speed.formatted())")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .background(Capsule().fill(sp.color))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .overlay {
                    // the 3x3 area this sprinkler speeds up
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sp.color.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .frame(width: Theme.tileSize * 3 - 6, height: Theme.tileSize * 3 - 6)
                }
            }
        }
        .frame(width: Theme.tileSize - 6, height: Theme.tileSize - 6)
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
        Game(onExit: {})
    }
}
