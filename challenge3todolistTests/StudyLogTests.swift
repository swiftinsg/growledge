import Foundation
import Testing
@testable import challenge3todolist

/// A fixed calendar (UTC, weeks start on Monday) so results don't depend on
/// where or when the tests run. In November 2026, Mon 9th ... Sun 15th.
@MainActor
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

@MainActor
private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

@MainActor
private func session(from start: Date, to end: Date) -> StudySession {
    StudySession(start: start, end: end)
}

// MARK: - Streak

@MainActor
struct StreakTests {
    private func streak(_ sessions: [StudySession], today: Date) -> Int {
        StudyLogStore(previewSessions: sessions).currentStreak(today: today, calendar: calendar)
    }

    @Test func noSessionsMeansNoStreak() {
        #expect(streak([], today: date(12, 10)) == 0)
    }

    @Test func studyingTodayStartsAStreakOfOne() {
        let sessions = [session(from: date(12, 9), to: date(12, 10))]
        #expect(streak(sessions, today: date(12, 15)) == 1)
    }

    @Test func streakSurvivesUntilTheDayIsOver() {
        // Studied yesterday, nothing yet today: the streak is still alive
        let sessions = [session(from: date(11, 9), to: date(11, 10))]
        #expect(streak(sessions, today: date(12, 8)) == 1)
    }

    @Test func missingAWholeDayBreaksTheStreak() {
        // Last studied two days ago
        let sessions = [session(from: date(10, 9), to: date(10, 10))]
        #expect(streak(sessions, today: date(12, 8)) == 0)
    }

    @Test func consecutiveDaysAreCounted() {
        let sessions = [
            session(from: date(10, 9), to: date(10, 10)),
            session(from: date(11, 9), to: date(11, 10)),
            session(from: date(12, 9), to: date(12, 10))
        ]
        #expect(streak(sessions, today: date(12, 15)) == 3)
    }

    @Test func aGapEndsTheCountAtTheGap() {
        // Today and the 10th, but nothing on the 11th
        let sessions = [
            session(from: date(10, 9), to: date(10, 10)),
            session(from: date(12, 9), to: date(12, 10))
        ]
        #expect(streak(sessions, today: date(12, 15)) == 1)
    }

    @Test func severalSessionsInOneDayCountOnce() {
        let sessions = [
            session(from: date(12, 7), to: date(12, 8)),
            session(from: date(12, 9), to: date(12, 10)),
            session(from: date(12, 11), to: date(12, 12))
        ]
        #expect(streak(sessions, today: date(12, 15)) == 1)
    }

    @Test func aSessionAcrossMidnightCountsBothDays() {
        let sessions = [session(from: date(11, 23, 30), to: date(12, 0, 30))]
        #expect(streak(sessions, today: date(12, 15)) == 2)
    }

    @Test func oldStudyDoesNotLeakIntoTheStreak() {
        let sessions = [
            session(from: date(1, 9), to: date(1, 10)),
            session(from: date(12, 9), to: date(12, 10))
        ]
        #expect(streak(sessions, today: date(12, 15)) == 1)
    }
}

// MARK: - Weekly blocks and totals

@MainActor
struct WeeklyBlocksTests {
    private let monday = date(9)

    @Test func sessionInsideADayBecomesOneBlock() {
        let store = StudyLogStore(previewSessions: [session(from: date(10, 14), to: date(10, 15, 30))])
        let blocks = store.blocks(weekStarting: monday, calendar: calendar)

        #expect(blocks.count == 1)
        #expect(blocks[0].day == 1)                      // Tuesday
        #expect(blocks[0].startHour == 14)
        #expect(blocks[0].seconds == 5400)
    }

    @Test func sessionAcrossMidnightIsSplitInTwo() {
        let store = StudyLogStore(previewSessions: [session(from: date(10, 23), to: date(11, 1))])
        let blocks = store.blocks(weekStarting: monday, calendar: calendar).sorted { $0.day < $1.day }

        #expect(blocks.count == 2)
        #expect(blocks.map(\.day) == [1, 2])
        #expect(blocks.map(\.seconds) == [3600, 3600])
        #expect(blocks[0].endHour == 24)
        #expect(blocks[1].startHour == 0)
    }

    @Test func veryShortSessionsAreStillVisible() {
        let store = StudyLogStore(previewSessions: [session(from: date(10, 9), to: date(10, 9).addingTimeInterval(5))])
        let block = store.blocks(weekStarting: monday, calendar: calendar)[0]

        #expect(block.endHour - block.startHour >= 0.08)
        // ...but the real time studied is not padded
        #expect(block.seconds == 5)
    }

    @Test func sessionsOutsideTheWeekAreLeftOut() {
        let store = StudyLogStore(previewSessions: [
            session(from: date(8, 9), to: date(8, 10)),      // Sunday before
            session(from: date(16, 9), to: date(16, 10))     // Monday after
        ])
        #expect(store.blocks(weekStarting: monday, calendar: calendar).isEmpty)
    }

