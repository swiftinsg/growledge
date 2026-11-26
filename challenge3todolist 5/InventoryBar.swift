//
//  InventoryBar.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 6. INVENTORY BAR  (scrollable, movable, can be minimised)
// =====================================================================
/// Your bag, floating over the garden.
///  - Drag the strip at the top to move it anywhere (it remembers where you left it).
///  - Tap the chevron to minimise it to a small bag button; tap that to open it again.
///  - Tap the rotate button to switch between a tall bar and a wide bar.
///  - Scroll through your items, then press and hold one and drag it onto a plot.
struct InventoryBar: View {
    /// The size of the area the bar floats in.
    let container: CGSize
    @Binding var dragging: DragInfo?
    /// Where the bar is on screen (global), so the garden knows a drop landed on it.
    @Binding var frame: CGRect
    var onPlantAll: () -> Void = {}
    var onDrop: (String, CGPoint) -> Void

    @ObservedObject private var store = GameStore.shared

    // Remembered between launches
    @AppStorage("inventory.minimised") private var minimised = false
    @AppStorage("inventory.horizontal") private var horizontal = false
    /// Where the bar sits, as 0...1 of the free space (0 = left/top, 1 = right/bottom).
    @AppStorage("inventory.posX") private var posX = 1.0
    @AppStorage("inventory.posY") private var posY = 0.35

    /// How far the bar has been dragged since the finger went down.
    @State private var dragOffset: CGSize = .zero

    /// "Plant All" only shows up once there are more seeds than this, because
    /// with a few seeds dragging them is just as quick.
    static let plantAllMinimumSeeds = 3

    private let margin: CGFloat = 8
    /// Keeps the bar clear of the coins pill at the top.
    private let topClearance: CGFloat = 56

    // MARK: Size and position

    private var panelSize: CGSize {
        if minimised { return CGSize(width: 58, height: 58) }
        if horizontal {
            return CGSize(width: min(container.width - margin * 2, 440), height: 140)
        }
        return CGSize(width: 84, height: max(180, min(container.height - topClearance - margin * 2, 420)))
    }

    /// The top-left corner of the bar, inside the container.
    private var origin: CGPoint {
        let size = panelSize
        let freeW = max(0, container.width - size.width - margin * 2)
        let freeH = max(0, container.height - size.height - topClearance - margin)
        return CGPoint(x: margin + freeW * posX + dragOffset.width,
                       y: topClearance + freeH * posY + dragOffset.height)
    }

    private func clampedOrigin(_ p: CGPoint) -> CGPoint {
        let size = panelSize
        return CGPoint(x: min(max(p.x, margin), max(margin, container.width - size.width - margin)),
                       y: min(max(p.y, topClearance), max(topClearance, container.height - size.height - margin)))
    }

    /// Moving the bar: follows the finger, and on release is saved (snapping
    /// to a side when it is let go close to it).
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let size = panelSize
                let start = CGPoint(x: origin.x - dragOffset.width, y: origin.y - dragOffset.height)
                let end = clampedOrigin(CGPoint(x: start.x + value.translation.width,
                                                y: start.y + value.translation.height))
                let freeW = max(1, container.width - size.width - margin * 2)
                let freeH = max(1, container.height - size.height - topClearance - margin)
                var x = (end.x - margin) / freeW
                let y = (end.y - topClearance) / freeH
                // Stick to the edges when let go near them
                if x < 24 / freeW { x = 0 }
                if x > 1 - 24 / freeW { x = 1 }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    posX = min(max(x, 0), 1)
                    posY = min(max(y, 0), 1)
                    dragOffset = .zero
                }
            }
    }

    // MARK: Body

    var body: some View {
        let clamped = clampedOrigin(origin)
        Group {
            if minimised {
                minimisedButton
            } else {
                expandedPanel
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .readFrame($frame)
        .position(x: clamped.x + panelSize.width / 2, y: clamped.y + panelSize.height / 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: minimised)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: horizontal)
    }

    // MARK: Minimised: a small bag button

    private var minimisedButton: some View {
        let total = store.inventory.values.reduce(0, +)
        return ZStack {
            Circle().fill(Theme.card.opacity(0.95))
            Circle().stroke(Theme.panelBorder, lineWidth: 1)
            Image(systemName: "backpack.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
        }
        .overlay(alignment: .topTrailing) {
            if total > 0 {
                Text(total > 999 ? "999+" : "\(total)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bad))
                    .offset(x: 4, y: -4)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .contentShape(Circle())
        // Tap opens the bag; dragging it moves it
        .onTapGesture {
            Haptics.tap()
            SoundPlayer.pop()
            minimised = false
        }
        .gesture(moveGesture)
        .accessibilityLabel("Open inventory")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Expanded panel

    private var expandedPanel: some View {
        let items = store.sortedInventory
        let seedCount = store.seedsInBag.reduce(0) { $0 + store.count($1) }
        return VStack(spacing: 4) {
            header

            if seedCount > Self.plantAllMinimumSeeds {
                Button(action: onPlantAll) {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                        Text("Plant All")
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(Theme.buttonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                }
                .bouncy(haptic: false)
                .padding(.horizontal, 6)
            }

            if items.isEmpty {
                Spacer(minLength: 0)
                Text("Empty")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.subtext)
                Text("Buy seeds in the shop")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            } else if horizontal {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { cells(items) }
                        .padding(.horizontal, 6)
                }
                .scrollDisabled(dragging != nil)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) { cells(items) }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
                .scrollDisabled(dragging != nil)
            }
        }
        .padding(.bottom, 6)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card.opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
    }

    @ViewBuilder
    private func cells(_ items: [String]) -> some View {
        ForEach(items, id: \.self) { id in
            InventoryCell(
                id: id,
                count: store.count(id),
                dragging: $dragging,
                onDrop: { point in onDrop(id, point) }
            )
        }
    }

    /// The strip you grab to move the bar, with your inventory animation on
    /// it and the minimise / rotate buttons.
    private var header: some View {
        VStack(spacing: 2) {
            AnimatedSprite(file: "inventorybaranimation.gif", loops: true)
                .frame(width: 70, height: 10)
                .padding(.top, 5)
            HStack(spacing: 0) {
                headerButton("chevron.down", label: "Minimise inventory") {
                    minimised = true
                }
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.subtext)
                    .frame(maxWidth: .infinity)
                headerButton(horizontal ? "rectangle.portrait" : "rectangle.landscape.rotate",
                             label: "Turn inventory sideways") {
                    horizontal.toggle()
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.white.opacity(0.06))
        .contentShape(Rectangle())
        .gesture(moveGesture)
    }

    private func headerButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            SoundPlayer.pop()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// One item: press and hold for a moment, then drag it onto a tile.
struct InventoryCell: View {
    let id: String
    let count: Int
    @Binding var dragging: DragInfo?
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
        .opacity(dragging?.id == id ? 0.4 : 1)
        .itemDrag(id: id, dragging: $dragging, onDrop: onDrop)
    }
}
