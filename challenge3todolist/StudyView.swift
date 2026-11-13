import SwiftUI

struct StudyView: View {
    // Tasks chosen for this session.
    @State private var sessionTasks: [StudyTask] = []

    // Coins are the same "points" currency the garden shop uses,
    // so what you earn studying can be spent on seeds and sprinklers.
    @ObservedObject private var store = GameStore.shared
    @State private var lastReward: CoinReward?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PointsPill()
                    .accessibilityLabel("\(store.points) coins")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Top half: countdown timer
            TimerView(onEnd: endSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom half: to-do list
            ToDoListView(tasks: $sessionTasks)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Session Complete", isPresented: showingResult, presenting: lastReward) { _ in
            Button("OK", role: .cancel) {}
        } message: { reward in
            Text(resultMessage(for: reward))
        }
    }

    private var showingResult: Binding<Bool> {
        Binding(
            get: { lastReward != nil },
            set: { if !$0 { lastReward = nil } }
        )
    }

    /// Awards coins for the finished session, then clears completed tasks
    /// so they can't be counted twice.
    private func endSession(_ studiedSeconds: TimeInterval) {
        let reward = CoinReward(
            studiedSeconds: studiedSeconds,
            completedTasks: sessionTasks.filter(\.isDone).count
        )
        store.points += reward.total
        sessionTasks.removeAll(where: \.isDone)
        lastReward = reward
    }

    private func resultMessage(for reward: CoinReward) -> String {
        let minutes = Int(reward.studiedSeconds / 60)
        guard reward.meetsMinimum else {
            return "You studied for \(minutes) min. Study at least \(Int(CoinReward.minimumStudyTime / 60)) min to earn coins."
        }
        return """
        Studied \(minutes) min: +\(reward.studyCoins) coins
        Tasks completed (\(reward.completedTasks)): +\(reward.taskBonusCoins) coins
        Total: +\(reward.total) coins
        """
    }
}

#Preview {
    NavigationStack {
        StudyView()
    }
}
