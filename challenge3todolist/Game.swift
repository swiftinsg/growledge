//
//  Game.swift
//  The app
//

import SwiftUI
import AVFoundation
import Combine

// =====================================================================
// MARK: - 1. THEME  (change colors, sizes and the button image here)
// =====================================================================
enum Theme {
    // Moody rainy palette
    static let grass = Color(red: 0.17, green: 0.25, blue: 0.25)
    static let soilDark = Color(red: 0.16, green: 0.18, blue: 0.23)
    static let soilLight = Color(red: 0.19, green: 0.21, blue: 0.27)
    static let backdropTop = Color(red: 0.09, green: 0.11, blue: 0.16)
    static let backdropBottom = Color(red: 0.14, green: 0.18, blue: 0.24)
    static let card = Color(red: 0.14, green: 0.17, blue: 0.23)
    static let panelBorder = Color.white.opacity(0.12)
    static let text = Color(red: 0.88, green: 0.92, blue: 0.96)
    static let subtext = Color(red: 0.88, green: 0.92, blue: 0.96).opacity(0.6)
    static let accent = Color(red: 0.45, green: 0.65, blue: 0.85)      // rain blue
    static let good = Color(red: 0.45, green: 0.78, blue: 0.65)        // soft teal
    static let gold = Color(red: 0.93, green: 0.78, blue: 0.50)
    static let bad = Color(red: 0.88, green: 0.45, blue: 0.50)
    static let coin = "✦"

    static let buttonImage = "Image 1"      // background of every button
    static let cornerRadius: CGFloat = 16
    static let tileSize: CGFloat = 80
    static let tickSeconds = 0.25           // how often plants grow
    static let sellRate = 0.5               // selling gives 50% of the price
    static let startingPoints = 100         // only used the very first time

    // Rain
    static let rainColor = Color(red: 0.75, green: 0.85, blue: 1.0)
    static let gloom = Color(red: 0.05, green: 0.08, blue: 0.16).opacity(0.35)
}

// =====================================================================
// MARK: - 2. CATALOG  (all products, prices and growth times)
// =====================================================================
struct Crop: Identifiable {
    let name: String            // = the image name
    let price: Int
    let growSeconds: Double
    var id: String { name }
}

struct Sprinkler: Identifiable {
    let tier: Int
    let name: String
    let price: Int
    let speed: Double           // growth speed multiplier
    let color: Color
    var id: Int { tier }
}

enum Catalog {
    // ORDER MATTERS: first = cheapest + fastest, last = most expensive + slowest.
    // Prices go from 10 to 1,000,000,000 and growth from 1 second to 30 minutes
    // automatically, spread across this list. Reorder, add or remove names freely.
    // (Every name must be unique.)
    static let cropNames: [String] = [
        // edibles
        "carrot", "cabbage", "raddish", "eggplant", "apple", "banana", "orange",
        "peanut", "egg", "pineapple", "coconut", "sugar cane", "cocoa", "chocolate",
        "fried chicken",
        // memes (oldest to newest)
        "doge", "obama", "donald trump", "pawn", "the rook", "ronaldo", "the skeleton",
        "backrooms scaryyy", "beluga", "jamal", "ishowspeed", "rudi", "ben",
        "tung tung tung sahur", "brr brr patapim", "iphone duo",
        "macbook proled xdr display",
        "carterpcs"
    ]

    static let minPrice = 10.0
    static let maxPrice = 1_000_000_000.0
    static let minGrowSeconds = 1.0
    static let maxGrowSeconds = 1800.0      // 30 minutes

    static let crops: [Crop] = {
        let n = cropNames.count
        return cropNames.enumerated().map { i, name in
            let t = n > 1 ? Double(i) / Double(n - 1) : 0
            let raw = minPrice * pow(maxPrice / minPrice, t)
            let step = pow(10.0, floor(log10(raw)) - 1)          // keep 2 digits, e.g. 4,800
            let price = Int((raw / step).rounded() * step)
            let grow = (minGrowSeconds * pow(maxGrowSeconds / minGrowSeconds, t)).rounded()
            return Crop(name: name, price: price, growSeconds: max(1, grow))
        }
    }()

