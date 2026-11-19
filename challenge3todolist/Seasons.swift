//
//  Seasons.swift
//  challenge3todolist
//
//  The garden's season: colours, weather and the shop backdrop.
//

import SwiftUI

/// A limited-time shop event, scheduled yearly by the real calendar date.
enum SeasonalEvent: Equatable {
    case halloween, christmas

    /// Which event (if any) is running right now, by the device's real date.
    static var current: SeasonalEvent? {
        let cal = Calendar.current
        let now = Date()
        let year = cal.component(.year, from: now)

        func range(_ y1: Int, _ m1: Int, _ d1: Int, _ y2: Int, _ m2: Int, _ d2: Int) -> ClosedRange<Date>? {
            guard let start = cal.date(from: DateComponents(year: y1, month: m1, day: d1, hour: 0, minute: 0)),
                  let end = cal.date(from: DateComponents(year: y2, month: m2, day: d2, hour: 23, minute: 59, second: 59))
            else { return nil }
            return start...end
        }

        // Halloween: October 1 – November 19.
        if let halloween = range(year, 10, 1, year, 11, 19), halloween.contains(now) {
            return .halloween
        }
        // Christmas: November 20 – December 31, continuing into January 1–8
        // of the following year.
        if let christmasLate = range(year, 11, 20, year, 12, 31), christmasLate.contains(now) {
            return .christmas
        }
        if let christmasEarly = range(year, 1, 1, year, 1, 8), christmasEarly.contains(now) {
            return .christmas
        }
        return nil
    }

    var title: String {
        switch self {
        case .halloween: "Halloween"
        case .christmas: "Christmas"
        }
    }

    var icon: String {
        switch self {
        case .halloween: "moon.stars.fill"
        case .christmas: "snowflake"
        }
    }
}

enum Season: String, CaseIterable {
    case rainy, sunny, snowy

    /// How often the weather changes on its own. Nobody picks it — it's random.
    static let changeInterval: TimeInterval = 15 * 60   // 15 minutes

    /// The current weather. This is worked out from the real clock, not
    /// stored anywhere, so every screen agrees on the same season at the
    /// same moment and the player has no way to choose it — it just changes
    /// on its own every `changeInterval`.
    static var current: Season {
        let bucket = Int(Date().timeIntervalSince1970 / changeInterval)
        var hasher = Hasher()
        hasher.combine(bucket)
        hasher.combine("weather-is-random")
        let all = Season.allCases
        let index = Int(UInt(bitPattern: hasher.finalize()) % UInt(all.count))
        return all[index]
    }

    /// SF Symbol shown next to the weather readout.
    var icon: String {
        switch self {
        case .rainy: "cloud.rain.fill"
        case .sunny: "sun.max.fill"
        case .snowy: "snowflake"
        }
    }

    var backdropTop: Color {
        switch self {
        case .rainy: Color(red: 0.10, green: 0.14, blue: 0.20)
        case .sunny: Color(red: 0.20, green: 0.32, blue: 0.48)
        case .snowy: Color(red: 0.16, green: 0.20, blue: 0.28)
        }
    }

    var backdropBottom: Color {
        switch self {
        case .rainy: Color(red: 0.06, green: 0.09, blue: 0.13)
        case .sunny: Color(red: 0.10, green: 0.18, blue: 0.26)
        case .snowy: Color(red: 0.09, green: 0.12, blue: 0.18)
        }
    }

    var card: Color {
        switch self {
        case .rainy: Color(red: 0.12, green: 0.17, blue: 0.23)
        case .sunny: Color(red: 0.14, green: 0.22, blue: 0.30)
        case .snowy: Color(red: 0.15, green: 0.19, blue: 0.26)
        }
    }

    var accent: Color {
        switch self {
        case .rainy: Color(red: 0.50, green: 0.72, blue: 0.95)
        case .sunny: Color(red: 0.98, green: 0.80, blue: 0.40)
        case .snowy: Color(red: 0.70, green: 0.88, blue: 1.0)
        }
    }

    /// How the season affects growth speed, on top of any sprinkler:
    /// rain waters everything for free (faster), sun is a mild bonus,
    /// and snowy "winter" slows things down.
    var growthMultiplier: Double {
        switch self {
        case .rainy: 1.25
        case .sunny: 1.1
        case .snowy: 0.6
        }
    }

    /// Short label for the season button / shop backdrop.
    var label: String {
        switch self {
        case .rainy: "Rainy"
        case .sunny: "Sunny"
        case .snowy: "Winter"
        }
    }
}

/// Gradient behind the shop and sell screens. Wrapped in a `TimelineView` so
/// it quietly picks up the random weather change without anyone tapping anything.
struct SeasonBackdrop: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { _ in
            let season = Season.current
            LinearGradient(colors: [season.backdropTop, season.backdropBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

/// Falling snow.
private struct SnowLayer: View {
    private static let flakes: [RainDrop] = (0..<90).map { _ in
        RainDrop(x: Double.random(in: 0...1),
                 speed: Double.random(in: 0.15...0.4),
                 length: Double.random(in: 2...5),
                 phase: Double.random(in: 0...1),
                 opacity: Double.random(in: 0.5...0.95))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for flake in Self.flakes {
                    let progress = (t * flake.speed + flake.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 20) - 10
                    let x = flake.x * size.width + sin(t * flake.speed * 3 + flake.phase * 6) * 12
                    let rect = CGRect(x: x, y: y, width: flake.length, height: flake.length)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(flake.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Soft sun rays from the top corner.
private struct SunLayer: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let origin = CGPoint(x: size.width * 0.9, y: -20)
                for i in 0..<6 {
                    let angle = Angle.degrees(100 + Double(i) * 12 + sin(t * 0.3 + Double(i)) * 3)
                    var path = Path()
                    path.move(to: origin)
                    path.addLine(to: CGPoint(x: origin.x + cos(angle.radians) * size.height * 1.4 - 30,
                                             y: origin.y + sin(angle.radians) * size.height * 1.4))
                    path.addLine(to: CGPoint(x: origin.x + cos(angle.radians) * size.height * 1.4 + 30,
                                             y: origin.y + sin(angle.radians) * size.height * 1.4))
                    path.closeSubpath()
                    context.fill(path, with: .color(Color.yellow.opacity(0.08)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Weather for the current season: rain, sun rays or snow. Refreshes itself
/// every few seconds so the random weather change shows up without a restart.
struct WeatherLayer: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            switch Season.current {
            case .rainy: RainLayer()
            case .sunny: SunLayer()
            case .snowy: SnowLayer()
            }
        }
    }
}
