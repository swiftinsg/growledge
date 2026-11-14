import SwiftUI
import Combine

/// The to-do list shown on the Study page (and reused by the To-Do List tab).
/// It lists every unfinished task, organised by subject, so the user can
/// finish tasks right while studying.
struct ToDoListView: View {
    /// Only show these tasks (nil = every task).
    var taskIDs: Set<UUID>? = nil
    var emptyTitle = "No tasks yet!"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("To-Do List")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                Text("+\(CoinReward.bonusPerTask.formatted()) \(Theme.coin) per task")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            GroupedTaskList(taskIDs: taskIDs, emptyTitle: emptyTitle)
        }
    }
}

/// Tasks grouped under a coloured heading per subject, with a
/// "Completed" section at the bottom. Used by both the To-Do List tab and
/// the Study page so they always show the same thing.
struct GroupedTaskList: View {
    @ObservedObject private var store = TodoStore.shared

    /// Only show these tasks (nil = every task).
    var taskIDs: Set<UUID>? = nil
    /// Also list subjects that have no tasks, and let the user delete them.
    var managesSubjects = false
    var emptyTitle = "No tasks yet!"
    var emptyDescription: String? = nil

    @State private var subjectToDelete: Subject?

    private func isShown(_ task: Reminder) -> Bool {
        taskIDs?.contains(task.id) ?? true
    }

    var body: some View {
        let completed = store.completedTasks.filter(isShown)
        let groups: [TaskGroup] = store.allSubjects.compactMap { subject in
            let tasks = store.reminders
                .filter { $0.subject.id == subject.id && !$0.isCompleted && isShown($0) }
                .sorted { $0.dueDate < $1.dueDate }
            // Empty subjects stay visible when managing, except the built-in "No Subject"
            let keepsEmpty = managesSubjects && subject.id != Subject.none.id
            return (tasks.isEmpty && !keepsEmpty) ? nil : TaskGroup(subject: subject, tasks: tasks)
        }

        List {
            // Running number so rows fade in one after the other
            let orders = rowOrders(for: groups)

            ForEach(groups) { group in
                Section {
                    if group.tasks.isEmpty {
                        Text("No tasks yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .rowStyle()
                    }
                    ForEach(group.tasks) { task in
                        TaskRow(task: task)
                            .fadeIn(order: orders[task.id] ?? 0)
                            .rowStyle()
                            .swipeActions {
                                Button(role: .destructive) {
                                    withAnimation { store.delete(task.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    SubjectHeader(subject: group.subject, count: group.tasks.count,
                                  onDelete: (managesSubjects && group.subject.id != Subject.none.id)
                                      ? { subjectToDelete = group.subject } : nil)
                }
            }

            if !completed.isEmpty {
                Section {
                    ForEach(completed) { task in
                        TaskRow(task: task, showsSubject: true)
                            .rowStyle()
                            .swipeActions {
                                Button(role: .destructive) {
                                    withAnimation { store.delete(task.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text("Completed")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") {
                            withAnimation { store.clearCompleted() }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if groups.isEmpty && completed.isEmpty {
                if let emptyDescription {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "checklist",
                        description: Text(emptyDescription)
                    )
                } else {
                    Text(emptyTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Delete \(subjectToDelete?.name ?? "subject")?",
            isPresented: Binding(get: { subjectToDelete != nil }, set: { if !$0 { subjectToDelete = nil } }),
            titleVisibility: .visible,
            presenting: subjectToDelete
        ) { subject in
            Button("Delete Subject and Its Tasks", role: .destructive) {
                withAnimation { store.deleteSubject(subject.id) }
            }
        } message: { _ in
            Text("All tasks in this subject will be deleted too.")
        }
    }

    /// Position of each task in the list, used to stagger the fade-in.
    private func rowOrders(for groups: [TaskGroup]) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        var next = 0
        for task in groups.flatMap(\.tasks) {
            result[task.id] = min(next, 12)   // cap so long lists don't wait forever
            next += 1
        }
        return result
    }
}

private extension View {
    /// Frosted-glass row on top of the garden background.
    func rowStyle() -> some View {
        self
            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
            .listRowSeparatorTint(.white.opacity(0.15))
    }
}

/// The coloured heading above one subject's tasks.
struct SubjectHeader: View {
    let subject: Subject
    let count: Int
    /// When set, a menu with "Delete Subject" is shown.
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(subject.color.color)
                .frame(width: 10, height: 10)
            Text(subject.name.uppercased())
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(subject.color.color)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(subject.color.color.opacity(0.6), in: Capsule())

            if let onDelete {
                Menu {
                    Button("Delete Subject", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Subject options")
            }
        }
    }
}

/// One task. Tapping the circle finishes it: the row ticks, then fades out
/// (blurring and sliding away) while the coin reward floats up.
struct TaskRow: View {
    let task: Reminder
    /// Active tasks sit under their subject heading; the Completed section has none.
    var showsSubject = false
    @ObservedObject private var store = TodoStore.shared

    /// True while the "finishing" animation plays.
    @State private var fading = false
    /// Drives the "+15,000" label floating upwards.
    @State private var floatUp = false

    private var isOverdue: Bool {
        !task.isCompleted && task.dueDate < .now
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            rowContent
                .opacity(fading ? 0 : 1)
                .scaleEffect(fading ? 0.92 : 1, anchor: .leading)
                .blur(radius: fading ? 8 : 0)
                .offset(x: fading ? 60 : 0)

            // The reward that pops up as the task disappears
            if fading && !task.rewarded {
                Text("+\(CoinReward.bonusPerTask.formatted()) \(Theme.coin)")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.7), radius: 8)
                    .offset(y: floatUp ? -26 : 0)
                    .opacity(floatUp ? 0 : 1)
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Completion circle
            Button {
                complete()
            } label: {
                Image(systemName: (fading || task.isCompleted) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle((fading || task.isCompleted) ? task.subject.color.color : .secondary)
                    .symbolEffect(.bounce, value: fading)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                if showsSubject {
                    Text(task.subject.name)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(task.subject.color.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(task.subject.color.color.opacity(0.18), in: Capsule())
                }

                // Title
                Text(task.title)
                    .font(.system(.headline, design: .rounded))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                // Due date (red once it has passed)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(task.dueDate, style: .date)
                    Text("at")
                    Text(task.dueDate, style: .time)
                }
                .font(.caption)
                .foregroundStyle(isOverdue ? Color.red : Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func complete() {
        guard !fading else { return }

        // Un-ticking a finished task needs no fancy animation
        if task.isCompleted {
            withAnimation(.easeOut(duration: 0.25)) { store.toggleCompleted(task.id) }
            return
        }

        withAnimation(.easeIn(duration: 0.65)) { fading = true }
        withAnimation(.easeOut(duration: 0.9)) { floatUp = true }

        // Once the fade has played, actually move the task to Completed
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.3)) { store.toggleCompleted(task.id) }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        ToDoListView()
    }
    .preferredColorScheme(.dark)
}