    // uniquingKeysWith so a duplicate name can never crash the app
    static let cropByName: [String: Crop] = Dictionary(crops.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

    // 5 sprinkler tiers. They speed up plants in the 3x3 area around them.
    static let sprinklers: [Sprinkler] = [
        Sprinkler(tier: 1, name: "Tiny Sprinkler",    price: 500,       speed: 1.5, color: .green),
        Sprinkler(tier: 2, name: "Super Sprinkler",   price: 5_000,     speed: 2,   color: .blue),
        Sprinkler(tier: 3, name: "Mega Sprinkler",    price: 50_000,    speed: 3,   color: .purple),
        Sprinkler(tier: 4, name: "Ultra Sprinkler",   price: 500_000,   speed: 5,   color: .orange),
        Sprinkler(tier: 5, name: "Rainbow Sprinkler", price: 5_000_000, speed: 10,  color: .pink)
    ]

    static func sprinkler(tier: Int) -> Sprinkler? {
        sprinklers.first { $0.tier == tier }
    }
}

// =====================================================================
// MARK: - 3. ITEMS + STORE  (inventory, points, plants; saved automatically)
// =====================================================================
// Item ids look like:  "seed:carrot"   "crop:carrot"   "gear:3"
struct ItemInfo {
    let id: String
    var kind: String { id.components(separatedBy: ":").first ?? "" }
    var name: String { id.components(separatedBy: ":").dropFirst().joined(separator: ":") }
    var imageName: String { kind == "gear" ? "sprinkler" : name }
    var displayName: String {
        if kind == "gear", let tier = Int(name), let sp = Catalog.sprinkler(tier: tier) { return sp.name }
        return name.capitalized
    }
}

func tileKey(_ col: Int, _ row: Int) -> String { "\(col),\(row)" }
func tileCoords(_ key: String) -> (col: Int, row: Int) {
    let p = key.split(separator: ",").compactMap { Int($0) }
    return p.count == 2 ? (p[0], p[1]) : (0, 0)
}

// Time left (rounds up): "45s" or "3m 5s"
func timeText(_ seconds: Double) -> String {
    let t = max(0, Int(ceil(seconds)))
    return t >= 60 ? "\(t / 60)m \(t % 60)s" : "\(t)s"
}

// Time already grown (rounds down)
func elapsedText(_ seconds: Double) -> String {
    let t = max(0, Int(floor(seconds)))
    return t >= 60 ? "\(t / 60)m \(t % 60)s" : "\(t)s"
}

struct Tile: Codable {
    var seed: String?
    var sprinkler: Int?
    var progress: Double = 0
}

final class GameStore: ObservableObject {
    static let shared = GameStore()

