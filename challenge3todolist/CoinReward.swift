import Foundation

/// Rules for the coins ("points") the user earns.
///
/// - Studying earns `coinsPerHour` for every hour studied (counted per full
///   minute, so 30 minutes earns half). It is paid when the session ends.
/// - Finishing a task earns `bonusPerTask`, paid straight away by
///   `TodoStore.toggleCompleted` (once per task).
struct CoinReward {
    static let coinsPerHour = 10_000
    static let bonusPerTask = 15_000

    /// Seconds studied in the session that just ended.
    let studiedSeconds: TimeInterval

    /// Whole minutes studied.
    var minutes: Int { Int(studiedSeconds / 60) }

    /// Coins for the study time: 10,000 per hour.
    var total: Int { minutes * Self.coinsPerHour / 60 }
}
