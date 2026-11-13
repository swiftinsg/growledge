//
//  ContentView.swift
//  The app
//
//  Created by T Krobot on 12/11/26.
//

import SwiftUI

/// The root of the app. First-time users see the two questions
/// (firsttimer + Q2View); after that they get the tabs.
struct ContentView: View {
    // Weekly goal in hours (set by the second question). Used by the progress bar.
    @AppStorage("hisgoal") private var goalTime = 100.0
    // The answer to "What do you hope to achieve from studying?" (first question)
    @AppStorage("studyGoal") private var studyGoal = ""
    // False until the questions have been answered, so first timers see them first.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // The study log drives both the progress bar and the streak.
    @ObservedObject private var log = StudyLogStore.shared

    @State private var gameStarted = false
    @State private var showBar = true
    @State private var showStreak = true
    @State private var showButton = true

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabs
                    .transition(.opacity)
            } else {
                firsttimer()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: hasCompletedOnboarding)
        // The whole app uses the moody garden look, which suits dark mode
        .preferredColorScheme(.dark)
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
                    .buttonStyle(.plain)
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

/// The user's answer to "What do you hope to achieve from studying?",
/// shown big and glowing at the top of the Home screen.
struct MissionBanner: View {
    let goal: String

    private let gold = Color(red: 0.98, green: 0.82, blue: 0.45)

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                Text("YOUR MISSION")
                    .tracking(2)
                Image(systemName: "sparkle")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(gold)

            Text(goal)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(colors: [gold, .white, gold], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: gold.opacity(0.6), radius: 10)
                .minimumScaleFactor(0.6)
                .lineLimit(3)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LinearGradient(colors: [gold, gold.opacity(0.1), gold], startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 1.5)
        )
        // A slow breathing glow
        .phaseAnimator([false, true]) { view, glow in
            view.shadow(color: gold.opacity(glow ? 0.55 : 0.15), radius: glow ? 26 : 8)
        } animation: { _ in
            .easeInOut(duration: 2.2)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
