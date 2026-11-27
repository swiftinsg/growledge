import Foundation

/// Rules for the coins ("points") the user earns.
///
/// - Studying earns `coinsPerHour` for every hour studied (counted per full
///   minute, so 30 minutes earns half). It is paid when the session ends.
/// - Finishing a task earns `bonusPerTask`, paid straight away by
///   `TodoStore.toggleCompleted` (once per task).
/// - A study streak of 2+ days earns a bonus that grows with the streak: see
///   `streakBonus(streakDays:minutesStudied:)`. Paid once a day, when a
///   session that lasted long enough ends.
struct CoinReward {
    static let coinsPerHour = 1_200
    static let bonusPerTask = 100
    /// Only this many finished tasks pay the bonus per day, so creating and
    /// ticking off throw-away tasks can't be used to farm coins.
    static let maxRewardedTasksPerDay = 10

    /// Streak bonus: this many coins for every day of the streak...
    static let streakBonusPerDay = 25
    /// ...counted up to this many days (so at most 30 x 25 = 750 a day).
    static let maxStreakBonusDays = 30
    /// A session must last this long to earn it. (A one-second session already
    /// keeps the streak going, but shouldn't pay a bonus.)
    static let minMinutesForStreakBonus = 5

    /// Seconds studied in the session that just ended.
    let studiedSeconds: TimeInterval

    /// Streak bonus paid with this session (0 = none), and the streak it was for.
    var streakBonus = 0
    var streakDays = 0

    /// Whole minutes studied.
    var minutes: Int { Int(studiedSeconds / 60) }

    /// Coins for the study time: 1,200 per hour (20 a minute).
    var total: Int { minutes * Self.coinsPerHour / 60 }

    /// Everything this session earned: study time plus any streak bonus.
    var grandTotal: Int { total + streakBonus }

    /// What a streak is worth for a session of `minutesStudied` minutes. There
    /// is no bonus for a first day or a very short session, and it stops
    /// growing after `maxStreakBonusDays`. The once-a-day limit is applied by
    /// the caller (`DailyRewardLimiter`).
    static func streakBonus(streakDays: Int, minutesStudied: Int) -> Int {
        guard streakDays >= 2, minutesStudied >= minMinutesForStreakBonus else { return 0 }
        return min(streakDays, maxStreakBonusDays) * streakBonusPerDay
    }
}

/// Allows a reward only `limit` times per calendar day. The count is kept in
/// `defaults` and starts again from zero on a new day.
struct DailyRewardLimiter {
    var defaults: UserDefaults = .standard
    var limit: Int
    var key = "reward.task"

    /// Counts one reward; false once today's limit has been reached.
    func claim(now: Date = .now, calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        var count = defaults.integer(forKey: key + "Count")
        if (defaults.object(forKey: key + "Day") as? Date) != today {
            defaults.set(today, forKey: key + "Day")
            count = 0
        }
        guard count < limit else { return false }
        defaults.set(count + 1, forKey: key + "Count")
        return true
    }
}
