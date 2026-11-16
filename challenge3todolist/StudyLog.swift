import Foundation
import SwiftUI
import Combine

extension Calendar {
    /// The calendar used for "this week": weeks start on Monday.
    static var studyWeek: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
}

/// A subject as saved with a study session (plain values, so it survives
/// the subject being renamed or deleted later).
struct SessionSubject: Codable, Hashable {
    var name: String
    var colorRaw: String

    var color: Color { SubjectColor(rawValue: colorRaw)?.color ?? .gray }
}

/// One stretch of focused study time (breaks are never logged).
struct StudySession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date
    /// Older sessions saved a single subject in these two fields.
    var subjectName: String?
    var colorRaw: String?
    /// The subjects studied (empty = no subject). Newer sessions can have several.
    var subjects: [SessionSubject]?

    var subjectList: [SessionSubject] {
        if let subjects { return subjects }
        if let subjectName, let colorRaw { return [SessionSubject(name: subjectName, colorRaw: colorRaw)] }
        return []
    }
}

/// A piece of a session that falls inside one day, ready to draw.
/// Sessions that cross midnight are split into two blocks.
struct StudyBlock: Identifiable {
    let id: String
    let day: Int            // 0 = first day of the week (Monday)
    let startHour: Double   // 0...24, hours since midnight
    let endHour: Double     // padded slightly so very short sessions stay visible
    let seconds: TimeInterval
    let subjects: [SessionSubject]

    /// The subject's colour (grey when no subject was chosen).
    var colors: [Color] {
        subjects.isEmpty ? [.gray] : subjects.map(\.color)
    }

    /// One colour for a single subject; a gradient across all of them for several.
    var fill: LinearGradient {
        let colors = colors
        return LinearGradient(colors: colors.count > 1 ? colors : [colors[0], colors[0].opacity(0.75)],
                              startPoint: .top, endPoint: .bottom)
    }
}

/// Saves study sessions between launches.
final class StudyLogStore: ObservableObject {
    static let shared = StudyLogStore()

    @Published private(set) var sessions: [StudySession]
    private let key = "studyLog.sessions"
    private let persists: Bool

    init() {
        persists = true
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([StudySession].self, from: data) {
            sessions = saved
        } else {
            sessions = []
        }
    }

    /// For previews: uses the given sessions and never touches saved data.
    init(previewSessions: [StudySession]) {
        persists = false
        sessions = previewSessions
    }

    /// Call this whenever a stretch of focus time ends.
    func record(start: Date, end: Date, subjects: [Subject] = []) {
        guard end.timeIntervalSince(start) >= 1 else { return }
        sessions.append(StudySession(start: start, end: end,
                                     subjects: subjects.map { SessionSubject(name: $0.name, colorRaw: $0.color.rawValue) }))
        save()
    }

    private func save() {
        guard persists else { return }
        UserDefaults.standard.set(try? JSONEncoder().encode(sessions), forKey: key)
    }

    /// All study blocks for the 7 days starting at `weekStart`.
    func blocks(weekStarting weekStart: Date, calendar: Calendar) -> [StudyBlock] {
        var result: [StudyBlock] = []
        for day in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: day, to: weekStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            for session in sessions {
                let from = max(session.start, dayStart)
                let to = min(session.end, dayEnd)
                guard to > from else { continue }

                let startHour = from.timeIntervalSince(dayStart) / 3600
                let seconds = to.timeIntervalSince(from)
                let endHour = min(24, max(startHour + seconds / 3600, startHour + 0.08))
                result.append(StudyBlock(id: "\(day)-\(session.id)",
                                         day: day,
                                         startHour: startHour,
                                         endHour: endHour,
                                         seconds: seconds,
                                         subjects: session.subjectList))
            }
        }
        return result
    }

    /// Total seconds studied in the week that contains `date`
    /// (this is what fills the Home progress bar).
    func seconds(inWeekOf date: Date, calendar: Calendar = .studyWeek) -> TimeInterval {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        return blocks(weekStarting: weekStart, calendar: calendar).reduce(0) { $0 + $1.seconds }
    }

    /// The study streak: how many days in a row (ending today) have at least
    /// one study session. If you haven't studied yet today the streak is not
    /// lost until the day is over, so it counts back from yesterday instead.
    func currentStreak(today: Date = .now, calendar: Calendar = .current) -> Int {
        // Every calendar day that has some study time (sessions can span midnight)
        var studyDays = Set<Date>()
        for session in sessions {
            var day = calendar.startOfDay(for: session.start)
            let lastDay = calendar.startOfDay(for: session.end)
            while day <= lastDay {
                studyDays.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        var day = calendar.startOfDay(for: today)
        if !studyDays.contains(day) {
            // nothing yet today: the streak is still alive if yesterday was studied
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while studyDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
