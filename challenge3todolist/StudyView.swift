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
                        .font(.system(.title2, design: .rounded, weight: .bold))
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
        store.points += reward.total
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

#Preview {
    NavigationStack {
        StudyView()
    }
    .preferredColorScheme(.dark)
}
