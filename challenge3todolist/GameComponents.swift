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
/// The plain fill every button shares: one solid colour (the current
/// season's accent), no texture and no gradient.
struct ButtonBackground: View {
    var body: some View {
        Theme.accent
    }
}

// The look every button shares: dark text on a solid accent colour.
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
        .foregroundStyle(Theme.buttonText)
        .frame(width: width, height: height)
        .background { ButtonBackground() }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
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

// Shows an item's image. Sprinklers and icon-only event crops get a colored circle.
// A non-`.none` mutation tints the artwork and adds a little name badge, so a
// Golden or Rotten crop is unmistakable at a glance.
struct ItemIcon: View {
    let id: String
    var size: CGFloat = 44
    var mutation: Mutation = .none

    var body: some View {
        let info = ItemInfo(id: id)
        let crop = Catalog.cropByName[info.name]
        ZStack {
            if info.kind == "gear", let tier = Int(info.name), let sp = Catalog.sprinkler(tier: tier) {
                Circle().fill(sp.color.opacity(0.35))
                Image("sprinkler")
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            } else if info.kind == "seed", let crop {
                // Seeds are drawn as a packet, never as the fruit
                SeedPacketView(style: crop.style, size: size)
            } else if let crop {
                // Grown fruit (tinted when it has a mutation)
                FruitView(style: crop.style, size: size, tint: mutation.tint)
            }

            if mutation != .none {
                VStack {
                    Spacer()
                    Text(mutation.label)
                        .font(.system(size: max(7, size * 0.18), weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill((mutation.tint ?? .black).opacity(0.9)))
                        .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 0.5))
                }
                .offset(y: size * 0.14)
            }
        }
        .frame(width: size, height: size)
    }
}

struct PointsPill: View {
    @ObservedObject private var store = GameStore.shared
    @ObservedObject private var admin = AdminMode.shared
    @State private var showAdmin = false

    var body: some View {
        Text("\(Theme.coin) \(store.points.formatted())\(admin.isActive ? " 🔧" : "")")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.card.opacity(0.9)))
            .overlay(Capsule().stroke(Theme.panelBorder, lineWidth: 1))
            // Hidden entrance to admin mode: press and hold the coin counter.
            .onLongPressGesture(minimumDuration: 1.5) { showAdmin = true }
            .sheet(isPresented: $showAdmin) { AdminSheet() }
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
                        // Only the moment the drag actually begins, not every
                        // frame it continues.
                        if dragging == nil {
                            Haptics.tap()
                            SoundPlayer.pickUp()
                        }
                        dragging = DragInfo(id: id, location: drag.location)
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        SoundPlayer.dropDown()
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

// ---------- First-time tutorial ----------
struct TutorialPage {
    let icon: String
    let title: String
    let text: String
    let tint: Color
}

/// A short, skippable walkthrough shown once, the first time the app opens
/// after the two onboarding questions.
struct TutorialOverlay: View {
    var onDone: () -> Void

    @State private var index = 0

