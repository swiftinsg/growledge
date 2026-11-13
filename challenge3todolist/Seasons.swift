//
//  Seasons.swift
//  challenge3todolist
//
//  The garden's season: colours, weather and the shop backdrop.
//

import SwiftUI

enum Season: String, CaseIterable {
    case rainy, sunny, snowy

    static let storageKey = "season"

    /// The season chosen by the player (read by `Theme`).
    static var current: Season {
        Season(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .rainy
    }

    /// The next season in the cycle (used by the season button).
    var next: Season {
        let all = Season.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// SF Symbol shown on the season button.
    var icon: String {
        switch self {
        case .rainy: "cloud.rain.fill"
        case .sunny: "sun.max.fill"
        case .snowy: "snowflake"
        }
    }

    var grass: Color {
        switch self {
        case .rainy: Color(red: 0.20, green: 0.34, blue: 0.30)
        case .sunny: Color(red: 0.30, green: 0.50, blue: 0.28)
        case .snowy: Color(red: 0.78, green: 0.84, blue: 0.88)
        }
    }

    var soilDark: Color {
        switch self {
        case .rainy: Color(red: 0.20, green: 0.16, blue: 0.14)
        case .sunny: Color(red: 0.36, green: 0.25, blue: 0.16)
        case .snowy: Color(red: 0.30, green: 0.27, blue: 0.27)
        }
    }

    var soilLight: Color {
        switch self {
        case .rainy: Color(red: 0.30, green: 0.24, blue: 0.20)
        case .sunny: Color(red: 0.48, green: 0.34, blue: 0.22)
        case .snowy: Color(red: 0.42, green: 0.38, blue: 0.37)
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

    /// Dark tint laid over the garden (heavier in the rain).
    var gloom: Color {
        switch self {
        case .rainy: Color.black.opacity(0.35)
        case .sunny: Color.clear
        case .snowy: Color.black.opacity(0.12)
        }
    }
}

/// Gradient behind the shop and sell screens.
struct SeasonBackdrop: View {
    @AppStorage(Season.storageKey) private var seasonRaw = Season.rainy.rawValue

    var body: some View {
        let season = Season(rawValue: seasonRaw) ?? .rainy
        LinearGradient(colors: [season.backdropTop, season.backdropBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
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

/// Weather for the current season: rain, sun rays or snow.
struct WeatherLayer: View {
    @AppStorage(Season.storageKey) private var seasonRaw = Season.rainy.rawValue

    var body: some View {
        switch Season(rawValue: seasonRaw) ?? .rainy {
        case .rainy: RainLayer()
        case .sunny: SunLayer()
        case .snowy: SnowLayer()
        }
    }
}
