import Foundation
import Testing
@testable import challenge3todolist

/// These use their own throw-away UserDefaults, so the app's real tasks are never touched.
@MainActor
struct TodoStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func preload(subjects: [Subject], reminders: [Reminder], into defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(subjects), forKey: TodoStore.subjectsKey)
        defaults.set(try JSONEncoder().encode(reminders), forKey: TodoStore.remindersKey)
    }

    @Test func savedTasksSurviveStartingTheAppAgain() throws {
        // Regression test: loading the saved subjects used to save the still-empty
        // task list over the real one, so every task vanished on each launch.
        let defaults = makeDefaults()
        let math = Subject(name: "Math", color: .blue)
        let task = Reminder(title: "Algebra", dueDate: .now, subject: math)
        try preload(subjects: [math], reminders: [task], into: defaults)

        let first = TodoStore(defaults: defaults)
        #expect(first.reminders.map(\.title) == ["Algebra"])

        // Starting again must still find them: the first start must not have wiped them
        let second = TodoStore(defaults: defaults)
        #expect(second.reminders.map(\.title) == ["Algebra"])
        #expect(second.subjects.map(\.name) == ["Math"])
    }

    @Test func aFreshInstallStartsWithTheStarterSubjectsAndNoTasks() {
        let store = TodoStore(defaults: makeDefaults())
        #expect(store.subjects.map(\.name) == ["Math", "English", "Science", "Humanities"])
        #expect(store.reminders.isEmpty)
    }

    @Test func deletingAStarterSubjectSticksAfterRestart() {
        let defaults = makeDefaults()
        let store = TodoStore(defaults: defaults)
        store.deleteSubject(store.subjects[0].id)

        let next = TodoStore(defaults: defaults)
        #expect(next.subjects.map(\.name) == ["English", "Science", "Humanities"])
    }

    @Test func deletingEveryStarterSubjectDoesNotBringThemBack() {
        let defaults = makeDefaults()
        let store = TodoStore(defaults: defaults)
        for subject in store.subjects { store.deleteSubject(subject.id) }

        #expect(TodoStore(defaults: defaults).subjects.isEmpty)
    }

    @Test func existingUsersKeepTheirOwnSubjectsWithoutStarters() throws {
        let defaults = makeDefaults()
        try preload(subjects: [Subject(name: "Art", color: .pink)], reminders: [], into: defaults)
        #expect(TodoStore(defaults: defaults).subjects.map(\.name) == ["Art"])
    }

    @Test func newTasksAreSavedAndComeBackNextTime() {
        let defaults = makeDefaults()
        let store = TodoStore(defaults: defaults)
        let art = Subject(name: "Art", color: .pink)
        store.subjects.append(art)
        store.reminders.append(Reminder(title: "Sketch", dueDate: .now, subject: art))

        let next = TodoStore(defaults: defaults)
        #expect(next.subjects.map(\.name) == ["Math", "English", "Science", "Humanities", "Art"])
        #expect(next.reminders.map(\.title) == ["Sketch"])
    }

    @Test func aFinishedTaskCanBeUnfinishedAndReturnsToItsSubject() throws {
        let defaults = makeDefaults()
        let math = Subject(name: "Math", color: .blue)
        try preload(subjects: [math],
                    reminders: [Reminder(title: "Algebra", dueDate: .now, subject: math)],
                    into: defaults)
        let store = TodoStore(defaults: defaults)

        store.reminders[0].isCompleted = true
        #expect(store.activeGroups.isEmpty)
        #expect(store.completedTasks.map(\.title) == ["Algebra"])

        store.reminders[0].isCompleted = false
        #expect(store.completedTasks.isEmpty)
        #expect(store.activeGroups.map(\.subject.name) == ["Math"])
        #expect(store.activeGroups.first?.tasks.map(\.title) == ["Algebra"])

        // and the un-finished state is what gets saved
        #expect(TodoStore(defaults: defaults).reminders.first?.isCompleted == false)
    }

    @Test func deletingASubjectDeletesItsTasksForGood() throws {
        let defaults = makeDefaults()
        let math = Subject(name: "Math", color: .blue)
        let art = Subject(name: "Art", color: .pink)
        try preload(subjects: [math, art],
                    reminders: [Reminder(title: "Algebra", dueDate: .now, subject: math),
                                Reminder(title: "Sketch", dueDate: .now, subject: art)],
                    into: defaults)
        let store = TodoStore(defaults: defaults)

        store.deleteSubject(math.id)

        let next = TodoStore(defaults: defaults)
        #expect(next.subjects.map(\.name) == ["Art"])
        #expect(next.reminders.map(\.title) == ["Sketch"])
    }

    // MARK: - Quick-adding subjects

    @Test func suggestionsHaveUniqueNamesAndNoLanguages() {
        let names = Subject.suggestions.map { $0.name.lowercased() }
        #expect(Set(names).count == names.count)
        for banned in ["chinese", "malay", "tamil", "mother tongue"] { #expect(!names.contains(banned)) }
    }

    @Test func addingASubjectSkipsDuplicatesIgnoringCaseAndSpaces() {
        let store = TodoStore(defaults: makeDefaults())
        #expect(!store.addSubject(Subject(name: "  math ", color: .red)))
        #expect(!store.addSubject(Subject(name: "   ", color: .red)))
        #expect(store.addSubject(Subject(name: " Art ", color: .pink)))
        #expect(store.subjects.last?.name == "Art")
    }

    @Test func addedSuggestionsDisappearFromTheSuggestionList() {
        let store = TodoStore(defaults: makeDefaults())
        #expect(!store.availableSuggestions.contains { $0.name == "Math" })
        #expect(store.availableSuggestions.contains { $0.name == "Physics" })

        store.addSubject(Subject.suggestions.first { $0.name == "Physics" }!)
        #expect(!store.availableSuggestions.contains { $0.name == "Physics" })
    }

    @Test func addAllAddsEverySuggestionOnceAndSavesThem() {
        let defaults = makeDefaults()
        let store = TodoStore(defaults: defaults)
        let added = store.addSubjects(store.availableSuggestions)
        #expect(added == Subject.suggestions.count - 4)
        #expect(store.availableSuggestions.isEmpty)
        #expect(store.addSubjects(Subject.suggestions) == 0)
        #expect(TodoStore(defaults: defaults).subjects.count == Subject.suggestions.count)
    }
}
