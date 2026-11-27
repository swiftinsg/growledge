//
//  TodoStore.swift
//  The app
//
//  The data behind the to-do list: subjects, tasks and the shared store.
//

import SwiftUI
import Combine

/// Colour options the user can pick from when creating a subject.
/// Codable so a subject (and its colour) can be saved.
enum SubjectColor: String, CaseIterable, Identifiable, Codable {
    case red, orange, yellow, green, blue, purple, pink
    /// Only used by the built-in "No Subject"; not offered when creating a subject.
    case gray

    var id: String { rawValue }

    /// The colours the user can pick from.
    static var choices: [SubjectColor] { allCases.filter { $0 != .gray } }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .gray: .gray
        }
    }
}

/// A category such as "Math". Tasks belong to a subject and studying
/// is logged against a subject, which gives History its colours.
struct Subject: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var color: SubjectColor

    /// The built-in subject for tasks (and study time) that belong to no subject.
    /// It has a fixed id and is never saved with the user's own subjects.
    static let none = Subject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                              name: "No Subject", color: .gray)

    /// Common subjects offered as one-tap suggestions when adding a subject.
    /// The first four are also what a brand-new install starts with. (No
    /// language subjects, since everyone studies a different mother tongue.)
    static let suggestions: [Subject] = [
        Subject(name: "Math", color: .blue),
        Subject(name: "English", color: .red),
        Subject(name: "Science", color: .green),
        Subject(name: "Humanities", color: .orange),
        Subject(name: "Physics", color: .purple),
        Subject(name: "Chemistry", color: .yellow),
        Subject(name: "Biology", color: .pink),
        Subject(name: "History", color: .orange),
        Subject(name: "Geography", color: .green),
        Subject(name: "Computing", color: .blue),
        Subject(name: "Economics", color: .yellow),
        Subject(name: "Literature", color: .red),
        Subject(name: "Art", color: .pink),
        Subject(name: "Music", color: .purple)
    ]

    /// The subjects a new user starts with. They can be renamed or deleted
    /// like any other, and once deleted they don't come back.
    static var starterSubjects: [Subject] { Array(suggestions.prefix(4)) }
}

/// One to-do item.
struct Reminder: Identifiable, Codable {
    var id = UUID()
    var title: String
    var dueDate: Date
    var subject: Subject
    var isCompleted: Bool = false
    /// True once the task-completion coins were paid out, so un-ticking and
    /// ticking a task again can't be used to farm coins.
    var rewarded: Bool = false
}

/// The tasks of one subject (used to show the list organised by subject).
struct TaskGroup: Identifiable {
    let subject: Subject
    let tasks: [Reminder]
    var id: UUID { subject.id }
}

/// Shared source of truth for subjects and tasks, so the to-do list tab
/// and the study page see the same data. Saved to UserDefaults on every change.
@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    static let subjectsKey = "todo.subjects"
    static let remindersKey = "todo.reminders"
    /// Set once the starter subjects were offered, so deleting them sticks.
    static let seededKey = "todo.starterSubjectsAdded"

    private let defaults: UserDefaults

    /// False while the saved data is being loaded. `didSet` on a @Published
    /// property DOES run inside `init`, so without this guard loading the
    /// subjects would save the still-empty task list over the real one, and
    /// every task would be lost each time the app starts.
    private var isLoaded = false

    @Published var subjects: [Subject] = [] {
        didSet { save() }
    }
    @Published var reminders: [Reminder] = [] {
        didSet { save() }
    }

    /// Tasks whose "finishing" fade is playing right now (never saved).
    @Published var finishingIDs: Set<UUID> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.subjectsKey),
           let saved = try? JSONDecoder().decode([Subject].self, from: data) {
            subjects = saved
        }
        if let data = defaults.data(forKey: Self.remindersKey),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = saved
        }

        // First launch ever: start with a few common subjects. Anyone who
        // already has saved subjects (or tasks) keeps exactly what they have.
        if !defaults.bool(forKey: Self.seededKey) {
            let isNewUser = defaults.data(forKey: Self.subjectsKey) == nil
                && defaults.data(forKey: Self.remindersKey) == nil
            if isNewUser { subjects = Subject.starterSubjects }
            defaults.set(true, forKey: Self.seededKey)
        }

        isLoaded = true
        save()
    }

    private func save() {
        guard isLoaded else { return }
        defaults.set(try? JSONEncoder().encode(subjects), forKey: Self.subjectsKey)
        defaults.set(try? JSONEncoder().encode(reminders), forKey: Self.remindersKey)
    }

    /// True if a subject with this name already exists (ignoring case and spaces).
    func hasSubject(named name: String) -> Bool {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        return subjects.contains { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == wanted }
    }

    /// Adds a subject unless one with that name already exists. Returns whether it was added.
    @discardableResult
    func addSubject(_ subject: Subject) -> Bool {
        let name = subject.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !hasSubject(named: name) else { return false }
        var added = subject
        added.name = name
        subjects.append(added)
        return true
    }

    /// The suggested subjects that the user doesn't have yet.
    var availableSuggestions: [Subject] {
        Subject.suggestions.filter { !hasSubject(named: $0.name) }
    }

    /// Adds several subjects at once (skipping any that already exist).
    /// Returns how many were added.
    @discardableResult
    func addSubjects(_ list: [Subject]) -> Int {
        list.reduce(0) { $0 + (addSubject($1) ? 1 : 0) }
    }

    /// The user's subjects followed by the built-in "No Subject".
    var allSubjects: [Subject] { subjects + [Subject.none] }

    /// Unfinished tasks organised by subject (one group per subject that has
    /// tasks), each group sorted by due date.
    var activeGroups: [TaskGroup] {
        allSubjects.compactMap { subject in
            let tasks = reminders
                .filter { $0.subject.id == subject.id && !$0.isCompleted }
                .sorted { $0.dueDate < $1.dueDate }
            return tasks.isEmpty ? nil : TaskGroup(subject: subject, tasks: tasks)
        }
    }

    /// Finished tasks, newest due date first.
    var completedTasks: [Reminder] {
        reminders.filter(\.isCompleted).sorted { $0.dueDate > $1.dueDate }
    }

    /// Ticks or un-ticks a task. The first time a task is finished it pays
    /// out `CoinReward.bonusPerTask` coins.
    func toggleCompleted(_ id: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].isCompleted.toggle()
        if reminders[index].isCompleted && !reminders[index].rewarded {
            reminders[index].rewarded = true
            // Paid straight into the same `points` the garden shop spends,
            // so task rewards and study rewards are always one balance.
            if DailyRewardLimiter(limit: CoinReward.maxRewardedTasksPerDay).claim() {
                // Pays the coins and also counts toward the Task Crusher
                // achievement and today's "finish N tasks" quest.
                GameStore.shared.completeTaskReward()
                Haptics.success()
                SoundPlayer.taskDone()
            }
        }
    }

    /// Deletes a subject together with all of its tasks.
    func deleteSubject(_ id: UUID) {
        reminders.removeAll { $0.subject.id == id }
        subjects.removeAll { $0.id == id }
    }

    func delete(_ id: UUID) {
        reminders.removeAll { $0.id == id }
    }

    func clearCompleted() {
        reminders.removeAll { $0.isCompleted }
    }
}