    // "points" is the shared currency: the garden shop spends it and
    // finished study sessions (StudyView) add to it.
    @Published var points: Int {
        didSet { UserDefaults.standard.set(points, forKey: "points") }
    }
    @Published var inventory: [String: Int]
    @Published var tiles: [String: Tile]
    private var ticks = 0

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "points") == nil { d.set(Theme.startingPoints, forKey: "points") }
        points = d.integer(forKey: "points")
        inventory = (d.dictionary(forKey: "garden.inventory") as? [String: Int]) ?? [:]
        if let data = d.data(forKey: "garden.tiles"),
           let saved = try? JSONDecoder().decode([String: Tile].self, from: data) {
            tiles = saved
        } else {
            tiles = [:]
        }
    }

    func save() {
        let d = UserDefaults.standard
        d.set(inventory, forKey: "garden.inventory")
        d.set(try? JSONEncoder().encode(tiles), forKey: "garden.tiles")
    }

    // ---- inventory ----
    func count(_ id: String) -> Int { inventory[id] ?? 0 }
    func add(_ id: String) { inventory[id, default: 0] += 1 }
    func remove(_ id: String) {
        let c = count(id)
        inventory[id] = c > 1 ? c - 1 : nil
    }

    var sortedInventory: [String] {
        inventory.filter { $0.value > 0 }.keys.sorted { sortOrder($0) < sortOrder($1) }
    }
    private func sortOrder(_ id: String) -> Int {
        let info = ItemInfo(id: id)
        let idx = Catalog.cropNames.firstIndex(of: info.name) ?? (Int(info.name) ?? 0)
        switch info.kind {
        case "seed": return idx
        case "gear": return 1000 + idx
        default: return 2000 + idx
        }
    }

    // ---- buying and selling ----
    @discardableResult
    func buy(_ id: String, price: Int) -> Bool {
        guard points >= price else { return false }
        points -= price
        add(id)
        save()
        return true
    }

    // seeds can't be sold (nil). Everything else sells for 50%.
    func sellValue(_ id: String) -> Int? {
        let info = ItemInfo(id: id)
        switch info.kind {
        case "crop":
            guard let crop = Catalog.cropByName[info.name] else { return nil }
            return Int(Double(crop.price) * Theme.sellRate)
        case "gear":
            guard let tier = Int(info.name), let sp = Catalog.sprinkler(tier: tier) else { return nil }
            return Int(Double(sp.price) * Theme.sellRate)
        default:
            return nil
        }
    }

    func sell(_ id: String) -> Int? {
        guard count(id) > 0, let value = sellValue(id) else { return nil }
        remove(id)
        points += value
        save()
        return value
    }

    // ---- planting ----
    func place(_ id: String, col: Int, row: Int) -> Bool {
        guard count(id) > 0 else { return false }
        let key = tileKey(col, row)
        if let t = tiles[key], t.seed != nil || t.sprinkler != nil { return false }
        let info = ItemInfo(id: id)
        if info.kind == "seed", Catalog.cropByName[info.name] != nil {
            tiles[key] = Tile(seed: info.name, sprinkler: nil, progress: 0)
        } else if info.kind == "gear", let tier = Int(info.name), Catalog.sprinkler(tier: tier) != nil {
            tiles[key] = Tile(seed: nil, sprinkler: tier, progress: 0)
        } else {
            return false
        }
        remove(id)
        save()
        return true
    }

    func isReady(_ tile: Tile) -> Bool {
        guard let seed = tile.seed, let crop = Catalog.cropByName[seed] else { return false }
        return tile.progress >= crop.growSeconds
    }

    var readyCount: Int { tiles.values.filter { isReady($0) }.count }

    // ---- growing ----
    // How fast a tile grows (1 = normal, more with a sprinkler in the 3x3 area around it)
    func speed(forKey key: String) -> Double {
        let spot = tileCoords(key)
        var speed = 1.0
        for dc in -1...1 {
            for dr in -1...1 {
                if let tier = tiles[tileKey(spot.col + dc, spot.row + dr)]?.sprinkler,
                   let sp = Catalog.sprinkler(tier: tier) {
                    speed = max(speed, sp.speed)
                }
            }
        }
        return speed
    }

    func tick(_ dt: Double) {
        var updated = tiles
        var changed = false
        for (key, tile) in tiles {
            guard let seed = tile.seed, let crop = Catalog.cropByName[seed],
                  tile.progress < crop.growSeconds else { continue }
            updated[key]?.progress = min(crop.growSeconds, tile.progress + dt * speed(forKey: key))
            changed = true
        }
        if changed { tiles = updated }
        ticks += 1
        if ticks % 20 == 0 { save() }
    }

    // ---- harvesting ----
    func harvest() -> Int {
        var updated = tiles
        var n = 0
        for (key, tile) in tiles where isReady(tile) {
            if let seed = tile.seed {
                add("crop:\(seed)")
                updated[key] = nil
                n += 1
            }
        }
        if n > 0 {
            tiles = updated
            save()
        }
        return n
    }
}

// =====================================================================
// MARK: - 4. REUSABLE UI  (buttons, icons, points, rain, drag helpers)
// =====================================================================
// The look every button shares: the same background image as Study, with a moody tint.
struct ButtonLook: View {
    var title: String? = nil
    var icon: String? = nil
    var width: CGFloat = 110
    var height: CGFloat = 46

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            if let title { Text(title) }
        }
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2)
        .frame(width: width, height: height)
        .background {
            ZStack {
                Image(Theme.buttonImage)
                    .resizable()
                    .scaledToFill()
                Theme.backdropTop.opacity(0.35)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(.white.opacity(0.35), lineWidth: 1.5))
    }
}

// A normal tap button with the pop sound.
struct GameButton: View {
    var title: String? = nil
    var icon: String? = nil
    var width: CGFloat = 110
    var height: CGFloat = 46
    var action: () -> Void

    var body: some View {
        Button {
            SoundPlayer.pop()
            action()
        } label: {
            ButtonLook(title: title, icon: icon, width: width, height: height)
        }
        .buttonStyle(.plain)
    }
}

// Shows an item's image. Sprinklers get a colored circle.
struct ItemIcon: View {
    let id: String
    var size: CGFloat = 44

