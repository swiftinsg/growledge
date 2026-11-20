//
//  Todolist.swift
//  The app
//
//  Created by Tiffany Tan on 1/8/26.
//

import SwiftUI
import Combine

// Which creation form is currently showing
enum AddSheet: String, Identifiable {
    case subject, task
    var id: String { rawValue }
}

/// The To-Do List tab: tasks grouped by subject, with a '+' button to add
/// subjects and tasks.
struct Todolist: View {
    @ObservedObject private var store = TodoStore.shared
    @State private var showingAddMenu = false
    @State private var activeSheet: AddSheet?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                

                // Tasks are organised automatically: one section per subject
                // (named once, in its heading), and finished tasks fade away.
                VStack(alignment: .leading, spacing: 0) {
                    Text("To-Do List")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .fadeIn(order: 0)

                    GroupedTaskList(
                        managesSubjects: true,
                        emptyTitle: "No subjects yet",
                        emptyDescription: "Add the subjects you study, then add tasks to them."
                    )
                }

                // Floating '+' Button at the Bottom-Right Corner
                Button {
                    Haptics.tap()
                    showingAddMenu = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Theme.buttonText)
                        .frame(width: 60, height: 60)
                        .background(Theme.accent, in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .bouncy(haptic: false)
                .fadeIn(order: 2)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                // Popover letting the user choose what to create
                .popover(isPresented: $showingAddMenu) {
                    AddMenuView { choice in
                        showingAddMenu = false
                        activeSheet = choice
                    }
                    .presentationCompactAdaptation(.popover)
                }
            }
            .tabFadeRoot()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .subject:
                    AddSubjectView()
                case .task:
                    AddTaskView(subjects: store.allSubjects) { newReminder in
                        store.reminders.append(newReminder)
                    }
                }
            }
        }
    }
}

// MARK: - Popover Menu
struct AddMenuView: View {
    var onSelect: (AddSheet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onSelect(.subject)
            } label: {
                Label("Create Subject", systemImage: "folder.badge.plus")
            }

            Divider()

            Button {
                onSelect(.task)
            } label: {
                Label("Create Task", systemImage: "checklist")
            }
        }
        .padding()
        .frame(minWidth: 220)
    }
}

// MARK: - Add Subject Sheet View
/// Tap a suggestion to add it straight away (as many as you like), or type
/// your own name and pick a colour.
struct AddSubjectView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TodoStore.shared

    @State private var name = ""
    @State private var color: SubjectColor = .blue

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                // One tap each; they disappear from here once added.
                if !store.availableSuggestions.isEmpty {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(store.availableSuggestions) { suggestion in
                                Button {
                                    Haptics.tap()
                                    withAnimation(.snappy) { store.addSubject(suggestion) }
                                } label: {
                                    Label(suggestion.name, systemImage: "plus")
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .foregroundStyle(suggestion.color.color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(suggestion.color.color.opacity(0.18), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        HStack {
                            Text("Quick add")
                            Spacer()
                            Button("Add all") {
                                Haptics.success()
                                withAnimation(.snappy) { store.addSubjects(store.availableSuggestions) }
                            }
                            .font(.caption.weight(.semibold))
                            .textCase(nil)
                        }
                    }
                }

                Section("Or make your own") {
                    TextField("Subject name", text: $name)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(SubjectColor.choices) { option in
                            Circle()
                                .fill(option.color)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if option == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { color = option }
                        }
                    }
                    .padding(.vertical, 4)
                    Button("Add \(trimmedName.isEmpty ? "subject" : trimmedName)") {
                        if store.addSubject(Subject(name: trimmedName, color: color)) {
                            Haptics.success()
                            name = ""
                        } else {
                            Haptics.warning()
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                }

                if !store.subjects.isEmpty {
                    Section("Your subjects") {
                        Text(store.subjects.map(\.name).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Add Task Sheet View
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let subjects: [Subject]
    var onSave: (Reminder) -> Void

    @State private var title = ""
    @State private var selectedSubject: Subject?
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Task Title", text: $title)

                }

                // A list of rows rather than a Picker menu, because menus
                // draw their icons without colour. Each row is tinted with
                // its own subject colour, and the chosen one fills solid so
                // the assigned colour is unmistakable.
                Section {
                    ForEach(subjects) { subject in
                        let isSelected = selectedSubject?.id == subject.id
                        Button {
                            withAnimation(.snappy) { selectedSubject = subject }
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(subject.color.color)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
                                Text(subject.name)
                                    .fontWeight(isSelected ? .bold : .regular)
                                    .foregroundStyle(isSelected ? subject.color.color : .primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(subject.color.color)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(isSelected ? subject.color.color.opacity(0.22) : Color.clear)
                    }
                } header: {
                    HStack {
                        Text("Subject")
                        Text("Required")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(selectedSubject == nil ? Color.red : Color.green))
                    }
                } footer: {
                    if selectedSubject == nil {
                        Text("Pick a subject so this task gets the right colour.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Due Date") {
                    DatePicker("Date & Time", selection: $dueDate)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedSubject else { return }
                        onSave(Reminder(title: title.trimmingCharacters(in: .whitespaces),
                                        dueDate: dueDate,
                                        subject: selectedSubject))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedSubject == nil)
                }
            }
        }
    }
}

#Preview {
    Todolist()
        .preferredColorScheme(.dark)
}
