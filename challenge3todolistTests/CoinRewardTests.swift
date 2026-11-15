import Foundation
import Testing
@testable import challenge3todolist

@MainActor
struct CoinRewardTests {
    @Test func studyTimeIsCountedInWholeMinutes() {
        #expect(CoinReward(studiedSeconds: 0).minutes == 0)
        #expect(CoinReward(studiedSeconds: 59.9).minutes == 0)
        #expect(CoinReward(studiedSeconds: 60).minutes == 1)
        #expect(CoinReward(studiedSeconds: 119).minutes == 1)
    }

    @Test func coinsFollowTheHourlyRate() {
        #expect(CoinReward(studiedSeconds: 3600).total == CoinReward.coinsPerHour)
        #expect(CoinReward(studiedSeconds: 1800).total == CoinReward.coinsPerHour / 2)
        #expect(CoinReward(studiedSeconds: 2 * 3600).total == 2 * CoinReward.coinsPerHour)
    }

    @Test func lessThanAMinutePaysNothing() {
        #expect(CoinReward(studiedSeconds: 59).total == 0)
    }

    @Test func oneMinutePaysAProportionalShare() {
        // 10,000 coins an hour = 166 whole coins for one minute
        #expect(CoinReward(studiedSeconds: 60).total == CoinReward.coinsPerHour / 60)
    }
}

@MainActor
struct StreakBonusTests {
    private let enough = CoinReward.minMinutesForStreakBonus

    @Test func noBonusForAFirstDay() {
        #expect(CoinReward.streakBonus(streakDays: 0, minutesStudied: 60) == 0)
        #expect(CoinReward.streakBonus(streakDays: 1, minutesStudied: 60) == 0)
    }

    @Test func bonusGrowsWithEachDayOfTheStreak() {
        #expect(CoinReward.streakBonus(streakDays: 2, minutesStudied: enough) == 2 * CoinReward.streakBonusPerDay)
        #expect(CoinReward.streakBonus(streakDays: 7, minutesStudied: enough) == 7 * CoinReward.streakBonusPerDay)
    }

    @Test func bonusStopsGrowingAtTheCap() {
        let cap = CoinReward.maxStreakBonusDays * CoinReward.streakBonusPerDay
        #expect(CoinReward.streakBonus(streakDays: CoinReward.maxStreakBonusDays, minutesStudied: enough) == cap)
        #expect(CoinReward.streakBonus(streakDays: 365, minutesStudied: enough) == cap)
    }

    @Test func aTooShortSessionEarnsNoBonus() {
        #expect(CoinReward.streakBonus(streakDays: 10, minutesStudied: enough - 1) == 0)
        #expect(CoinReward.streakBonus(streakDays: 10, minutesStudied: 0) == 0)
        #expect(CoinReward.streakBonus(streakDays: 10, minutesStudied: enough) > 0)
    }

    @Test func theBonusIsAddedToTheSessionTotal() {
        var reward = CoinReward(studiedSeconds: 3600)         // 1 hour = 10,000
        #expect(reward.grandTotal == reward.total)             // no bonus yet
        reward.streakBonus = 5_000
        #expect(reward.grandTotal == CoinReward.coinsPerHour + 5_000)
    }

    @Test func theBonusCanOnlyBePaidOncePerDay() {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let limiter = DailyRewardLimiter(defaults: defaults, limit: 1, key: "reward.streak")

        #expect(limiter.claim())
        #expect(!limiter.claim())
    }
}

@MainActor
struct DailyRewardLimiterTests {
    /// A throw-away UserDefaults so tests never touch the app's real data.
    private func makeDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func allowsRewardsUpToTheLimitThenStops() {
        let limiter = DailyRewardLimiter(defaults: makeDefaults(), limit: 3)
        let now = date(day: 10)

        #expect(limiter.claim(now: now, calendar: calendar))
        #expect(limiter.claim(now: now, calendar: calendar))
        #expect(limiter.claim(now: now, calendar: calendar))
        #expect(!limiter.claim(now: now, calendar: calendar))
        #expect(!limiter.claim(now: now, calendar: calendar))
    }

    @Test func limitStartsAgainOnANewDay() {
        let limiter = DailyRewardLimiter(defaults: makeDefaults(), limit: 1)

        #expect(limiter.claim(now: date(day: 10), calendar: calendar))
        #expect(!limiter.claim(now: date(day: 10, hour: 23), calendar: calendar))
        #expect(limiter.claim(now: date(day: 11, hour: 0), calendar: calendar))
    }

    @Test func zeroLimitNeverPays() {
        let limiter = DailyRewardLimiter(defaults: makeDefaults(), limit: 0)
        #expect(!limiter.claim(now: date(day: 10), calendar: calendar))
    }

    @Test func countIsSavedBetweenLimiters() {
        let defaults = makeDefaults()
        let now = date(day: 10)

        #expect(DailyRewardLimiter(defaults: defaults, limit: 2).claim(now: now, calendar: calendar))
        #expect(DailyRewardLimiter(defaults: defaults, limit: 2).claim(now: now, calendar: calendar))
        #expect(!DailyRewardLimiter(defaults: defaults, limit: 2).claim(now: now, calendar: calendar))
    }

    @Test func differentKeysAreCountedSeparately() {
        let defaults = makeDefaults()
        let now = date(day: 10)
        let tasks = DailyRewardLimiter(defaults: defaults, limit: 1, key: "a")
        let other = DailyRewardLimiter(defaults: defaults, limit: 1, key: "b")

        #expect(tasks.claim(now: now, calendar: calendar))
        #expect(other.claim(now: now, calendar: calendar))
    }
}
