import SwiftUI
import Combine

/// A Pomodoro timer styled after the Timer in Apple's Clock app.
/// The user picks a work length (saved between launches); the break is
/// derived automatically using a 5:1 work:break ratio (default 25:5).
struct TimerView: View {
    private enum TimerState {
        case idle, running, paused
    }

    private enum Phase {
        case work, rest

        var title: String { self == .work ? "Focus" : "Break" }
        var tint: Color { self == .work ? .orange : .green }
    }

    /// Work:break ratio: every 5 minutes of work earns 1 minute of break.
    private static let breakRatio = 5.0

    // Persisted so the user's custom work time is remembered on later launches.
    @AppStorage("workMinutes") private var workMinutes = 25
    @AppStorage("hasConfiguredWorkTime") private var hasConfiguredWorkTime = false

    @State private var phase: Phase = .work
    @State private var state: TimerState = .idle
    @State private var totalDuration: TimeInterval = 0
    @State private var remaining: TimeInterval = 0
    @State private var endDate: Date?
    @State private var tickTask: Task<Void, Never>?
    @State private var isEditingDuration = false
    /// Work time from finished or cancelled focus phases (breaks never count).
    @State private var completedStudyTime: TimeInterval = 0
    /// When the current stretch of focus time began (used for the History chart).
    @State private var segmentStart: Date?
    /// Whether the timer is taking over the whole screen right now.
    @State private var isFullScreen = false

    /// The user's own answer to "What do you hope to achieve from studying?",
    /// shown (among other goals) while the timer is full screen.
    @AppStorage("studyGoal") private var studyGoal = ""

    /// Unlocks the apps if this screen goes away while a focus phase is running.
    @StateObject private var lockSession = FocusLockSession()

    /// The subjects being studied; History colours the session with them.
    var subjects: [Subject] = []

    /// Lets the parent step in before the first focus phase starts (e.g. to
    /// choose tasks). It must call the closure it is given to actually start.
    var beforeStart: (@escaping () -> Void) -> Void = { $0() }

    /// Called with the total seconds studied when the user taps End.
    var onEnd: (TimeInterval) -> Void = { _ in }

    /// Finished work time plus the elapsed part of the current focus phase.
    private var studiedTime: TimeInterval {
        let current = (phase == .work && state != .idle) ? totalDuration - remaining : 0
        return completedStudyTime + max(0, current)
    }

    private var workDuration: TimeInterval { TimeInterval(workMinutes * 60) }
    private var breakDuration: TimeInterval { workDuration / Self.breakRatio }

    private var phaseDuration: TimeInterval {
        phase == .work ? workDuration : breakDuration
    }

    /// True during the break phase — used to make the screen feel like a
    /// reward (confetti, brighter colors, a fun track) instead of more work.
    private var isBreak: Bool { phase == .rest }

    /// While idle, show the full length of the upcoming phase.
    private var displayedTime: TimeInterval {
        state == .idle ? phaseDuration : remaining
    }