    var body: some View {
        let info = ItemInfo(id: id)
        ZStack {
            if info.kind == "gear", let tier = Int(info.name), let sp = Catalog.sprinkler(tier: tier) {
                Circle().fill(sp.color.opacity(0.35))
            }
            Image(info.imageName)
                .resizable()
                .scaledToFit()
                .padding(info.kind == "gear" ? 5 : 0)
        }
        .frame(width: size, height: size)
    }
}

struct PointsPill: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        Text("\(Theme.coin) \(store.points.formatted())")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.card.opacity(0.9)))
            .overlay(Capsule().stroke(Theme.panelBorder, lineWidth: 1))
    }
}

// ---------- Rain (change the number of drops, speed and look here) ----------
struct RainDrop {
    let x: Double        // 0...1 across the screen
    let speed: Double    // how fast it falls
    let length: Double
    let phase: Double
    let opacity: Double
}

struct RainLayer: View {
    static let drops: [RainDrop] = (0..<140).map { _ in
        RainDrop(x: Double.random(in: 0...1),
                 speed: Double.random(in: 0.7...1.4),
                 length: Double.random(in: 10...24),
                 phase: Double.random(in: 0...1),
                 opacity: Double.random(in: 0.15...0.5))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for drop in Self.drops {
                    let progress = (t * drop.speed * 0.9 + drop.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 60) - 30
                    let x = drop.x * (size.width + 40) + y * 0.18 - 20
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + drop.length * 0.18, y: y + drop.length))
                    context.stroke(path, with: .color(Theme.rainColor.opacity(drop.opacity)), lineWidth: 1.2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// Dark background with rain, used behind the shops
struct RainyBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.backdropTop, Theme.backdropBottom], startPoint: .top, endPoint: .bottom)
            RainLayer().opacity(0.6)
        }
        .ignoresSafeArea()
    }
}

// ---------- Drag and drop (our own, so it always works) ----------
// What is being dragged and where the finger is (screen coordinates)
struct DragInfo {
    var id: String
    var location: CGPoint
}

// Press and hold an item for a moment, then drag it.
struct ItemDrag: ViewModifier {
    let id: String
    @Binding var dragging: DragInfo?
    var onDrop: (CGPoint) -> Void

    func body(content: Content) -> some View {
        content.gesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                .onChanged { value in
                    if case .second(true, let drag?) = value {
                        dragging = DragInfo(id: id, location: drag.location)
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        onDrop(drag.location)
                    }
                    dragging = nil
                }
        )
    }
}

// Remembers where a view is on the screen
struct FrameReader: ViewModifier {
    @Binding var frame: CGRect

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { frame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, new in frame = new }
            }
        )
    }
}

extension View {
    func itemDrag(id: String, dragging: Binding<DragInfo?>, onDrop: @escaping (CGPoint) -> Void) -> some View {
        modifier(ItemDrag(id: id, dragging: dragging, onDrop: onDrop))
    }
    func readFrame(_ frame: Binding<CGRect>) -> some View {
        modifier(FrameReader(frame: frame))
    }
}

// The icon that follows your finger while dragging
struct DragGhost: View {
    let drag: DragInfo?

