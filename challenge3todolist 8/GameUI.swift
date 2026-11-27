//
//  GameUI.swift
//  The game's look: wood-and-orange panels and chunky buttons (the colours of
//  your inventory bar GIF), your pixel coin, and big full-screen celebrations.
//
//  The GAME screens (garden, Fruiterer, quests, achievements) use this look.
//  The STUDY screens (Study, History, To-Do) stay calm and use the forest.
//

import SwiftUI

// =====================================================================
// MARK: - Colours (taken from inventorybaranimation.gif)
// =====================================================================
enum Wood {
    static let base = Color(hex: 0x9B5A3C)        // the bar's brown
    static let dark = Color(hex: 0x6E3C25)        // shadow side
    static let darker = Color(hex: 0x4A2616)
    static let trim = Color(hex: 0xFBB572)        // the bar's orange edge
    static let cream = Color(hex: 0xFFF1DC)
    static let paper = Color(hex: 0xF6EAD2)
    static let leaf = Color(hex: 0x5FA55A)
    static let leafDark = Color(hex: 0x3E7A3F)
    static let gold = Color(hex: 0xFFC83D)
    static let ink = Color(hex: 0x3B2415)         // dark text on paper
}

// =====================================================================
// MARK: - Pixel pictures and the coin
// =====================================================================

/// A hand-drawn picture from the asset catalog, kept crisp when enlarged.
struct PixelIcon: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// Your pixel coin followed by an amount, e.g. [coin] 1,200.
struct CoinLabel: View {
    let amount: Int
    var size: CGFloat = 18
    var color: Color = Wood.cream
    var signed = false

    var body: some View {
        HStack(spacing: size * 0.25) {
            PixelIcon(name: "currency", size: size)
            Text("\(signed && amount > 0 ? "+" : "")\(amount.formatted())")
                .font(.system(size: size * 0.9, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount.formatted()) coins")
    }
}

// =====================================================================
// MARK: - Panels and buttons
// =====================================================================

struct WoodPanel: ViewModifier {
    var radius: CGFloat = 16
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius).fill(Wood.dark).offset(y: 4)
                    RoundedRectangle(cornerRadius: radius).fill(Wood.base)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(highlighted ? Wood.gold : Wood.trim, lineWidth: highlighted ? 4 : 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
    }
}

extension View {
    /// A wooden game panel with an orange edge.
    func woodPanel(radius: CGFloat = 16, highlighted: Bool = false) -> some View {
        modifier(WoodPanel(radius: radius, highlighted: highlighted))
    }
}

/// The look every game button shares: chunky wood with an orange edge. It sits
/// on a darker "base" so it looks like it sinks when pressed.
struct ButtonLook: View {
    var title: String? = nil
    var icon: String? = nil
    var pixelIcon: String? = nil
    var width: CGFloat = 110
    var height: CGFloat = 46

    var body: some View {
        HStack(spacing: 6) {
            if let pixelIcon { PixelIcon(name: pixelIcon, size: height * 0.5) }
            if let icon { Image(systemName: icon) }
            if let title {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .font(.system(.headline, design: .rounded).weight(.heavy))
        .foregroundStyle(Wood.cream)
        .shadow(color: Wood.darker.opacity(0.8), radius: 0, y: 1.5)
        .padding(.horizontal, 8)
        .frame(width: width, height: height)
        .woodPanel(radius: min(14, height / 2.4))
    }
}

/// A normal tap button with the pop sound and a confirming bounce + haptic.
struct GameButton: View {
    var title: String? = nil
    var icon: String? = nil
    var pixelIcon: String? = nil
    var width: CGFloat = 110
    var height: CGFloat = 46
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            SoundPlayer.pop()
            action()
        } label: {
            ButtonLook(title: title, icon: icon, pixelIcon: pixelIcon, width: width, height: height)
        }
        .bouncy(haptic: false)
    }
}

/// A green "do it" button for the main action on a game screen (Claim, Buy, Sell).
struct LeafButtonLook: View {
    var title: String
    var width: CGFloat = 110
    var height: CGFloat = 40

    var body: some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(.white)
            .shadow(color: Wood.leafDark, radius: 0, y: 1.5)
            .frame(width: width, height: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Wood.leafDark).offset(y: 3)
                    RoundedRectangle(cornerRadius: 12).fill(Wood.leaf)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xA6E08A), lineWidth: 2.5))
    }
}

// =====================================================================
// MARK: - Confetti (used by the achievement celebration and quest claims)
// =====================================================================

struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: Double
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let spin: Double
    }

    private static let colors: [Color] = [Wood.gold, Wood.trim, Wood.leaf, Color(hex: 0xFF7A8A), Color(hex: 0x7FD1FF), .white]
    @State private var pieces: [Piece] = (0..<70).map { _ in
        Piece(x: .random(in: 0...1), delay: .random(in: 0...0.8), duration: .random(in: 1.8...3.2),
              size: .random(in: 6...12), color: colors.randomElement() ?? .white, spin: .random(in: -540...540))
    }
    @State private var fall = false

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { p in
                Rectangle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .rotationEffect(.degrees(fall ? p.spin : 0))
                    .position(x: p.x * geo.size.width, y: fall ? geo.size.height + 30 : -20)
                    .animation(.easeIn(duration: p.duration).delay(p.delay), value: fall)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { fall = true }
    }
}

// =====================================================================
// MARK: - Full-screen "Achievement unlocked!"
// =====================================================================

/// Covers the whole screen when an achievement is earned: confetti, a glowing
/// badge that pops in, and a button to carry on.
struct AchievementCelebration: View {
    let achievement: Achievement
    var onDone: () -> Void

    @State private var shown = false
    @State private var glow = false

    var body: some View {
        ZStack {
            ForestBackground(dim: 0.6)
            Color.black.opacity(0.25).ignoresSafeArea()
            ConfettiBurst()

            VStack(spacing: 22) {
                Spacer()

                Text("ACHIEVEMENT UNLOCKED!")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Wood.gold)
                    .shadow(color: Wood.darker, radius: 0, y: 3)
                    .multilineTextAlignment(.center)
                    .scaleEffect(shown ? 1 : 0.3)
                    .opacity(shown ? 1 : 0)

                ZStack {
                    // rotating rays behind the badge
                    ForEach(0..<12, id: \.self) { i in
                        Capsule()
                            .fill(Wood.gold.opacity(0.35))
                            .frame(width: 14, height: 120)
                            .offset(y: -95)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    .rotationEffect(.degrees(glow ? 360 : 0))
                    .animation(.linear(duration: 18).repeatForever(autoreverses: false), value: glow)

                    Circle()
                        .fill(Wood.base)
                        .frame(width: 190, height: 190)
                        .overlay(Circle().stroke(Wood.gold, lineWidth: 8))
                        .shadow(color: Wood.gold.opacity(glow ? 0.9 : 0.3), radius: glow ? 34 : 10)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: glow)

                    AchievementBadge(achievement: achievement, size: 110)
                }
                .frame(height: 260)
                .scaleEffect(shown ? 1 : 0.1)
                .rotationEffect(.degrees(shown ? 0 : -25))

                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Wood.cream)
                        .shadow(color: .black.opacity(0.5), radius: 0, y: 3)
                        .multilineTextAlignment(.center)
                    Text(achievement.detail)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Wood.cream.opacity(0.9))
                        .multilineTextAlignment(.center)
                    if achievement.reward > 0 {
                        HStack(spacing: 6) {
                            Text("Reward")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Wood.cream.opacity(0.8))
                            CoinLabel(amount: achievement.reward, size: 22, color: Wood.gold, signed: true)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 30)

                Spacer()

                Button {
                    Haptics.tap()
                    SoundPlayer.pop()
                    onDone()
                } label: {
                    LeafButtonLook(title: "Awesome!", width: 220, height: 56)
                }
                .bouncy(haptic: false)
                .padding(.bottom, 40)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear {
            Haptics.success()
            SoundPlayer.mutation()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { shown = true }
            glow = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Achievement unlocked: \(achievement.title). \(achievement.detail)")
    }
}

/// An achievement's pixel badge (a grey silhouette while it is still locked).
struct AchievementBadge: View {
    let achievement: Achievement
    var size: CGFloat = 56
    var unlocked = true

    var body: some View {
        PixelIcon(name: achievement.art, size: size)
            .saturation(unlocked ? 1 : 0)
            .brightness(unlocked ? 0 : -0.35)
            .opacity(unlocked ? 1 : 0.55)
    }
}

// =====================================================================
// MARK: - Showing the celebration over any screen
// =====================================================================

/// Covers the whole screen with the celebration whenever an achievement is
/// waiting in the store. Add `.achievementCelebration()` to a screen once.
struct AchievementCelebrationModifier: ViewModifier {
    @ObservedObject private var store = GameStore.shared

    func body(content: Content) -> some View {
        content.overlay {
            if let achievement = store.pendingAchievementUnlock {
                AchievementCelebration(achievement: achievement) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        store.dismissAchievementCelebration()
                    }
                }
                .id(achievement.id)
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}

extension View {
    func achievementCelebration() -> some View {
        modifier(AchievementCelebrationModifier())
    }
}
