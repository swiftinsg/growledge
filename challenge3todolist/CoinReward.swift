import Foundation

/// Rules for the coins a user earns when ending a study session.
///
/// - Nothing is earned unless the user studied for at least `minimumStudyTime`.
/// - Study time earns `coinsPerStudyMinute` per full minute, capped at `maxStudyCoins`.
/// - Each completed task earns `bonusPerTask`, capped at `maxTaskBonus`.
struct CoinReward {
    static let minimumStudyTime: TimeInterval = 60 * 60   // 1 hour: lower this to reward shorter sessions
    static let coinsPerStudyMinute = 1
    static let maxStudyCoins = 180      // reached after 3 hours of study
    static let bonusPerTask = 15
    static let maxTaskBonus = 60        // reached after 4 completed tasks

    let studiedSeconds: TimeInterval
    let completedTasks: Int

    /// True once the user has studied long enough to earn anything.
    var meetsMinimum: Bool { studiedSeconds >= Self.minimumStudyTime }

    var studyCoins: Int {
        guard meetsMinimum else { return 0 }
        let minutes = Int(studiedSeconds / 60)
        return min(minutes * Self.coinsPerStudyMinute, Self.maxStudyCoins)
    }

    var taskBonusCoins: Int {
        guard meetsMinimum else { return 0 }
        return min(max(completedTasks, 0) * Self.bonusPerTask, Self.maxTaskBonus)
    }

    var total: Int { studyCoins + taskBonusCoins }
}
