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
                // Your sprinkler animation (tiers without their own GIF are recoloured)
                AnimatedSprite(file: sp.gif, loops: true)
                    .hueRotation(.degrees(sp.hue))
                    .frame(width: size, height: size)
            } else if info.kind == "seed", let crop {
                // Seeds have their own picture, never the fruit's
                CropSeedView(crop: crop, size: size)
            } else if let crop {
                // Grown fruit (tinted when it has a mutation)
                CropFruitView(crop: crop, size: size, tint: mutation.tint)
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
        HStack(spacing: 6) {
            CoinLabel(amount: store.points, size: 20, color: Wood.gold)
            if admin.isActive { Text("🔧") }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .woodPanel(radius: 18)
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
                     text: "Tap your garden on the Home screen to open it, then press and hold a seed in your bag and drag it onto an empty tile to plant it. Drag the bag by its top strip to move it, or tap the arrow to minimise it.",
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
    case achievements = "Trophies"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .quests: return "scroll.fill"
        case .dex: return "square.grid.3x3.fill"
        case .achievements: return "trophy.fill"
        }
    }
}

/// Opened from the Hub button as a FULL-SCREEN page (not a pop-up): today's
/// quests, the mutation collection, and the achievements.
struct GameHubView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = GameStore.shared
    @State private var section: HubSection = .quests

    var body: some View {
        NavigationStack {
            ZStack {
                ForestBackground(dim: 0.4)

                VStack(spacing: 12) {
                    HStack {
                        Text(title)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Wood.cream)
                            .shadow(color: .black.opacity(0.5), radius: 0, y: 2)
                        Spacer()
                        PointsPill()
                        GameButton(icon: "xmark", width: 46, height: 40) { dismiss() }
                            .accessibilityLabel("Close")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        ForEach(HubSection.allCases) { item in
                            Button {
                                Haptics.tap()
                                SoundPlayer.select()
                                withAnimation(.easeInOut(duration: 0.2)) { section = item }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.symbol)
                                    Text(item.rawValue)
                                }
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                .foregroundStyle(section == item ? Wood.ink : Wood.cream)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(section == item ? Wood.trim : Wood.base)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Wood.trim, lineWidth: 2))
                            }
                            .bouncy(haptic: false)
                        }
                    }
                    .padding(.horizontal)

                    ScrollView {
                        switch section {
                        case .quests: DailyQuestsSection()
                        case .dex: MutationDexSection()
                        case .achievements: AchievementsSection()
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .achievementCelebration()
    }

    private var title: String {
        switch section {
        case .quests: return "Daily Quests"
        case .dex: return "Mutation Dex"
        case .achievements: return "Achievements"
        }
    }
}

// ---------- Daily Quests (full screen) ----------

private struct DailyQuestsSection: View {
    @ObservedObject private var store = GameStore.shared
    @State private var celebrate = false

    private var claimedCount: Int {
        store.todayQuests.filter { store.isQuestClaimed($0) }.count
    }

    /// Seconds until midnight, when new quests arrive.
    private func secondsUntilReset(from date: Date) -> Double {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else { return 0 }
        return max(0, tomorrow.timeIntervalSince(date))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                // Summary card
                VStack(spacing: 8) {
                    HStack {
                        Text("\(claimedCount) of \(store.todayQuests.count) done today")
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Wood.cream)
                        Spacer()
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Label("New in \(longTimeText(secondsUntilReset(from: context.date)))", systemImage: "clock.fill")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Wood.trim)
                        }
                    }
                    chunkyBar(fraction: store.todayQuests.isEmpty ? 0 : Double(claimedCount) / Double(store.todayQuests.count),
                              color: Wood.gold)
                }
                .padding(14)
                .woodPanel(radius: 18)

                ForEach(store.todayQuests) { template in
                    QuestRow(template: template) {
                        celebrate = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { celebrate = false }
                    }
                }

                if !store.todayQuests.isEmpty && claimedCount == store.todayQuests.count {
                    VStack(spacing: 6) {
                        PixelIcon(name: "ach_greenthumb", size: 56)
                        Text("All quests complete!")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .foregroundStyle(Wood.gold)
                        Text("Come back tomorrow for three new ones.")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Wood.cream.opacity(0.9))
                    }
                    .padding(.top, 8)
                }
            }
            .padding()

            if celebrate { ConfettiBurst() }
        }
    }
}

/// A chunky wooden progress bar.
@ViewBuilder
private func chunkyBar(fraction: Double, color: Color) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(Wood.darker.opacity(0.7))
            Capsule()
                .fill(color)
                .frame(width: fraction > 0 ? max(10, geo.size.width * min(max(fraction, 0), 1)) : 0)
        }
    }
    .frame(height: 12)
    .overlay(Capsule().stroke(Wood.darker, lineWidth: 1.5))
}

