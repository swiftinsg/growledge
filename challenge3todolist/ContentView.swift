//
//  ContentView.swift
//  AnotherCloudKitDemo
//
//  Created by Tiffany Tan on 1/8/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var reminders: [Reminder] = []
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                
                List {
                    ForEach($reminders) { $reminder in
                        HStack(alignment: .top, spacing: 12) {
                            // Completion Circle
                            Button {
                                reminder.isCompleted.toggle()
                            } label: {
                                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(reminder.isCompleted ? .blue : .gray)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            
                            // Subject on TOP, Task & Due Date on BOTTOM
                            VStack(alignment: .leading, spacing: 4) {
                                // 1. Subject on Top
                                Text(reminder.subject.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                                
                                // 2. Task Title Underneath
                                Text(reminder.title)
                                    .font(.headline)
                                    .strikethrough(reminder.isCompleted)
                                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                                
                                // 3. Due Date at the Bottom
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                    Text(reminder.dueDate, style: .date)
                                    Text("at")
                                    Text(reminder.dueDate, style: .time)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        reminders.remove(atOffsets: indexSet)
                    }
                }
                
                // Floating '+' Button at the Bottom-Right Corner
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Reminders")
            // Opens the Add Reminder form when '+' is tapped
            .sheet(isPresented: $showingAddSheet) {
                AddReminderView { newReminder in
                    reminders.append(newReminder)
                }
            }
        }
    }
}

// MARK: - Add Reminder Sheet View
struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Reminder) -> Void
    
    @State private var subject = ""
    @State private var title = ""
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Subject (e.g. Math, Work)", text: $subject)
                    TextField("Task Title", text: $title)
                }
                
                Section("Due Date") {
                    DatePicker("Date & Time", selection: $dueDate)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newReminder = Reminder(
                            title: title,
                            dueDate: dueDate,
                            subject: subject,
                            isCompleted: false
                        )
                        onSave(newReminder)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
