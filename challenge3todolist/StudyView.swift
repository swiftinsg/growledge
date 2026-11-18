import SwiftUI
import Combine

/// The Study page (opened by the Home "Study" button): a timer on top and the
/// to-do list underneath so tasks can be finished while studying.
struct StudyView: View {
    @ObservedObject private var todoStore = TodoStore.shared

    // Coins are the same "points" currency the garden shop uses,
    // so what you earn studying can be spent on seeds and sprinklers.
    @ObservedObject private var store = GameStore.shared
    @State private var lastReward: CoinReward?

    /// The tasks chosen when the session was started. Only these show in the
    /// to-do list below, and their subjects colour the session in History.
    @State private var sessionTaskIDs: Set<UUID> = []
    @State private var sessionSubjects: [Subject] = []
    @State private var sessionActive = false
    @State private var showingTaskPicker = false
    /// The timer's start action, held until the user has chosen their tasks.
    @State private var pendingStart: (() -> Void)?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 12) {
                HStack {
                    Text("Studying")
                        .font(.system(.title2, design: .serif, weight: .bold))
                    Spacer()
                    PointsPill()
                        .accessibilityLabel("\(store.points) coins")
                }
                .padding(.horizontal)
                .fadeIn(order: 0)

                if !sessionSubjects.isEmpty {
                    subjectTags
                        .fadeIn(order: 1)
                }

                // Top half: countdown timer
                TimerView(subjects: sessionSubjects, beforeStart: requestStart, onEnd: endSession)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal)
                    .fadeIn(order: 2)

                // Bottom half: the tasks chosen for this session, by subject
                ToDoListView(taskIDs: sessionTaskIDs, emptyTitle: "No tasks added yet!")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal)
                    .fadeIn(order: 3)
            }
            .padding(.vertical, 8)
            .tabFadeRoot()
        }
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTaskPicker) {
            TaskPickerSheet(onStart: startSession)
        }
        .alert("Session Complete", isPresented: showingResult, presenting: lastReward) { _ in
            Button("OK", role: .cancel) {}
        } message: { reward in
            Text(resultMessage(for: reward))
        }
    }

    /// The subjects of the chosen tasks (read-only; they come from the tasks).
    private var subjectTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sessionSubjects) { subject in
                    HStack(spacing: 6) {
                        Circle().fill(subject.color.color).frame(width: 9, height: 9)
                        Text(subject.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(subject.color.color.opacity(0.35), in: Capsule())
                    .overlay(Capsule().stroke(subject.color.color, lineWidth: 2))
                }
            }
            .padding(.horizontal)
        }
    }

    /// The first Start of a session asks which tasks it is for.
    private func requestStart(_ start: @escaping () -> Void) {
        if sessionActive {
            start()
        } else {
            pendingStart = start
            showingTaskPicker = true
        }
    }

    private func startSession(with taskIDs: Set<UUID>) {
        let chosen = todoStore.reminders.filter { taskIDs.contains($0.id) }
        let chosenSubjectIDs = Set(chosen.map(\.subject.id))
        withAnimation(.snappy) {
            sessionTaskIDs = taskIDs
            // Studying without any task is logged under "No Subject"
            sessionSubjects = chosen.isEmpty
                ? [Subject.none]
                : todoStore.allSubjects.filter { chosenSubjectIDs.contains($0.id) }
            sessionActive = true
        }
        pendingStart?()
        pendingStart = nil
    }

    private var showingResult: Binding<Bool> {
        Binding(
            get: { lastReward != nil },
            set: { if !$0 { lastReward = nil } }
        )
    }

    /// Awards coins for the finished session. (Task coins are paid
    /// the moment a task is finished, see TodoStore.toggleCompleted.)
    private func endSession(_ studiedSeconds: TimeInterval) {
        withAnimation(.snappy) {
            sessionActive = false
            sessionTaskIDs = []
            sessionSubjects = []
        }
        let reward = CoinReward(studiedSeconds: studiedSeconds)
        // Same shared `points` balance the garden shop and the to-do list use.
        store.points += reward.total
        Haptics.success()
        SoundPlayer.fanfare()
        lastReward = reward
    }

    private func resultMessage(for reward: CoinReward) -> String {
        "You studied for \(reward.minutes) min and earned +\(reward.total.formatted()) \(Theme.coin)"
    }
}

