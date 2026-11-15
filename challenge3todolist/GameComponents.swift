//
//  GameComponents.swift
//  The app
//

import SwiftUI

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

    /// 0, 1 or 2: which of three brightness groups this drop belongs to.
    /// Each group is drawn in one go, which is much cheaper than one draw
    /// call per drop.
    func group(in range: ClosedRange<Double>) -> Int {
        let position = (opacity - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(2, max(0, Int(position * 3)))
    }
}

struct RainLayer: View {
    static let opacityRange = 0.15...0.5
    /// The brightness of each of the three groups.
    private static let groupOpacities = [0.2, 0.33, 0.46]

    static let drops: [RainDrop] = (0..<Theme.rainDropCount).map { _ in
        RainDrop(x: Double.random(in: 0...1),
                 speed: Double.random(in: 0.7...1.4),
                 length: Double.random(in: 10...24),
                 phase: Double.random(in: 0...1),
                 opacity: Double.random(in: opacityRange))
    }

    var body: some View {
        WeatherTimeline { date in
            Canvas { context, size in
                let t = date.timeIntervalSinceReferenceDate
                var groups = [Path(), Path(), Path()]
                for drop in Self.drops {
                    let progress = (t * drop.speed * 0.9 + drop.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 60) - 30
                    let x = drop.x * (size.width + 40) + y * 0.18 - 20
                    let g = drop.group(in: Self.opacityRange)
                    groups[g].move(to: CGPoint(x: x, y: y))
                    groups[g].addLine(to: CGPoint(x: x + drop.length * 0.18, y: y + drop.length))
                }
                for (path, opacity) in zip(groups, Self.groupOpacities) {
                    context.stroke(path, with: .color(Theme.rainColor.opacity(opacity)), lineWidth: 1.2)
                }
            }
        }
    }
}

// (The shop backdrop, SeasonBackdrop, now lives in Seasons.swift)

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
