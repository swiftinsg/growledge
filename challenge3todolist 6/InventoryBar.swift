//
//  InventoryBar.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 6. INVENTORY BAR  (scrollable, movable, can be minimised)
// =====================================================================
/// The bar IS your `inventorybaranimation.gif`:
///  - its LAST frame is the open bar (your items sit on top of it),
///  - its FIRST frame is the minimised button,
///  - maximising plays the GIF forwards, minimising plays it in reverse.
///
/// Drag the bar by its wooden frame (or the grip at the top of the tall bar) to
/// move it anywhere. The rotate button turns it sideways. Scroll through your
/// items, then press and hold one and drag it onto a plot.
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
    /// Set while your GIF is playing to open or close the bar.
    @State private var transition: Transition?

    private enum Transition { case opening, closing }

    /// The GIF file, and the part of each frame that holds the bar
    /// (the GIF has white space around it; these crop it away).
    private let gif = "inventorybaranimation.gif"
    private let barCrop = CGRect(x: 10, y: 0, width: 43, height: 10)      // bar: 43 x 10 pixels
    private let circleCrop = CGRect(x: 28, y: 0, width: 12, height: 10)   // minimised button: 12 x 10

    private let cream = Color(hex: 0xFFF1DC)

    /// "Plant All" only shows up once there are more seeds than this.
    static let plantAllMinimumSeeds = 3

    private let margin: CGFloat = 8
    /// Keeps the bar clear of the coins pill at the top.
    private let topClearance: CGFloat = 56

    // MARK: Size and position

    /// How many points each pixel of the GIF is drawn as. The bar is 43 pixels
    /// long and 10 across, so every size below is a multiple of that.
    private var pixel: CGFloat {
        let room = horizontal ? container.width - margin * 2
                              : container.height - topClearance - margin * 2
        return min(9, max(4, room / 43))
    }

    private var panelSize: CGSize {
        // While opening, the bar already has its full size
        if minimised && transition != .opening { return CGSize(width: 60, height: 50) }
        return horizontal ? CGSize(width: 43 * pixel, height: 10 * pixel)
                          : CGSize(width: 10 * pixel, height: 43 * pixel)
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
            if let transition {
                transitionView(transition)
            } else if minimised {
                minimisedButton
            } else {
                expandedPanel
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .readFrame($frame)
        .position(x: clamped.x + panelSize.width / 2, y: clamped.y + panelSize.height / 2)
    }

    // MARK: Opening and closing

    private func openBar() {
        Haptics.tap()
        SoundPlayer.pop()
        transition = .opening
        minimised = false
    }

    private func closeBar() {
        Haptics.tap()
        SoundPlayer.pop()
        transition = .closing
    }

    /// Your GIF over the whole bar: forwards to open, backwards to close.
    private func transitionView(_ kind: Transition) -> some View {
        skin {
            AnimatedSprite(file: gif, loops: false, crop: barCrop,
                           reversed: kind == .closing, fill: true) {
                if kind == .closing { minimised = true }
                transition = nil
            }
        }
    }

    /// Draws something that is made to lie flat (the GIF) so it fills the bar,
    /// turned on its side when the bar is tall.
    private func skin<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let size = panelSize
        return Group {
            if horizontal {
                content().frame(width: size.width, height: size.height)
            } else {
                content()
                    .frame(width: size.height, height: size.width)
                    .rotationEffect(.degrees(90))
                    .frame(width: size.width, height: size.height)
            }
        }
    }

    // MARK: Minimised: the GIF's first frame

    private var minimisedButton: some View {
        let total = store.inventory.values.reduce(0, +)
        return ZStack {
            GIFStill(file: gif, last: false, crop: circleCrop)
            Image(systemName: "backpack.fill")
                .font(.title3)
                .foregroundStyle(cream)
        }
        .overlay(alignment: .topTrailing) {
            if total > 0 {
                Text(total > 999 ? "999+" : "\(total)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bad))
                    .offset(x: 6, y: -4)
            }
        }
        .contentShape(Rectangle())
        // Tap opens the bag; dragging it moves it
        .onTapGesture { openBar() }
        .gesture(moveGesture)
        .accessibilityLabel("Open inventory")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Open: the GIF's last frame with your items on it

    private var expandedPanel: some View {
        let items = store.sortedInventory
        let seedCount = store.seedsInBag.reduce(0) { $0 + store.count($1) }
        let showPlantAll = seedCount > Self.plantAllMinimumSeeds
        // The wooden frame is 1 pixel along the long sides and 2 at the ends
        let side = pixel * 1.3
        let end = pixel * 2.4

        return ZStack {
            // The last frame of your GIF is the bar. Dragging the wood moves it.
            skin { GIFStill(file: gif, last: true, crop: barCrop) }
                .contentShape(Rectangle())
                .gesture(moveGesture)

            Group {
                if horizontal {
                    horizontalContent(items, showPlantAll: showPlantAll)
                        .padding(.horizontal, end)
                        .padding(.vertical, side)
                } else {
                    verticalContent(items, showPlantAll: showPlantAll)
                        .padding(.horizontal, side)
                        .padding(.vertical, end)
                }
            }
        }
    }

    private func verticalContent(_ items: [String], showPlantAll: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                headerButton("chevron.down", label: "Minimise inventory") { closeBar() }
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(cream.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .contentShape(Rectangle())
                    .gesture(moveGesture)
                headerButton("rectangle.landscape.rotate", label: "Turn inventory sideways") {
                    horizontal = true
                }
            }

            if showPlantAll { plantAllButton.frame(height: 28) }

            if items.isEmpty {
                emptyMessage
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) { cells(items, width: min(64, pixel * 10 - pixel * 2.6)) }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }
                .scrollDisabled(dragging != nil)
            }
        }
    }

    private func horizontalContent(_ items: [String], showPlantAll: Bool) -> some View {
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                headerButton("chevron.down", label: "Minimise inventory") { closeBar() }
                headerButton("rectangle.portrait", label: "Turn inventory upright") {
                    horizontal = false
                }
            }
            if items.isEmpty {
                emptyMessage
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if showPlantAll { plantAllButton.frame(width: 70, height: 40) }
                        cells(items, width: 56)
                    }
                    .frame(maxHeight: .infinity)
                }
                .scrollDisabled(dragging != nil)
            }
        }
    }

    private var plantAllButton: some View {
        Button(action: onPlantAll) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                Text("Plant All")
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(Theme.buttonText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
        }
        .bouncy(haptic: false)
    }

    private var emptyMessage: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            Text("Empty")
                .font(.caption.weight(.semibold))
                .foregroundStyle(cream)
            Text("Buy seeds in the shop")
                .font(.system(size: 9))
                .foregroundStyle(cream.opacity(0.8))
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cells(_ items: [String], width: CGFloat) -> some View {
        ForEach(items, id: \.self) { id in
            InventoryCell(
                id: id,
                count: store.count(id),
                width: width,
                dragging: $dragging,
                onDrop: { point in onDrop(id, point) }
            )
        }
    }

    private func headerButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            SoundPlayer.pop()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(cream)
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
    /// How wide the cell is (the icon scales with it).
    var width: CGFloat = 64
    @Binding var dragging: DragInfo?
    var onDrop: (CGPoint) -> Void

    var body: some View {
        let info = ItemInfo(id: id)
        VStack(spacing: 2) {
            ItemIcon(id: id, size: width * 0.72)
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
                .foregroundStyle(Color(hex: 0xFFF1DC))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: width)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.18)))
        .opacity(dragging?.id == id ? 0.4 : 1)
        .itemDrag(id: id, dragging: $dragging, onDrop: onDrop)
    }
}