/// Shown when the user taps Start: pick the tasks this session is for.
struct TaskPickerSheet: View {
    @ObservedObject private var store = TodoStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    let onStart: (Set<UUID>) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.activeGroups) { group in
                    Section {
                        ForEach(group.tasks) { task in
                            Button {
                                if selected.contains(task.id) {
                                    selected.remove(task.id)
                                } else {
                                    selected.insert(task.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selected.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(task.id) ? group.subject.color.color : .secondary)
                                    Text(task.title)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    } header: {
                        SubjectHeader(subject: group.subject, count: group.tasks.count)
                    }
                }
            }
            .overlay {
                if store.activeGroups.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Add tasks in the To-Do List tab to link them to a session.")
                    )
                }
            }
            .navigationTitle("Choose Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(selected)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// =====================================================================
// MARK: - 9. RELAX TAB  (breathing exercises + the song library)
// =====================================================================

/// One step of a breathing pattern: breathe in, hold, or breathe out,
/// each with its own length in seconds.
enum BreathStep: String {
    case inhale = "Breathe In"
    case hold = "Hold"
    case exhale = "Breathe Out"
}

/// A named breathing pattern, e.g. box breathing (4-4-4-4).
struct BreathingTechnique: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    /// The pattern, repeated for as long as the exercise runs.
    let pattern: [(step: BreathStep, seconds: Double)]

    static let all: [BreathingTechnique] = [
        BreathingTechnique(
            name: "Box Breathing",
            subtitle: "4 in · 4 hold · 4 out · 4 hold — steadies you fast",
            pattern: [(.inhale, 4), (.hold, 4), (.exhale, 4), (.hold, 4)]
        ),
        BreathingTechnique(
            name: "4-7-8 Relaxing Breath",
            subtitle: "4 in · 7 hold · 8 out — good before sleep or a big worry",
            pattern: [(.inhale, 4), (.hold, 7), (.exhale, 8)]
        ),
        BreathingTechnique(
            name: "Calm Breathing",
            subtitle: "4 in · 6 out — simple, no holding your breath",
            pattern: [(.inhale, 4), (.exhale, 6)]
        )
    ]
}

/// The Relax page (opened by the Home tab's "Relax" tab): a few guided
/// breathing exercises, and the full song library to put something on
/// in the background while you breathe, or just to browse freely.
struct RelaxView: View {
    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Relax")
                            .font(.system(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("A short breathing exercise, or just something nice to listen to.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    .fadeIn(order: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Breathing Exercises", systemImage: "wind")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        ForEach(BreathingTechnique.all) { technique in
                            BreathingCard(technique: technique)
                        }
                    }
                    .fadeIn(order: 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Song Library", systemImage: "music.note.list")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text("Play anything in the app whenever you like — it keeps going if you switch tabs.")
                            .font(.caption)
                            .foregroundStyle(Theme.subtext)
                        SongLibraryList()
                    }
                    .fadeIn(order: 2)
                }
                .padding()
                .padding(.bottom, 20)
            }
            .tabFadeRoot()
        }
        .navigationTitle("Relax")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One breathing technique: tap Start, and a circle slowly grows and
/// shrinks in time with "Breathe In" / "Hold" / "Breathe Out", so there's
/// something to visually follow rather than just reading the words.
private struct BreathingCard: View {
    let technique: BreathingTechnique

    @State private var running = false
    @State private var currentStep: BreathStep = .inhale
    @State private var scale: CGFloat = 0.62
    @State private var runLoop: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(technique.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(technique.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.subtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Theme.good.opacity(0.55), Theme.accent.opacity(0.45)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)

                Text(running ? currentStep.rawValue : "Ready")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }
            .frame(height: 130)

            GameButton(title: running ? "Stop" : "Start",
                       icon: running ? "stop.fill" : "play.fill",
                       width: 140, height: 44) {
                running ? stop() : start()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.panelBorder, lineWidth: 1))
        .onDisappear { stop() }
    }

    private func start() {
        guard !running else { return }
        running = true
        SoundPlayer.select()
        runLoop = Task {
            var index = 0
            while !Task.isCancelled {
                let step = technique.pattern[index % technique.pattern.count]
                await MainActor.run {
                    currentStep = step.step
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: step.seconds)) {
                        switch step.step {
                        case .inhale: scale = 1.0
                        case .exhale: scale = 0.62
                        case .hold: break // stays exactly where it is
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(step.seconds * 1_000_000_000))
                index += 1
            }
        }
    }

    private func stop() {
        running = false
        runLoop?.cancel()
        runLoop = nil
        withAnimation(.easeOut(duration: 0.4)) { scale = 0.62 }
    }
}

/// Every track in the app (see `Music.library`), each with its own
/// play/stop control, sharing the one `MusicPlayer` the rest of the app
/// uses — so starting a song here is just like starting one anywhere else.
private struct SongLibraryList: View {
    @ObservedObject private var musicPlayer = MusicPlayer.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Music.library) { track in
                SongLibraryRow(track: track, isPlaying: musicPlayer.currentFile == track.file)
            }
        }
    }
}

private struct SongLibraryRow: View {
    let track: MusicTrack
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((isPlaying ? Theme.good : Theme.accent).opacity(0.3))
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "music.note")
                    .foregroundStyle(isPlaying ? Theme.good : Theme.text)
            }
            .frame(width: 38, height: 38)

            Text(track.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)

            Spacer()

            Button {
                Haptics.tap()
                if isPlaying {
                    SoundPlayer.pop()
                    MusicPlayer.shared.fadeOutAndStop()
                } else {
                    SoundPlayer.select()
                    MusicPlayer.shared.loop(track.file, volume: 0.35)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isPlaying ? Theme.bad : Theme.good)
            }
            .bouncy(haptic: false)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card.opacity(isPlaying ? 0.95 : 0.75)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isPlaying ? Theme.good.opacity(0.6) : Theme.panelBorder, lineWidth: isPlaying ? 2 : 1))
    }
}

#Preview {
    NavigationStack {
        StudyView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Relax") {
    NavigationStack {
        RelaxView()
    }
    .preferredColorScheme(.dark)
}