    private var progress: Double {
        guard state != .idle else { return 1 }
        return totalDuration > 0 ? remaining / totalDuration : 0
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                // Lets the user choose whether the timer takes over the
                // whole screen or stays docked above the to-do list.
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.3)) { isFullScreen = true }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.secondary.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Show timer full screen")
            }

            countdownRing
                .frame(maxHeight: .infinity)

            controls

            Button("End Session", role: .destructive) {
                endSession()
            }
            .buttonStyle(.bordered)
            .disabled(studiedTime == 0)
        }
        .padding()
        .fullScreenCover(isPresented: $isFullScreen) {
            FullScreenTimerView(
                ring: countdownRing,
                controls: controls,
                studyGoal: studyGoal,
                studiedTime: studiedTime,
                canEnd: studiedTime > 0,
                isBreak: isBreak,
                onEnd: endSession,
                onMinimize: { isFullScreen = false }
            )
        }
        .sheet(isPresented: $isEditingDuration) {
            WorkDurationSheet(workMinutes: $workMinutes, breakRatio: Self.breakRatio) {
                hasConfiguredWorkTime = true
                isEditingDuration = false
            }
            .presentationDetents([.medium])
            // On first launch the user must confirm a work time.
            .interactiveDismissDisabled(!hasConfiguredWorkTime)
        }
        .onAppear {
            if !hasConfiguredWorkTime {
                isEditingDuration = true
            }
            resumeTickingIfNeeded()
        }
        .onDisappear {
            // Stop the background loop; it restarts in onAppear if still running.
            tickTask?.cancel()
            tickTask = nil
            if state != .running { MusicPlayer.shared.fadeOutAndStop() }
        }
    }

    // MARK: - Subviews

    private var countdownRing: some View {
        ZStack {
            // A joyful little confetti sprinkle behind the ring during breaks.
            if isBreak {
                ConfettiLayer()
                    .clipShape(Circle())
                    .opacity(0.8)
            }

            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            VStack(spacing: 8) {
                Text(isBreak ? "🎉 \(phase.title) Time!" : phase.title)
                    .font(.headline)
                    .foregroundStyle(phase.tint)

                Text(formatted(displayedTime))
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                statusLabel
            }
            .padding(24)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Circle())
        // Tapping the ring while idle opens the duration editor.
        .onTapGesture {
            if state == .idle { isEditingDuration = true }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .idle:
            Button {
                isEditingDuration = true
            } label: {
                Label("\(workMinutes) min · \(formatted(breakDuration)) break", systemImage: "pencil")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .accessibilityLabel("Edit work time, currently \(workMinutes) minutes")
        case .running:
            if let endDate {
                // Clock app shows when the timer will finish
                Label(endDate.formatted(date: .omitted, time: .shortened), systemImage: "bell.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .paused:
            Label("Paused", systemImage: "pause.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack {
            circleButton("Cancel", foreground: .primary, background: .gray.opacity(0.3)) {
                cancel()
            }
            .disabled(state == .idle && phase == .work)
            .opacity(state == .idle && phase == .work ? 0.5 : 1)

            Spacer()

            switch state {
            case .idle:
                circleButton("Start", foreground: .green, background: .green.opacity(0.25)) {
                    beforeStart { start() }
                }
            case .running:
                circleButton("Pause", foreground: .orange, background: .orange.opacity(0.25)) {
                    pause()
                }
            case .paused:
                circleButton("Resume", foreground: .green, background: .green.opacity(0.25)) {
                    resume()
                }
            }
        }
        .padding(.horizontal)
    }

    private func circleButton(_ title: String, foreground: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .foregroundStyle(foreground)
                .frame(width: 80, height: 80)
                .background(Circle().fill(background))
                // Double ring look from the Clock app
                .overlay(Circle().stroke(background, lineWidth: 2).padding(-4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer logic

    private func start() {
        totalDuration = phaseDuration
        remaining = totalDuration
        state = .running
        if phase == .work { segmentStart = .now }
        // Breaks get their own fun track; focus time gets the study playlist.
        if phase == .work {
            MusicPlayer.shared.playPlaylist(Music.studyPlaylist)
        } else {
            MusicPlayer.shared.loop(Music.verityDisstrack)
        }
        runCountdown()
    }

    private func pause() {
        logStudySegment()
        tickTask?.cancel()
        tickTask = nil
        TimerNotifications.cancel()
        FocusLock.shared.unlock()
        if let endDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        endDate = nil
        state = .paused
        MusicPlayer.shared.pause()
    }

    private func resume() {
        state = .running
        if phase == .work { segmentStart = .now }
        MusicPlayer.shared.resume()
        runCountdown()
    }

    /// Stops the timer and resets the cycle back to a work session.
    /// Time already studied in the current focus phase is kept.
    private func cancel() {
        logStudySegment()
        bankCurrentStudyTime()
        stopTicking()
        phase = .work
    }

    /// Ends the whole session, reports the time studied, and resets everything.
    private func endSession() {
        let total = studiedTime
        logStudySegment()
        stopTicking()
        phase = .work
        completedStudyTime = 0
        onEnd(total)
    }

    private func bankCurrentStudyTime() {
        completedStudyTime = studiedTime
    }

    /// Saves the current stretch of focus time so it shows up in History.
    /// Breaks are never logged.
    private func logStudySegment() {
        guard phase == .work, let start = segmentStart else { return }
        // If the phase ran out while the app was in the background, only the
        // time up to its scheduled end was studied, not the time away.
        let end = min(.now, endDate ?? .now)
        StudyLogStore.shared.record(start: start, end: end, subjects: subjects)
        segmentStart = nil
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        TimerNotifications.cancel()
        FocusLock.shared.unlock()
        endDate = nil
        remaining = 0
        state = .idle
        MusicPlayer.shared.fadeOutAndStop()
    }

    /// Called when a phase runs out: work hands over to break and vice versa,
    /// and the next phase starts on its own so the timer runs until the
    /// user ends the session.
    private func finishPhase() {
        logStudySegment()
        bankCurrentStudyTime()
        stopTicking()
        phase = phase == .work ? .rest : .work
        start()
    }

    /// If the view reappears (e.g. after switching tabs) while a phase is
    /// still running, pick the countdown back up from the saved end date.
    private func resumeTickingIfNeeded() {
        guard state == .running, tickTask == nil, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        runCountdown()
    }

    /// Counts down against a fixed end date so the timer stays accurate
    /// even if individual ticks are delayed.
    private func runCountdown() {
        let target = Date.now.addingTimeInterval(remaining)
        endDate = target
        TimerNotifications.schedule(after: remaining, endingFocus: phase == .work)
        // Apps are blocked during focus time only; breaks are free
        if phase == .work {
            FocusLock.shared.lock()
        } else {
            FocusLock.shared.unlock()
        }
        tickTask?.cancel()
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                remaining = max(0, target.timeIntervalSinceNow)
                if remaining <= 0 {
                    finishPhase()
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// Formats seconds as H:MM:SS or MM:SS, rounding up like the Clock app.
    private func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

/// Half-height sheet for choosing the work length, with a live preview
/// of the automatically calculated break.
private struct WorkDurationSheet: View {
    @Binding var workMinutes: Int
    let breakRatio: Double
    let onDone: () -> Void

    @State private var draftMinutes: Int

    init(workMinutes: Binding<Int>, breakRatio: Double, onDone: @escaping () -> Void) {
        _workMinutes = workMinutes
        self.breakRatio = breakRatio
        self.onDone = onDone
        _draftMinutes = State(initialValue: workMinutes.wrappedValue)
    }

    private var breakText: String {
        let breakSeconds = Int((Double(draftMinutes * 60) / breakRatio).rounded())
        let m = breakSeconds / 60
        let s = breakSeconds % 60
        return s == 0 ? "\(m) min" : "\(m) min \(s) sec"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Work time", selection: $draftMinutes) {
                    ForEach(1...120, id: \.self) { value in
                        Text("\(value) min").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Label("Break: \(breakText)", systemImage: "cup.and.saucer.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .animation(.default, value: draftMinutes)
            }
            .padding()
            .navigationTitle("Work Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        workMinutes = draftMinutes
                        onDone()
                    }
                }
            }
        }
    }
}

/// A little piece of falling, tumbling confetti.
private struct ConfettiPiece {
    let x: Double        // 0...1 across the width
    let speed: Double
    let phase: Double
    let spin: Double
    let size: Double
    let color: Color
}

/// A cheerful sprinkle of falling confetti — used to make the break phase
/// feel like a reward rather than more of the same screen.
private struct ConfettiLayer: View {
    private static let colors: [Color] = [
        Color(red: 1.00, green: 0.45, blue: 0.45),
        Color(red: 1.00, green: 0.78, blue: 0.30),
        Color(red: 0.45, green: 0.85, blue: 0.55),
        Color(red: 0.40, green: 0.70, blue: 1.00),
        Color(red: 0.85, green: 0.55, blue: 1.00)
    ]

    private static let pieces: [ConfettiPiece] = (0..<40).map { _ in
        ConfettiPiece(
            x: Double.random(in: 0...1),
            speed: Double.random(in: 0.25...0.55),
            phase: Double.random(in: 0...1),
            spin: Double.random(in: 1...4) * (Bool.random() ? 1 : -1),
            size: Double.random(in: 5...10),
            color: colors.randomElement() ?? .yellow
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for piece in Self.pieces {
                    let progress = (t * piece.speed + piece.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 30) - 15
                    let x = piece.x * size.width + sin(t * piece.speed * 2 + piece.phase * 6) * 14
                    var transform = CGAffineTransform(translationX: x, y: y)
                    transform = transform.rotated(by: t * piece.spin)
                    var square = context
                    square.transform = transform
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 2, width: piece.size, height: piece.size * 0.6)
                    square.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color.opacity(0.9)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The timer taking over the whole screen: the same ring and controls as the
/// docked view, plus a rotating panel underneath — study goals while
/// focused, or a joyful "take a breather" panel with confetti on break.
private struct FullScreenTimerView<Ring: View, Controls: View>: View {
    let ring: Ring
    let controls: Controls
    let studyGoal: String
    let studiedTime: TimeInterval
    let canEnd: Bool
    var isBreak: Bool = false
    let onEnd: () -> Void
    let onMinimize: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isBreak {
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.28, blue: 0.22), Color(red: 0.05, green: 0.12, blue: 0.10)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    ConfettiLayer().ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Top half: the clock.
                    VStack(spacing: 14) {
                        HStack {
                            Button {
                                Haptics.tap()
                                onMinimize()
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(10)
                                    .background(.white.opacity(0.08), in: Circle())
                            }
                            .accessibilityLabel("Exit full screen")
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        ring
                            .padding(.horizontal, 28)
                            .frame(maxHeight: .infinity)

                        controls
                            .padding(.bottom, 4)
                    }
                    .frame(height: geo.size.height / 2)

                    Divider().overlay(.white.opacity(0.08))

                    // Bottom half: study goals while focused, or a joyful
                    // "take a breather" panel with Verity Disstrack playing on break.
                    MotivationalGoalsPanel(studyGoal:
                                            
                                            studyGoal, isBreak: isBreak)
                        .frame(height: geo.size.height / 2)
                        .frame(maxWidth: .infinity)
                }
                
            }
            .safeAreaInset(edge: .bottom) {
                Button("End Session", role: .destructive) { onEnd() }
                    .buttonStyle(.bordered)
                    .disabled(!canEnd)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.black)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Cycles through encouraging study goals every few seconds while focused;
/// every fourth turn it surfaces the user's own "what I hope to achieve"
/// answer instead. On a break it switches to cheerful, no-pressure messages
/// instead, since a break isn't the place for more studying prompts.
private struct MotivationalGoalsPanel: View {
    let studyGoal: String
    var isBreak: Bool = false

    private static let genericGoals: [String] = [
        "Stay focused — future you is counting on this.",
        "Small steps now, big results later.",
        "Discipline beats motivation. Keep going.",
        "One page, one problem, one step at a time.",
        "You don't have to be perfect, just consistent.",
        "This hour is an investment in yourself.",
        "Progress, not perfection.",
        "Deep work now, deserved rest later."
    ]

    private static let breakMessages: [String] = [
        "🎉 Nice work! Stretch, breathe, and enjoy this.",
        "☕️ Grab a drink, look away from the screen for a bit.",
        "🙌 You earned this break — make it count.",
        "💃 Dance it out for a second if you want to.",
        "🌤️ Rest the eyes, rest the mind. Back soon!",
        "🎶 Enjoy the tune — no studying allowed right now."
    ]

    @State private var index = 0

    private var showsOwnGoal: Bool {
        !isBreak && !studyGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && index % 4 == 3
    }

    private var currentText: String {
        if isBreak { return Self.breakMessages[index % Self.breakMessages.count] }
        return showsOwnGoal ? "Remember why: \(studyGoal)" : Self.genericGoals[index % Self.genericGoals.count]
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isBreak ? "party.popper.fill" : (showsOwnGoal ? "flag.checkered" : "quote.opening"))
                .font(.title2)
                .foregroundStyle(isBreak ? Color(red: 0.55, green: 0.95, blue: 0.65) : (showsOwnGoal ? Color(red: 0.98, green: 0.82, blue: 0.45) : .secondary))

            Text(currentText)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isBreak ? Color(red: 0.75, green: 1.0, blue: 0.82) : (showsOwnGoal ? Color(red: 0.98, green: 0.82, blue: 0.45) : Color.white.opacity(0.85)))
                .padding(.horizontal, 28)
        }
        .id(index)
        // A plain cross-fade — no sliding/flying in, just dissolves between quotes.
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.04))
        .animation(.easeInOut(duration: 0.7), value: index)
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                index += 1
            }
    }
}

#Preview {
    TimerView()
}