    private let pages: [TutorialPage] = [
        TutorialPage(icon: "leaf.fill", title: "Welcome to your Garden",
                     text: "Open the Garden tab, then press and hold a seed on the right edge and drag it onto an empty tile to plant it. Your plants also show up on the Home screen.",
                     tint: Theme.good),
        TutorialPage(icon: "hand.tap.fill", title: "Harvesting",
                     text: "Tap any crop once it's ready to harvest just that one — or hold the \"Hold to Harvest All\" button to collect everything at once.",
                     tint: Theme.gold),
        TutorialPage(icon: "cart.fill", title: "Buy & Sell",
                     text: "Use Buy to get new seeds and sprinklers — pricier items have limited daily stock. Use Sell to cash in crops you've harvested.",
                     tint: Color(red: 0.55, green: 0.70, blue: 0.95)),
        TutorialPage(icon: "timer", title: "Study Timer",
                     text: "Tap Study to start a focus timer. Finishing a session earns points — the same currency you spend in the garden shop.",
                     tint: .orange),
        TutorialPage(icon: "checklist", title: "To-Do List",
                     text: "Add tasks with a subject so they're colour coded. Completing one also earns points, synced with everything else.",
                     tint: .blue),
        TutorialPage(icon: "cloud.sun.rain.fill", title: "Seasons & Events",
                     text: "The weather changes on its own every so often — sun, rain and winter each affect how fast things grow, and rain can bring the odd tornado. Watch for limited-time seasonal seeds too!",
                     tint: Color(red: 0.70, green: 0.88, blue: 1.0))
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        VStack(spacing: 18) {
                            ZStack {
                                Circle().fill(page.tint.opacity(0.25))
                                Image(systemName: page.icon)
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(page.tint)
                            }
                            .frame(width: 96, height: 96)

                            Text(page.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text(page.text)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 24)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 380)

                Spacer()

                HStack {
                    Button("Skip") {
                        Haptics.tap()
                        onDone()
                    }
                    .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    Button {
                        Haptics.tap()
                        SoundPlayer.pop()
                        if index < pages.count - 1 {
                            withAnimation { index += 1 }
                        } else {
                            onDone()
                        }
                    } label: {
                        Text(index < pages.count - 1 ? "Next" : "Let's go!")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Theme.good))
                    }
                    .bouncy(haptic: false)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .transition(.opacity)
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
// MARK: - 10. GAME HUB  (Daily Quests + Mutation Dex + Achievements)
// =====================================================================

enum HubSection: String, CaseIterable, Identifiable {
    case quests = "Quests"
    case dex = "Dex"
    case achievements = "Achievements"
    var id: String { rawValue }
}

/// One entry point (opened from a single button) for everything that isn't
/// a day-to-day action: today's quests, the mutation collection log, and
/// the achievement list — kept as tabs in one sheet instead of three
/// separate buttons cluttering the Home or Garden screens.
struct GameHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var section: HubSection = .quests

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(HubSection.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch section {
                    case .quests: DailyQuestsSection()
                    case .dex: MutationDexSection()
                    case .achievements: AchievementsSection()
                    }
                }
            }
            .background(AppBackground())
            .navigationTitle("Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// ---------- Daily Quests ----------

private struct DailyQuestsSection: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        VStack(spacing: 10) {
            Text("Resets every day — come back tomorrow for 3 new ones.")
                .font(.caption)
                .foregroundStyle(Theme.subtext)
                .multilineTextAlignment(.center)
            ForEach(store.todayQuests) { template in
                QuestRow(template: template)
            }
        }
        .padding()
    }
}

private struct QuestRow: View {
    let template: QuestTemplate
    @ObservedObject private var store = GameStore.shared

    private var progress: Double { store.questProgress(for: template.kind) }
    private var done: Bool { progress >= template.target }
    private var claimed: Bool { store.isQuestClaimed(template) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((claimed ? Theme.good : Theme.accent).opacity(0.3))
                Image(systemName: claimed ? "checkmark" : template.icon)
                    .foregroundStyle(claimed ? Theme.good : Theme.text)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(claimed ? Theme.good : Theme.accent)
                        .frame(width: max(6, 120 * min(progress / template.target, 1)))
                }
                .frame(width: 120, height: 6)
                Text("\(Int(min(progress, template.target)))/\(Int(template.target)) · \(Theme.coin)\(template.reward)")
                    .font(.caption2)
                    .foregroundStyle(Theme.subtext)
            }

            Spacer()

            if claimed {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.good)
            } else if done {
                GameButton(title: "Claim", width: 90, height: 38) {
                    _ = store.claimQuest(template)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.panelBorder, lineWidth: 1))
    }
}

// ---------- Mutation Dex ----------

