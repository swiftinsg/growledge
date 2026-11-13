import Foundation
import Combine

/// One stretch of focused study time (breaks are never logged).
struct StudySession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date
}

/// A piece of a session that falls inside one day, ready to draw.
/// Sessions that cross midnight are split into two blocks.
struct StudyBlock: Identifiable {
    let id: String
    let day: Int            // 0 = first day of the week (Monday)
    let startHour: Double   // 0...24, hours since midnight
    let endHour: Double     // padded slightly so very short sessions stay visible
    let seconds: TimeInterval
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
    func record(start: Date, end: Date) {
        guard end.timeIntervalSince(start) >= 1 else { return }
        sessions.append(StudySession(start: start, end: end))
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
                                         seconds: seconds))
            }
        }
        return result
    }
}
