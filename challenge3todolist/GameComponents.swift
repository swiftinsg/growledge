//
//  GameComponents.swift
//  The app
//

import SwiftUI
import UIKit

// =====================================================================
// MARK: - 4. REUSABLE UI  (buttons, icons, points, rain, drag helpers)
// =====================================================================

/// Short haptic buzzes so every tap feels confirmed, not just heard/seen.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// A gentle press-down-and-spring-back for every custom button, so taps
/// always give an obvious, immediate confirmation of which button was hit.
struct BouncyButtonStyle: ButtonStyle {
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic { Haptics.tap() }
            }
    }
}

extension View {
    /// Press feedback (scale + opacity + optional haptic) for a custom button.
    func bouncy(haptic: Bool = true) -> some View {
        buttonStyle(BouncyButtonStyle(haptic: haptic))
    }
}
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

// A normal tap button with the pop sound and a confirming bounce + haptic.
struct GameButton: View {
    var title: String? = nil
    var icon: String? = nil
    var width: CGFloat = 110
    var height: CGFloat = 46
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            SoundPlayer.pop()
            action()
        } label: {
            ButtonLook(title: title, icon: icon, width: width, height: height)
        }
        .bouncy(haptic: false)
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