    var body: some View {
        GeometryReader { geo in
            if let drag {
                let origin = geo.frame(in: .global)
                ItemIcon(id: drag.id, size: 70)
                    .shadow(radius: 6)
                    .position(x: drag.location.x - origin.minX,
                              y: drag.location.y - origin.minY - 50)
            }
        }
        .allowsHitTesting(false)
    }
}

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
    @State private var selected: String?
    @State private var gardenFrame: CGRect = .zero

    private let timer = Timer.publish(every: Theme.tickSeconds, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // ---------- Garden: ground + plants + rain + drag to move ----------
            ZStack {
                GardenPlot(offset: plotOffset)

                ForEach(store.tiles.keys.sorted(), id: \.self) { key in
                    if let tile = store.tiles[key] {
                        let spot = tileCoords(key)
                        TileContent(tile: tile, speed: store.speed(forKey: key))
                            .position(
                                x: (CGFloat(spot.col) + 0.5) * Theme.tileSize + plotOffset.width,
                                y: (CGFloat(spot.row) + 0.5) * Theme.tileSize + plotOffset.height
                            )
                            .allowsHitTesting(false)
                    }
                }

                // Gloomy tint + falling rain
                Rectangle().fill(Theme.gloom).allowsHitTesting(false)
                RainLayer()

                // Outline on the tile you are about to drop onto
                if let d = dragging, gardenFrame != .zero {
                    let spot = tileAt(d.location)
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.accent, lineWidth: 3)
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
            // Tap a tile to plant the selected item
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                    if let id = selected { plant(id, atGlobal: value.location) }
                }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(timer) { _ in store.tick(Theme.tickSeconds) }
        .onDisappear { store.save() }

        // ==================================================
        // BUTTONS AND HUD: each .overlay is one spot on screen
        // ==================================================

        // Exit (top left)
        .overlay(alignment: .topLeading) {
            GameButton(icon: "xmark", width: 50, height: 50) { onExit() }
                .padding()
        }

        // Relocate (top right)
        .overlay(alignment: .topTrailing) {
            GameButton(icon: "location.fill", width: 50, height: 50) { relocate() }
                .padding()
        }

        // Points + messages (top center)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                PointsPill()
                if let selected {
                    Text("Tap a tile to plant \(ItemInfo(id: selected).displayName)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent.opacity(0.9)))
                }
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
            InventoryBar(dragging: $dragging, selected: $selected) { id, point in
                plant(id, atGlobal: point)
            }
            .padding(.trailing, 6)
            .padding(.top, 90)
            .padding(.bottom, 150)
        }

        // Harvest: press and HOLD (bottom left)
        .overlay(alignment: .bottomLeading) {
            ButtonLook(title: "Hold to Harvest", icon: "hand.tap.fill", width: 200, height: 56)
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

        // Buy + Sell navigation links (bottom right, stacked)
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                NavigationLink {
                    BuyScreen()
                } label: {
                    ButtonLook(title: "Buy", icon: "cart.fill", width: 120, height: 46)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { SoundPlayer.pop() })

                NavigationLink {
                    SellScreen()
                } label: {
                    ButtonLook(title: "Sell", icon: "dollarsign.circle.fill", width: 120, height: 46)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { SoundPlayer.pop() })
            }
            .padding()
        }

        // The icon that follows your finger (keep this LAST so it is on top)
        .overlay { DragGhost(drag: dragging) }
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

    func plant(_ id: String, atGlobal point: CGPoint) {
        guard gardenFrame != .zero else { return }
        // ignore drops on top of the inventory bar
        guard point.x < gardenFrame.maxX - 92 else { return }

        let spot = tileAt(point)
        if store.place(id, col: spot.col, row: spot.row) {
            SoundPlayer.pop()
            if store.count(id) == 0 { selected = nil }
        } else {
            showToast("That spot is taken, or it can't go here")
        }
    }

    func harvest() {
        let n = store.harvest()
        SoundPlayer.pop()
        showToast(n > 0 ? "Harvested \(n) crop\(n == 1 ? "" : "s")" : "Nothing is ready yet")
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
                    Image(seed)
                        .resizable()
                        .scaledToFit()
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

// =====================================================================
// MARK: - 6. INVENTORY BAR  (scrollable, right side of the garden)
// =====================================================================
struct InventoryBar: View {
    @ObservedObject private var store = GameStore.shared
    @Binding var dragging: DragInfo?
    @Binding var selected: String?
    var onDrop: (String, CGPoint) -> Void

    var body: some View {
        let items = store.sortedInventory
        VStack(spacing: 4) {
            Image(systemName: "bag.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            if items.isEmpty {
                Text("Empty")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.subtext)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(items, id: \.self) { id in
                            InventoryCell(
                                id: id,
                                count: store.count(id),
                                isSelected: selected == id,
                                dragging: $dragging,
                                onTap: { selected = (selected == id) ? nil : id },
                                onDrop: { point in onDrop(id, point) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollDisabled(dragging != nil)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 80)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelBorder, lineWidth: 1))
    }
}

// One item.
// Option 1: press and hold for a moment, then drag it onto a tile.
// Option 2: tap it (blue outline), then tap a tile.
struct InventoryCell: View {
    let id: String
    let count: Int
    let isSelected: Bool
    @Binding var dragging: DragInfo?
    var onTap: () -> Void
    var onDrop: (CGPoint) -> Void

    var body: some View {
        let info = ItemInfo(id: id)
        VStack(spacing: 2) {
            ItemIcon(id: id, size: 46)
                .overlay(alignment: .topTrailing) {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.bad))
                        .offset(x: 6, y: -4)
                }
            Text(info.kind == "gear" ? info.displayName : info.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if info.kind == "seed" {
                Text("SEEDS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.8)))
            }
        }
        .frame(width: 64)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent, lineWidth: isSelected ? 3 : 0)
        )
        .opacity(dragging?.id == id ? 0.4 : 1)
        .onTapGesture { onTap() }
        .itemDrag(id: id, dragging: $dragging, onDrop: onDrop)
    }
}