private struct QuestRow: View {
    let template: QuestTemplate
    var onClaimed: () -> Void = {}
    @ObservedObject private var store = GameStore.shared

    private var progress: Double { store.questProgress(for: template.kind) }
    private var done: Bool { progress >= template.target }
    private var claimed: Bool { store.isQuestClaimed(template) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(claimed ? Wood.leaf : Wood.dark)
                Circle().stroke(claimed ? Color(hex: 0xA6E08A) : Wood.trim, lineWidth: 3)
                Image(systemName: claimed ? "checkmark" : template.icon)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Wood.cream)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Wood.cream)
                    .fixedSize(horizontal: false, vertical: true)
                chunkyBar(fraction: min(progress / max(template.target, 1), 1), color: claimed || done ? Wood.leaf : Wood.trim)
                HStack(spacing: 8) {
                    Text("\(Int(min(progress, template.target)))/\(Int(template.target))")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Wood.cream.opacity(0.85))
                    CoinLabel(amount: template.reward, size: 15, color: Wood.gold, signed: true)
                }
            }

            Spacer(minLength: 4)

            if claimed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(Wood.leaf)
            } else if done {
                Button {
                    if store.claimQuest(template) {
                        Haptics.success()
                        SoundPlayer.coin()
                        onClaimed()
                    }
                } label: {
                    LeafButtonLook(title: "Claim!", width: 84, height: 42)
                }
                .bouncy(haptic: false)
            }
        }
        .padding(12)
        .woodPanel(radius: 18, highlighted: done && !claimed)
        .opacity(claimed ? 0.8 : 1)
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

// ---------- Achievements (full screen) ----------

private struct AchievementsSection: View {
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        let total = Achievement.all.count
        let got = Achievement.all.filter { store.unlockedAchievements.contains($0.id) }.count
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                HStack {
                    Text("\(got) of \(total) unlocked")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Wood.cream)
                    Spacer()
                    Image(systemName: "trophy.fill").foregroundStyle(Wood.gold)
                }
                chunkyBar(fraction: total == 0 ? 0 : Double(got) / Double(total), color: Wood.gold)
            }
            .padding(14)
            .woodPanel(radius: 18)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Achievement.all) { achievement in
                    AchievementCard(achievement: achievement,
                                    unlocked: store.unlockedAchievements.contains(achievement.id))
                }
            }
        }
        .padding()
    }
}

private struct AchievementCard: View {
    let achievement: Achievement
    let unlocked: Bool
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        let progress = achievement.progress?(store)
        let fraction: Double = {
            guard let progress, progress.goal > 0 else { return unlocked ? 1 : 0 }
            return min(progress.current / progress.goal, 1)
        }()

        VStack(spacing: 8) {
            ZStack {
                Circle().fill(unlocked ? Wood.dark : Wood.darker.opacity(0.8)).frame(width: 84, height: 84)
                Circle().stroke(unlocked ? Wood.gold : Wood.dark, lineWidth: 4).frame(width: 84, height: 84)
                AchievementBadge(achievement: achievement, size: 54, unlocked: unlocked)
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Wood.cream.opacity(0.85))
                        .offset(x: 28, y: 28)
                }
            }
            Text(achievement.title)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(unlocked ? Wood.gold : Wood.cream)
                .multilineTextAlignment(.center)
            Text(achievement.detail)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Wood.cream.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if unlocked {
                Label("UNLOCKED", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Wood.leaf)
            } else {
                VStack(spacing: 4) {
                    chunkyBar(fraction: fraction, color: Wood.trim)
                    HStack(spacing: 6) {
                        if let progress {
                            Text(progressText(progress.current, progress.goal))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Wood.cream.opacity(0.85))
                        }
                        Spacer(minLength: 0)
                        CoinLabel(amount: achievement.reward, size: 13, color: Wood.gold)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 210)
        .woodPanel(radius: 18, highlighted: unlocked)
        .opacity(unlocked ? 1 : 0.9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title). \(achievement.detail). \(unlocked ? "Unlocked" : "Locked")")
    }

    /// Study time is shown in minutes or hours, the rest as plain counts.
    private func progressText(_ current: Double, _ goal: Double) -> String {
        if achievement.id.hasPrefix("study") {
            return "\(longTimeText(min(current, goal))) / \(longTimeText(goal))"
        }
        return "\(Int(min(current, goal)).formatted()) / \(Int(goal).formatted())"
    }
}

/// A button that opens the full-screen Hub, with a badge showing how many of
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
                Image(systemName: "trophy.fill")
                    .foregroundStyle(claimableCount > 0 ? Wood.gold : Wood.cream)
                Text("Quests & Trophies")
                    .foregroundStyle(Wood.cream)
            }
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .woodPanel(radius: 12)
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