private struct MutationDexSection: View {
    @ObservedObject private var store = GameStore.shared
    private var totalMutations: Int { Mutation.allCases.count - 1 } // minus .none

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(Catalog.cropNames, id: \.self) { name in
                NavigationLink {
                    MutationDexCropDetail(cropName: name)
                } label: {
                    HStack(spacing: 12) {
                        ItemIcon(id: "crop:\(name)", size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.capitalized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.text)
                            Text("\(foundCount(name))/\(totalMutations) mutations found")
                                .font(.caption2)
                                .foregroundStyle(Theme.subtext)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.subtext)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.panelBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func foundCount(_ name: String) -> Int {
        store.discoveredMutations.filter { $0.hasPrefix("\(name)|") }.count
    }
}

private struct MutationDexCropDetail: View {
    let cropName: String
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Mutation.allCases.filter { $0 != .none }, id: \.self) { mutation in
                    let discovered = store.discoveredMutations.contains("\(cropName)|\(mutation.rawValue)")
                    HStack(spacing: 12) {
                        ItemIcon(id: "crop:\(cropName)", size: 44, mutation: discovered ? mutation : .none)
                            .saturation(discovered ? 1 : 0)
                            .opacity(discovered ? 1 : 0.35)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(discovered ? mutation.label : "???")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(discovered ? Theme.text : Theme.subtext)
                            Text(discovered
                                 ? "x\(mutation.priceMultiplier.formatted(.number.precision(.fractionLength(0...2)))) price"
                                 : "Not discovered yet")
                                .font(.caption2)
                                .foregroundStyle(Theme.subtext)
                        }
                        Spacer()
                        if discovered {
                            Circle().fill(mutation.tint ?? .gray).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Theme.subtext)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.panelBorder, lineWidth: 1))
                }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(cropName.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ---------- Achievements ----------

private struct AchievementsSection: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(Achievement.all) { achievement in
                let unlocked = store.unlockedAchievements.contains(achievement.id)
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill((unlocked ? Theme.gold : Theme.panelBorder).opacity(0.3))
                        Image(systemName: unlocked ? achievement.icon : "lock.fill")
                            .foregroundStyle(unlocked ? Theme.gold : Theme.subtext)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(unlocked ? Theme.text : Theme.subtext)
                        Text(achievement.detail)
                            .font(.caption2)
                            .foregroundStyle(Theme.subtext)
                    }
                    Spacer()
                    if unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.good)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(unlocked ? 0.95 : 0.7)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(unlocked ? Theme.gold.opacity(0.6) : Theme.panelBorder, lineWidth: unlocked ? 2 : 1))
            }
        }
        .padding()
    }
}

// ---------- "Achievement unlocked" toast ----------

/// A banner any screen can show when `GameStore.shared.pendingAchievementUnlock`
/// becomes non-nil (ContentView watches it app-wide, so it pops up no matter
/// which tab you're on when something unlocks).
struct AchievementUnlockBanner: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.gold.opacity(0.9))
                Image(systemName: achievement.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 1) {
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.subtext)
                Text(achievement.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card.opacity(0.97)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(.horizontal, 24)
    }
}

/// A small pill button that opens the Hub, with a badge showing how many of
/// today's quests are finished and ready to claim (so it's worth tapping).
struct HubButton: View {
    @ObservedObject private var store = GameStore.shared
    @Binding var showingHub: Bool

    private var claimableCount: Int {
        store.todayQuests.filter { store.questProgress(for: $0.kind) >= $0.target && !store.isQuestClaimed($0) }.count
    }

    var body: some View {
        Button {
            Haptics.tap()
            SoundPlayer.select()
            showingHub = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "scroll.fill")
                    .foregroundStyle(claimableCount > 0 ? Theme.gold : Theme.text)
                Text("Hub")
                    .foregroundStyle(Theme.text)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .overlay(alignment: .topTrailing) {
                if claimableCount > 0 {
                    Text("\(claimableCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Theme.bad))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .bouncy(haptic: false)
    }
}
