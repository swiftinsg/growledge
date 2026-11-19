//
//  ContentView.swift
//  The app
//
//  Created by T Krobot on 12/11/26.
//

import SwiftUI

/// The root of the app. First-time users see the two questions
/// (FirstTimerView + Q2View); after that they get the tabs.
struct ContentView: View {
    // Weekly goal in hours (set by the second question). Used by the progress bar.
    @AppStorage("hisgoal") private var goalTime = 100.0
    // The answer to "What do you hope to achieve from studying?" (first question)
    @AppStorage("studyGoal") private var studyGoal = ""
    // False until the questions have been answered, so first timers see them first.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // False until the first-time walkthrough has been shown (or skipped).
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    // The study log drives both the progress bar and the streak.
    @ObservedObject private var log = StudyLogStore.shared
    // Watched here (not just in the Hub) so an achievement unlock banner can
    // pop up no matter which tab is open when it happens.
    @ObservedObject private var store = GameStore.shared

    @Environment(\.scenePhase) private var scenePhase

    @State private var gameStarted = false
    @State private var showBar = true
    @State private var showStreak = true
    @State private var showButton = true
    @State private var showingHub = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabs
                    .transition(.opacity)
                    .overlay {
                        if !hasSeenTutorial {
                            TutorialOverlay {
                                withAnimation { hasSeenTutorial = true }
                            }
                        }
                    }
            } else {
                FirstTimerView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasCompletedOnboarding)
        // The whole app uses the moody garden look, which suits dark mode
        .preferredColorScheme(.dark)
        // All text throughout the app (every screen, every .font(...) that
        // doesn't pick its own design) renders in a serif typeface.
        .fontDesign(.serif)
        // Plants keep growing while the app is in the background or closed:
        // catch up when we come back, and save when we leave.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                GameStore.shared.advance()
                // The user may have changed Screen Time access in Settings
                FocusLock.shared.refreshAuthorization()
            case .background:
                GameStore.shared.advance()
                GameStore.shared.save()
            default: break
            }
        }
        // Pops up over whatever's on screen — garden, study, to-do, anywhere —
        // the instant an achievement unlocks, then clears itself after a beat.
        .overlay(alignment: .top) {
            if let achievement = store.pendingAchievementUnlock {
                AchievementUnlockBanner(achievement: achievement)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                            withAnimation { store.pendingAchievementUnlock = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: store.pendingAchievementUnlock?.id)
        .sheet(isPresented: $showingHub) {
            GameHubView()
        }
    }

    private var mainTabs: some View {
        TabView {
            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            Todolist()
                .tabItem {
                    Label("To-Do List", systemImage: "checklist")
                }

            NavigationStack {
                RelaxView()
            }
            .tabItem {
                Label("Relax", systemImage: "wind")
            }
        }
    }

    // MARK: - Weekly progress and streak

    /// Seconds studied so far this week.
    private var studiedSeconds: TimeInterval {
        log.seconds(inWeekOf: .now)
    }

    /// Studied hours divided by the weekly goal (can go above 1).
    private var progressRaw: Double {
        guard goalTime > 0 else { return 0 }
        return studiedSeconds / 3600 / goalTime
    }

    /// 0...1 for the bar itself, safe even if the goal is 0.
    private var progress: Double {
        min(max(progressRaw, 0), 1)
    }

    /// e.g. "2h 5m"
    private func hoursText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    // MARK: - Home tab

    private var homeTab: some View {
        NavigationStack {
            ZStack {
                // The garden only shows on the Home tab
                GardenBackground()
                    .onTapGesture {
                        if !gameStarted && showBar {
                            Haptics.tap()
                            startGame()
                        }
                    }

                // Home HUD: mission, progress bar, streak, and the Study link
                VStack(spacing: 18) {
                    if !studyGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        MissionBanner(goal: studyGoal)
                            .fadeIn(order: 0)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        progressBar
                            .opacity(showBar ? 1 : 0)
                            .scaleEffect(showBar ? 1 : 0.8)
                            .blur(radius: showBar ? 0 : 10)
                            .fadeIn(order: 1)

                        streakBadge
                            .opacity(showStreak ? 1 : 0)
                            .scaleEffect(showStreak ? 1 : 0.5)
                            .blur(radius: showStreak ? 0 : 10)
                            .fadeIn(order: 2)

                        // Today's quests, the Mutation Dex and Achievements —
                        // all behind this one button instead of three.
                        HubButton(showingHub: $showingHub)
                            .opacity(showStreak ? 1 : 0)
                            .scaleEffect(showStreak ? 1 : 0.5)
                            .blur(radius: showStreak ? 0 : 10)
                            .fadeIn(order: 2)
                    }

                    Spacer()

                    // The Study button is a NavigationLink to the study screen
                    NavigationLink {
                        StudyView()
                    } label: {
                        Text("Study")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 200, height: 80)
                            .background {
                                Image("Image 1")
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.4), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                    }
                    .bouncy()
                    .opacity(showButton ? 1 : 0)
                    .scaleEffect(showButton ? 1 : 0.5)
                    .blur(radius: showButton ? 0 : 10)
                    .allowsHitTesting(showButton && !gameStarted)
                    .fadeIn(order: 3)

                    Spacer()
                }
                .padding()
                .allowsHitTesting(!gameStarted)

                // The garden game sits on top of everything once started
                if gameStarted {
                    Game(onExit: exitGame)
                        .transition(.opacity)
                }
            }
            .tabFadeRoot()
            .toolbar(.hidden, for: .navigationBar)
            // Hide the tab bar while playing the garden game
            .toolbar(gameStarted ? .hidden : .visible, for: .tabBar)
        }
    }

    /// Shows how much of this week's study goal is done:
    /// hours studied this week out of the hours in the goal.
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))

                    Capsule()
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        // a small sliver shows as soon as any time is studied
                        .frame(width: progress > 0 ? max(geo.size.width * progress, 14) : 0)

                    Text("\(Int(progressRaw * 100))%")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 2))
            .animation(.easeOut(duration: 0.8), value: progress)

            // e.g. "1h 30m of 10h this week"
            Text("\(hoursText(studiedSeconds)) of \(goalTime.formatted(.number.precision(.fractionLength(0...1))))h this week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly progress \(Int(progressRaw * 100)) percent, \(hoursText(studiedSeconds)) studied")
    }

    /// Days studied in a row (see StudyLogStore.currentStreak).
    private var streakBadge: some View {
        let streak = log.currentStreak()
        return VStack(spacing: 0) {
            Text(" \(Image(systemName: "flame.fill")) \(streak)")
                .bold()
                .foregroundStyle(streak > 0 ? .orange : .gray)
                .font(.title2)
                .shadow(color: streak > 0 ? .orange.opacity(0.6) : .clear, radius: 10)
                .contentTransition(.numericText())
            Text("day streak")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day study streak")
    }

    // MARK: - Game transitions

    private func startGame() {
        withAnimation(.easeIn(duration: 0.4)) {
            showBar = false
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
            showStreak = false
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.4)) {
            showButton = false
        }
        withAnimation(.easeIn.delay(0.8)) {
            gameStarted = true
        }
    }

    private func exitGame() {
        withAnimation(.easeOut(duration: 0.4)) {
            gameStarted = false
            showBar = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            showStreak = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            showButton = true
        }
    }
}

/// The user's answer to "What do you hope to achieve from studying?", shown
/// as a quest-style objective card that matches the rest of the game's UI
/// (same texture as every button) instead of a generic glowing banner.
struct MissionBanner: View {
    let goal: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.good.opacity(0.9))
                Image(systemName: "flag.checkered")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 1) {
                Text("YOUR GOAL")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.subtext)
                Text(goal)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Image(Theme.buttonImage)
                    .resizable()
                    .scaledToFill()
                Theme.backdropTop.opacity(0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
