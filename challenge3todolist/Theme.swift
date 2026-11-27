//
//  Theme.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 1. THEME  (change colors, sizes and the button image here)
// =====================================================================

/// The user's appearance choice, saved in UserDefaults and applied at the root.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// nil means "follow the system setting".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    /// A colour that changes with the system/app appearance.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum Theme {
    // The garden ground never changes colour, whatever the season
    static let grass = Color(red: 0.40, green: 0.66, blue: 0.50)

    // Season-dependent colours: they follow the current season (see Seasons.swift)
    static var backdropTop: Color { Season.current.backdropTop }
    static var backdropBottom: Color { Season.current.backdropBottom }
    static var card: Color { Season.current.card }
    static var accent: Color { Season.current.accent }

    // Colours that stay the same in every season, but adapt to light/dark mode
    /// Text on top of a solid accent-coloured button
    static let buttonText = Color(red: 0.05, green: 0.09, blue: 0.13)
    static let panelBorder = Color.adaptive(
        light: UIColor(white: 0, alpha: 0.12),
        dark: UIColor(white: 1, alpha: 0.12)
    )
    static let text = Color.adaptive(
        light: UIColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1)
    )
    static let subtext = Color.adaptive(
        light: UIColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 0.62),
        dark: UIColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 0.6)
    )
    /// Thin track behind progress bars and small chips on a card.
    static let track = Color.adaptive(
        light: UIColor(white: 0, alpha: 0.10),
        dark: UIColor(white: 1, alpha: 0.14)
    )
    static let chip = Color.adaptive(
        light: UIColor(white: 0, alpha: 0.06),
        dark: UIColor(white: 1, alpha: 0.08)
    )
    static let good = Color(red: 0.45, green: 0.78, blue: 0.65)        // soft teal
    static let gold = Color(red: 0.93, green: 0.78, blue: 0.50)
    static let bad = Color(red: 0.88, green: 0.45, blue: 0.50)
    static let coin = "✦"

    static let cornerRadius: CGFloat = 16
    /// Sized from the screen width, so a plot looks the same share of every
    /// iPhone (about 94pt on an iPhone SE).
    static var tileSize: CGFloat { (UIScreen.main.bounds.width * 0.25).rounded() }
    // The garden is a small fixed grid, so there are only a few big plots.
    static let gardenCols = 3
    static let gardenRows = 3

    static func isInGarden(col: Int, row: Int) -> Bool {
        (0..<gardenCols).contains(col) && (0..<gardenRows).contains(row)
    }

    /// The offset that puts the whole garden in the middle of an area.
    static func centeredGardenOffset(in size: CGSize) -> CGSize {
        CGSize(width: (size.width - CGFloat(gardenCols) * tileSize) / 2,
               height: (size.height - CGFloat(gardenRows) * tileSize) / 2)
    }
    static let tickSeconds = 0.25           // how often plants grow
    static let sellRate = 0.7               // selling gives 50% of the price
    static let startingPoints = 100         // only used the very first time

    // Weather (rain, snow, sun rays). Fewer particles and a lower frame rate
    // keep the garden smooth on slower devices; raise them for a richer look.
    static let weatherFrameRate = 30.0
    static let rainDropCount = 70
    static let snowFlakeCount = 45

    // Rain
    static let rainColor = Color(red: 0.75, green: 0.85, blue: 1.0)
}
