import SwiftUI

// =====================================================================
// The two starting questions, drawn as a cosy garden study app:
// the forest behind a wooden card, with a little plant that grows as you answer.
// =====================================================================

struct FirstTimerView: View {
    // Saved straight away so the answer is kept for later use in the app.
    @AppStorage("studyGoal") private var q1Text = ""

    private let ideas = ["Pass my exams", "Build a daily habit", "Learn something new", "Finish my homework"]

    private var hasAnswer: Bool {
        !q1Text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuestionBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        QuestionProgress(currentQuestion: 1)

                        QuestionHeader(
                            title: "What do you hope to achieve from studying?",
                            subtitle: "Plant your goal. Every study session helps it grow."
                        )

                        AnswerTextField(
                            title: "Your study goal",
                            prompt: "For example, pass my final exam",
                            text: $q1Text,
                            icon: "target",
                            keyboardType: .default
                        )

                        ChipRow(options: ideas, onPick: { idea in q1Text = idea })

                        NavigationLink {
                            Q2View()
                        } label: {
                            QuestionButtonLook(title: "Continue", icon: "arrow.right")
                        }
                        .disabled(!hasAnswer)
                        .opacity(hasAnswer ? 1 : 0.5)
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Pieces

/// The misty forest, a little darker so the card stands out.
struct QuestionBackground: View {
    var body: some View {
        ForestBackground(dim: 0.5)
    }
}

/// A seed, a sapling and a tree: the plant grows as you move through the questions.
struct QuestionProgress: View {
    let currentQuestion: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 26) {
                plant("emberfigseed", lit: true, size: 34)
                plant("emberfigsapling", lit: currentQuestion >= 2, size: 46)
                plant("emberfigtree", lit: false, size: 60)
            }
            .frame(height: 64, alignment: .bottom)

            Text("Question \(currentQuestion) of 2")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Wood.trim)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Wood.darker.opacity(0.75)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(currentQuestion) of 2")
    }

    private func plant(_ name: String, lit: Bool, size: CGFloat) -> some View {
        PixelIcon(name: name, size: size)
            .saturation(lit ? 1 : 0)
            .opacity(lit ? 1 : 0.4)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}

struct QuestionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.black))
                .foregroundStyle(Wood.cream)
                .shadow(color: .black.opacity(0.5), radius: 0, y: 2)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Wood.cream.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
}

/// A cream "paper" card with a text box on it.
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
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Wood.ink.opacity(0.75))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Wood.leafDark)
                    .frame(width: 28)

                TextField(prompt, text: $text, axis: .vertical)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(keyboardType == .numberPad)
                    .lineLimit(1...3)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Wood.ink)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.7)))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? Wood.leaf : Wood.base.opacity(0.5), lineWidth: isFocused ? 3 : 2)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Wood.paper))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Wood.base, lineWidth: 4))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 5)
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

/// Quick suggestions: tap one to fill in the answer.
struct ChipRow: View {
    let options: [String]
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    Haptics.tap()
                    onPick(option)
                } label: {
                    Text(option)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Wood.cream)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Wood.leafDark.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Wood.leaf, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The big green button at the bottom of each question.
struct QuestionButtonLook: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: icon)
        }
        .font(.system(.title3, design: .rounded).weight(.black))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Wood.leafDark).offset(y: 4)
                RoundedRectangle(cornerRadius: 16).fill(Wood.leaf)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xA6E08A), lineWidth: 3))
    }
}

#Preview {
    FirstTimerView()
}