    @Test func weekTotalOnlyCountsThatWeek() {
        let store = StudyLogStore(previewSessions: [
            session(from: date(8, 9), to: date(8, 10)),      // last week
            session(from: date(9, 9), to: date(9, 10)),      // Monday
            session(from: date(15, 20), to: date(15, 21))    // Sunday
        ])
        let total = store.seconds(inWeekOf: date(13, 12), calendar: calendar)
        #expect(total == 7200)
    }

    @Test func aSundayBelongsToTheWeekThatStartedOnMonday() {
        let store = StudyLogStore(previewSessions: [session(from: date(9, 9), to: date(9, 10))])
        #expect(store.seconds(inWeekOf: date(15, 23), calendar: calendar) == 3600)
        #expect(store.seconds(inWeekOf: date(16, 1), calendar: calendar) == 0)
    }

    @Test func studyWeekCalendarStartsOnMonday() {
        #expect(Calendar.studyWeek.firstWeekday == 2)
    }
}

// MARK: - Sessions and saving

@MainActor
struct SessionTests {
    @Test func recordIgnoresSessionsShorterThanASecond() {
        let store = StudyLogStore(previewSessions: [])
        store.record(start: date(10, 9), end: date(10, 9).addingTimeInterval(0.5))
        #expect(store.sessions.isEmpty)
    }

    @Test func recordKeepsTheSubjects() {
        let store = StudyLogStore(previewSessions: [])
        store.record(start: date(10, 9), end: date(10, 10),
                     subjects: [Subject(name: "Math", color: .blue), Subject(name: "Art", color: .pink)])

        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].subjectList.map(\.name) == ["Math", "Art"])
        #expect(store.sessions[0].subjectList.map(\.colorRaw) == ["blue", "pink"])
    }

    @Test func oldSessionsWithOneSubjectStillWork() {
        let old = StudySession(start: date(10, 9), end: date(10, 10), subjectName: "Math", colorRaw: "red")
        #expect(old.subjectList == [SessionSubject(name: "Math", colorRaw: "red")])
    }

    @Test func newSubjectsWinOverTheOldFields() {
        let mixed = StudySession(start: date(10, 9), end: date(10, 10),
                                 subjectName: "Old", colorRaw: "red",
                                 subjects: [SessionSubject(name: "New", colorRaw: "green")])
        #expect(mixed.subjectList.map(\.name) == ["New"])
    }

    @Test func aSessionWithNoSubjectHasAnEmptyList() {
        #expect(session(from: date(10, 9), to: date(10, 10)).subjectList.isEmpty)
    }

    @Test func savedDataFromBeforeSubjectsWereAddedStillLoads() throws {
        let json = """
        {"id":"\(UUID().uuidString)","start":0,"end":60,"subjectName":"Math","colorRaw":"blue"}
        """
        let decoded = try JSONDecoder().decode(StudySession.self, from: Data(json.utf8))
        #expect(decoded.subjectList.map(\.name) == ["Math"])
    }

    @Test func unknownColourFallsBackToGrey() {
        #expect(SessionSubject(name: "X", colorRaw: "not-a-colour").color == .gray)
    }
}

// MARK: - Subject totals (the colour key in History)

@MainActor
struct SubjectTotalTests {
    private func blocks(_ sessions: [StudySession]) -> [StudyBlock] {
        StudyLogStore(previewSessions: sessions).blocks(weekStarting: date(9), calendar: calendar)
    }

    @Test func studyWithNoSubjectIsCountedUnderOneName() {
        // One session saved with no subjects at all, one with the built-in
        // "No Subject": History must show them as a single entry.
        let none = SessionSubject(name: Subject.none.name, colorRaw: Subject.none.color.rawValue)
        let sessions = [
            session(from: date(10, 9), to: date(10, 10)),
            StudySession(start: date(10, 11), end: date(10, 12), subjects: [none])
        ]

        let totals = SubjectTotal.totals(for: blocks(sessions))

        #expect(totals.count == 1)
        #expect(totals[0].name == "No Subject")
        #expect(totals[0].seconds == 7200)
    }

    @Test func realSubjectsAreKeptApartFromNoSubject() {
        let math = SessionSubject(name: "Math", colorRaw: "blue")
        let sessions = [
            StudySession(start: date(10, 9), end: date(10, 11), subjects: [math]),
            session(from: date(10, 12), to: date(10, 13))
        ]

        let totals = SubjectTotal.totals(for: blocks(sessions))

        #expect(totals.map(\.name) == ["Math", "No Subject"])      // longest first
        #expect(totals.map(\.seconds) == [7200, 3600])
    }

    @Test func severalSubjectsShareTheTimeEqually() {
        let sessions = [StudySession(start: date(10, 9), end: date(10, 11),
                                     subjects: [SessionSubject(name: "Math", colorRaw: "blue"),
                                                SessionSubject(name: "Art", colorRaw: "pink")])]

        let totals = SubjectTotal.totals(for: blocks(sessions))

        #expect(totals.count == 2)
        #expect(totals.allSatisfy { $0.seconds == 3600 })
    }

    @Test func noSessionsMeansNoTotals() {
        #expect(SubjectTotal.totals(for: []).isEmpty)
    }
}
