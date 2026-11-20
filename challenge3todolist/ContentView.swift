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

            // The garden has its own tab; Home only shows the plants behind it.
            NavigationStack {
                Game()
            }
            .tabItem {
                Label("Garden", systemImage: "leaf.fill")
            }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            Todolist()
                .tabItem {
                    Label("To-Do List", systemImage: "checklist")
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
                // The plants you have growing, shown behind the Home card
                GardenBackground()

                VStack(spacing: 18) {
                    // One tidy card: goal and streak on top, the weekly bar,
                    // then hours studied and the Hub button underneath.
                    homeCard
                        .fadeIn(order: 1)

                    Spacer()

                    // The Study button is a NavigationLink to the study screen
                    NavigationLink {
                        StudyView()
                    } label: {
                        Text("Study")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.buttonText)
                            .frame(width: 200, height: 72)
                            .background { ButtonBackground() }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    }
                    .bouncy()
                    .fadeIn(order: 3)

                    Spacer()
                }
                .padding()
            }
            .tabFadeRoot()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var trimmedGoal: String {
        studyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The Home card: goal + streak, the weekly bar, hours studied + Hub.
    private var homeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if !trimmedGoal.isEmpty {
                    Label(trimmedGoal, systemImage: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                streakChip
            }

            // Weekly progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(Theme.good)
                        // a small sliver shows as soon as any time is studied
                        .frame(width: progress > 0 ? max(geo.size.width * progress, 12) : 0)
                }
            }
            .frame(height: 12)
            .animation(.easeOut(duration: 0.8), value: progress)

            HStack {
                // e.g. "1h 30m of 10h this week · 15%"
                Text("\(hoursText(studiedSeconds)) of \(goalTime.formatted(.number.precision(.fractionLength(0...1))))h this week · \(Int(progressRaw * 100))%")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                // Today's quests, the Mutation Dex and Achievements
                HubButton(showingHub: $showingHub)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.panelBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    /// Days studied in a row (see StudyLogStore.currentStreak).
    private var streakChip: some View {
        let streak = log.currentStreak()
        return HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(streak) \(streak == 1 ? "day" : "days")")
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(streak > 0 ? Color.orange : Theme.subtext)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(streak > 0 ? Color.orange.opacity(0.16) : Color.white.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day study streak")
    }
}

#Preview {
    ContentView()
}
