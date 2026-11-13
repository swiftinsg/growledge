import SwiftUI

struct firsttimer: View {
    // Saved straight away so the answer is kept for later use in the app.
    @AppStorage("studyGoal") private var q1Text = ""

    private var hasAnswer: Bool {
        !q1Text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuestionBackground()

                VStack(spacing: 28) {
                    QuestionProgress(currentQuestion: 1)

                    Spacer()

                    QuestionHeader(
                        title: "What do you hope to achieve from studying?",
                        subtitle: "Your goal will help shape a study plan that works for you."
                    )

                    AnswerTextField(
                        title: "Your study goal",
                        prompt: "For example, pass my final exam",
                        text: $q1Text,
                        icon: "target",
                        keyboardType: .default
                    )

                    Spacer()

                    NavigationLink {
                        Q2View()
                    } label: {
                        Label("Continue", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!hasAnswer)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct QuestionBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.indigo.opacity(0.18),
                Color.blue.opacity(0.08),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct QuestionProgress: View {
    let currentQuestion: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...2, id: \.self) { question in
                Capsule()
                    .fill(question <= currentQuestion ? Color.indigo : Color.secondary.opacity(0.18))
                    .frame(width: question == currentQuestion ? 36 : 12, height: 8)
            }

            Spacer()

            // (was "\\(" which printed the text literally instead of the number)
            Text("Question \(currentQuestion) of 2")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct QuestionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct AnswerTextField: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let icon: String
    let keyboardType: UIKeyboardType

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .frame(width: 28)

                TextField(prompt, text: $text, axis: .vertical)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(keyboardType == .numberPad)
                    .lineLimit(1...3)
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused ? Color.indigo : Color.secondary.opacity(0.18), lineWidth: isFocused ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        // The number pad has no Return key, so give it a way to close,
        // otherwise it covers the Finish button.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isFocused = false }
            }
        }
    }
}

#Preview {
    firsttimer()
}
