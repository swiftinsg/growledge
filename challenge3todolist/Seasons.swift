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

    /// A random season (picked each time the garden is opened).
    static func random() -> Season {
        allCases.randomElement() ?? .rainy
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

/// Redraws the weather at a capped frame rate (`Theme.weatherFrameRate`), and
/// stops while the app is in the background or Reduce Motion is switched on.
struct WeatherTimeline<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1 / Theme.weatherFrameRate, paused: paused)) { timeline in
            content(timeline.date)
        }
        .allowsHitTesting(false)
    }
}

/// Falling snow.
private struct SnowLayer: View {
    private static let opacityRange = 0.5...0.95
    /// The brightness of each of the three groups (see `RainDrop.group`).
    private static let groupOpacities = [0.55, 0.72, 0.9]

    private static let flakes: [RainDrop] = (0..<Theme.snowFlakeCount).map { _ in
        RainDrop(x: Double.random(in: 0...1),
                 speed: Double.random(in: 0.15...0.4),
                 length: Double.random(in: 2...5),
                 phase: Double.random(in: 0...1),
                 opacity: Double.random(in: opacityRange))
    }

    var body: some View {
        WeatherTimeline { date in
            Canvas { context, size in
                let t = date.timeIntervalSinceReferenceDate
                var groups = [Path(), Path(), Path()]
                for flake in Self.flakes {
                    let progress = (t * flake.speed + flake.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 20) - 10
                    let x = flake.x * size.width + sin(t * flake.speed * 3 + flake.phase * 6) * 12
                    groups[flake.group(in: Self.opacityRange)]
                        .addEllipse(in: CGRect(x: x, y: y, width: flake.length, height: flake.length))
                }
                for (path, opacity) in zip(groups, Self.groupOpacities) {
                    context.fill(path, with: .color(.white.opacity(opacity)))
                }
            }
        }
    }
}

/// Soft sun rays from the top corner.
private struct SunLayer: View {
    var body: some View {
        WeatherTimeline { date in
            let t = date.timeIntervalSinceReferenceDate
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
