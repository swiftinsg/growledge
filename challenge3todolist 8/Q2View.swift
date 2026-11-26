import SwiftUI

struct Q2View: View {
    @State private var q2Text = ""

    // Saved answers. "hisgoal" is the goal the Home progress bar uses.
    @AppStorage("weeklyGoalHours") private var weeklyGoalHours = 0
    @AppStorage("hisgoal") private var goalTime = 100.0
    // Flipping this makes ContentView leave the questionnaire and show the app.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let hourIdeas = ["3 hours", "5 hours", "10 hours", "15 hours"]

    /// The typed hours as a number, or nil if it isn't a sensible value.
    private var hours: Int? {
        let trimmed = q2Text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1...168).contains(value) else { return nil }
        return value
    }

    var body: some View {
        ZStack {
            QuestionBackground()

            ScrollView {
                VStack(spacing: 20) {
                    QuestionProgress(currentQuestion: 2)

                    QuestionHeader(
                        title: "How many hours do you plan to study each week?",
                        subtitle: "A realistic goal helps your garden grow steadily."
                    )

                    AnswerTextField(
                        title: "Weekly study time (hours)",
                        prompt: "Enter number of hours",
                        text: $q2Text,
                        icon: "clock",
                        keyboardType: .numberPad
                    )

                    ChipRow(options: hourIdeas, onPick: { option in
                        q2Text = option.filter { $0.isNumber }
                    })

                    Button {
                        finish()
                    } label: {
                        QuestionButtonLook(title: "Start growing", icon: "leaf.fill")
                    }
                    .disabled(hours == nil)
                    .opacity(hours == nil ? 0.5 : 1)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        // Keep only digits (there are 168 hours in a week, so 1...168 is accepted)
        .onChange(of: q2Text) { _, newValue in
            let digits = newValue.filter(\.isNumber)
            if digits != newValue { q2Text = digits }
        }
    }

    private func finish() {
        guard let hours else { return }
        weeklyGoalHours = hours
        goalTime = Double(hours)
        Haptics.success()
        hasCompletedOnboarding = true
    }
}

#Preview {
    NavigationStack {
        Q2View()
    }
}