// =====================================================================
// MARK: - 7. BUY SCREEN  (opened by the Buy navigation link)
// =====================================================================
struct BuyScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type: ShopType = .seeds
    @State private var showAsk = true

    var body: some View {
        ZStack {
            RainyBackdrop()
            VStack(spacing: 12) {
                HStack {
                    // Always lets you go back to the garden
                    GameButton(title: "Garden", icon: "chevron.left", width: 130, height: 44) {
                        dismiss()
                    }
                    Spacer()
                    PointsPill()
                }

                // Switch between the two shops any time
                HStack(spacing: 10) {
                    GameButton(title: "Seeds", width: 110, height: 40) { type = .seeds }
                        .opacity(type == .seeds ? 1 : 0.45)
                    GameButton(title: "Gears", width: 110, height: 40) { type = .gears }
                        .opacity(type == .gears ? 1 : 0.45)
                }

                Text(type == .seeds ? "Seed Shop" : "Gear Shop")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if type == .seeds {
                            ForEach(Catalog.crops) { crop in
                                ShopRow(
                                    id: "seed:\(crop.name)",
                                    title: crop.name.capitalized + " Seeds",
                                    subtitle: "Grows in \(timeText(crop.growSeconds))",
                                    price: crop.price
                                )
                            }
                        } else {
                            ForEach(Catalog.sprinklers) { sp in
                                ShopRow(
                                    id: "gear:\(sp.tier)",
                                    title: sp.name,
                                    subtitle: "Plants nearby grow x\(sp.speed.formatted()) faster",
                                    price: sp.price
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // The question when you arrive
        .confirmationDialog("What would you like to do?", isPresented: $showAsk, titleVisibility: .visible) {
            Button("Buy Seeds") { type = .seeds }
            Button("Buy Gears") { type = .gears }
            Button("Back to garden", role: .cancel) { dismiss() }
        }
    }
}

struct ShopRow: View {
    let id: String
    let title: String
    let subtitle: String
    let price: Int
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        let canBuy = store.points >= price
        HStack(spacing: 12) {
            ItemIcon(id: id, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.subtext)
                Text("\(Theme.coin) \(price.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(canBuy ? Theme.gold : Theme.bad)
                Text("You have: \(store.count(id))")
                    .font(.caption2)
                    .foregroundStyle(Theme.subtext)
            }
            Spacer()
            GameButton(title: "Buy", width: 72, height: 44) {
                store.buy(id, price: price)
            }
            .disabled(!canBuy)
            .opacity(canBuy ? 1 : 0.4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.panelBorder, lineWidth: 1))
    }
}

// =====================================================================
// MARK: - 8. SELL SCREEN  (opened by the Sell navigation link)
// =====================================================================
struct SellScreen: View {
    @ObservedObject private var store = GameStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var message = "Drag an item into the box (or tap an item, then tap the box)"
    @State private var showAsk = true
    @State private var dragging: DragInfo?
    @State private var selected: String?
    @State private var boxFrame: CGRect = .zero

    var body: some View {
        // seeds can't be sold, so they are not shown here
        let sellable = store.sortedInventory.filter { ItemInfo(id: $0).kind != "seed" }
        let hovering = dragging.map { boxFrame.contains($0.location) } ?? false

        ZStack {
            RainyBackdrop()
            VStack(spacing: 12) {
                HStack {
                    GameButton(title: "Garden", icon: "chevron.left", width: 130, height: 44) {
                        dismiss()
                    }
                    Spacer()
                    PointsPill()
                }

                Text("Sell Shop")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)

                // Drop zone
                RoundedRectangle(cornerRadius: 24)
                    .fill(hovering ? Theme.good.opacity(0.3) : Theme.card.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(hovering ? Theme.good : Theme.accent.opacity(0.6),
                                          style: StrokeStyle(lineWidth: 2, dash: [10]))
                    )
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 34))
                                .foregroundStyle(Theme.accent)
                            Text(message)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .frame(height: 150)
                    .readFrame($boxFrame)
                    .onTapGesture {
                        if let id = selected {
                            sellItem(id)
                        } else {
                            message = "Tap an item first, or drag it here"
                        }
                    }

                // Your inventory (scrollable). Press, hold and drag up into the box.
                ScrollView {
                    if sellable.isEmpty {
                        Text("Nothing to sell yet. Harvest some crops.")
                            .font(.body)
                            .foregroundStyle(Theme.subtext)
                            .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(sellable, id: \.self) { id in
                                let info = ItemInfo(id: id)
                                VStack(spacing: 3) {
                                    ItemIcon(id: id, size: 60)
                                    Text(info.displayName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                    Text("x\(store.count(id))  •  \(Theme.coin) \((store.sellValue(id) ?? 0).formatted())")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Theme.gold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card.opacity(0.92)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.accent, lineWidth: selected == id ? 3 : 0)
                                )
                                .opacity(dragging?.id == id ? 0.4 : 1)
                                .onTapGesture { selected = (selected == id) ? nil : id }
                                .itemDrag(id: id, dragging: $dragging) { point in
                                    if boxFrame.contains(point) { sellItem(id) }
                                }
                            }
                        }
                    }
                }
                .scrollDisabled(dragging != nil)
            }
            .padding()
        }
        .overlay { DragGhost(drag: dragging) }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // The question when you arrive
        .confirmationDialog("What would you like to do?", isPresented: $showAsk, titleVisibility: .visible) {
            Button("Sell my stuff") { }
            Button("Back to garden", role: .cancel) { dismiss() }
        }
    }

    func sellItem(_ id: String) {
        if let earned = store.sell(id) {
            SoundPlayer.pop()
            message = "Sold for \(Theme.coin) \(earned.formatted())"
            if store.count(id) == 0 { selected = nil }
        } else {
            message = "That can't be sold"
        }
    }
}

