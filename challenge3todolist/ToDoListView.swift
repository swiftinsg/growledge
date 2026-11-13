import SwiftUI

/// Placeholder task model so the list can be built before the team's real
/// task model exists. Swap this for the shared model once it's available.
struct StudyTask: Identifiable {
    let id = UUID()
    var title: String
    var isDone = false
}

/// The bottom half of the study view. Shows the tasks the user picked for
/// the current study session, or an empty state when there are none.
struct ToDoListView: View {
    /// Tasks selected for this session.
    @Binding var tasks: [StudyTask]

    @State private var newTitle = ""

    private var trimmedTitle: String {
        newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To-Do List")
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top, 12)

            // Quick add, so the list is usable before the task picker exists
            HStack {
                TextField("Add a task", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addTask)

                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(trimmedTitle.isEmpty)
                .accessibilityLabel("Add task")
            }
            .padding(.horizontal)

            if tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks added yet!",
                    systemImage: "checklist",
                    description: Text("Add a task above to track it this session.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($tasks) { $task in
                        Button {
                            task.isDone.toggle()
                        } label: {
                            Label {
                                Text(task.title)
                                    .strikethrough(task.isDone)
                                    .foregroundStyle(task.isDone ? .secondary : .primary)
                            } icon: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? .green : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        tasks.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func addTask() {
        guard !trimmedTitle.isEmpty else { return }
        tasks.append(StudyTask(title: trimmedTitle))
        newTitle = ""
    }
}

#Preview("Empty") {
    @Previewable @State var tasks: [StudyTask] = []
    ToDoListView(tasks: $tasks)
}

#Preview("With sample tasks") {
    @Previewable @State var tasks = [
        StudyTask(title: "Read chapter 4"),
        StudyTask(title: "Finish math worksheet", isDone: true),
        StudyTask(title: "Review flashcards")
    ]
    ToDoListView(tasks: $tasks)
}
