import SwiftUI

/// A Pomodoro timer styled after the Timer in Apple's Clock app.
/// The user picks a work length (saved between launches); the break is
/// derived automatically using a 5:1 work:break ratio (default 25:5).
struct TimerView: View {
    private enum TimerState {
        case idle, running, paused
    }

    private enum Phase {
        case work, rest

        var title: String { self == .work ? "Folus" : "Break" }
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
        }
    }

    // MARK: - Subviews

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            VStack(spacing: 8) {
                Text(phase.title)
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
        runCountdown()
    }

    private func pause() {
        logStudySegment()
        tickTask?.cancel()
        tickTask = nil
        if let endDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        endDate = nil
        state = .paused
    }

    private func resume() {
        state = .running
        if phase == .work { segmentStart = .now }
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
        StudyLogStore.shared.record(start: start, end: .now, subjects: subjects)
        segmentStart = nil
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        endDate = nil
        remaining = 0
        state = .idle
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

#Preview {
    TimerView()
}