// =====================================================================
// MARK: - Pop sound (you never need to touch this)
// =====================================================================
class SoundPlayer {
    static var player: AVAudioPlayer?
    static let popData = makePopWav()

    static func pop() {
        player = try? AVAudioPlayer(data: popData)
        player?.play()
    }

    static func makePopWav() -> Data {
        let sampleRate = 44100.0
        let duration = 0.12
        let count = Int(sampleRate * duration)

        var samples = [Int16]()
        var phase = 0.0
        for i in 0..<count {
            let progress = Double(i) / Double(count)
            let frequency = 700 - 450 * progress
            phase += 2 * Double.pi * frequency / sampleRate
            let fade = pow(1 - progress, 2)
            samples.append(Int16(sin(phase) * fade * 0.6 * Double(Int16.max)))
        }

        var data = Data()
        func add32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func add16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }

        let dataSize = UInt32(samples.count * 2)
        data.append("RIFF".data(using: .ascii)!)
        add32(36 + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        add32(16)
        add16(1)
        add16(1)
        add32(UInt32(sampleRate))
        add32(UInt32(sampleRate) * 2)
        add16(2)
        add16(16)
        data.append("data".data(using: .ascii)!)
        add32(dataSize)
        for s in samples { add16(UInt16(bitPattern: s)) }
        return data
    }
}

// =====================================================================
// MARK: - Endless garden ground (you never need to touch this)
// =====================================================================
struct GardenPlot: View, Animatable {
    var offset: CGSize
    let tileSize: CGFloat = Theme.tileSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Theme.grass)
            )

            let firstCol = Int(floor(-offset.width / tileSize))
            let lastCol = Int(floor((size.width - offset.width) / tileSize))
            let firstRow = Int(floor(-offset.height / tileSize))
            let lastRow = Int(floor((size.height - offset.height) / tileSize))
            guard firstCol <= lastCol, firstRow <= lastRow else { return }

            for col in firstCol...lastCol {
                for row in firstRow...lastRow {
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize + offset.width,
                        y: CGFloat(row) * tileSize + offset.height,
                        width: tileSize,
                        height: tileSize
                    ).insetBy(dx: 3, dy: 3)

                    let isDark = (col + row) % 2 == 0
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 12),
                        with: .color(isDark ? Theme.soilDark : Theme.soilLight)
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Game(onExit: {})
    }
}
