//
//  TodolistContinuoation.swift
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

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }
}

/// A category such as "Math". Tasks belong to a subject and studying
/// is logged against a subject, which gives History its colours.
struct Subject: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var color: SubjectColor
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

    private static let subjectsKey = "todo.subjects"
    private static let remindersKey = "todo.reminders"

    @Published var subjects: [Subject] = [] {
        didSet { save() }
    }
    @Published var reminders: [Reminder] = [] {
        didSet { save() }
    }

    init() {
        // (didSet is not called while initialising, so loading doesn't re-save)
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.subjectsKey),
           let saved = try? JSONDecoder().decode([Subject].self, from: data) {
            subjects = saved
        }
        if let data = defaults.data(forKey: Self.remindersKey),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = saved
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(subjects), forKey: Self.subjectsKey)
        defaults.set(try? JSONEncoder().encode(reminders), forKey: Self.remindersKey)
    }

    /// Unfinished tasks organised by subject (one group per subject that has
    /// tasks), each group sorted by due date.
    var activeGroups: [TaskGroup] {
        subjects.compactMap { subject in
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
            GameStore.shared.points += CoinReward.bonusPerTask
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
