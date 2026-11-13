//
//  ContentView.swift
//  AnotherCloudKitDemo
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
                AppBackground()

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
                        emptyDescription: "Tap + to create a subject, then add tasks to it."
                    )
                }

                // Floating '+' Button at the Bottom-Right Corner
                Button {
                    showingAddMenu = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5))
                        .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 4)
                }
                .fadeIn(order: 2)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                // Popover letting the user choose what to create
                .popover(isPresented: $showingAddMenu) {
                    AddMenuView(hasSubjects: !store.subjects.isEmpty) { choice in
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
                    AddSubjectView { newSubject in
                        store.subjects.append(newSubject)
                    }
                case .task:
                    AddTaskView(subjects: store.subjects) { newReminder in
                        store.reminders.append(newReminder)
                    }
                }
            }
        }
    }
}

// MARK: - Popover Menu
struct AddMenuView: View {
    let hasSubjects: Bool
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
            .disabled(!hasSubjects)

            if !hasSubjects {
                Text("Create a subject first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 220)
    }
}

// MARK: - Add Subject Sheet View
struct AddSubjectView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Subject) -> Void

    @State private var name = ""
    @State private var color: SubjectColor = .blue

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Subject name (e.g. Math)", text: $name)
                }

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(SubjectColor.allCases) { option in
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
                }
            }
            .navigationTitle("New Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Subject(name: name.trimmingCharacters(in: .whitespaces), color: color))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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

                    Picker("Subject", selection: $selectedSubject) {
                        ForEach(subjects) { subject in
                            Label {
                                Text(subject.name)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(subject.color.color)
                            }
                            .tag(Optional(subject))
                        }
                    }
                }

                Section("Due Date") {
                    DatePicker("Date & Time", selection: $dueDate)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedSubject == nil { selectedSubject = subjects.first }
            }
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
