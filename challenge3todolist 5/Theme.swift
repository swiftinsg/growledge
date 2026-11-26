//
//  Theme.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 1. THEME  (change colors, sizes and the button image here)
// =====================================================================
enum Theme {
    // The garden ground never changes colour, whatever the season
    static let grass = Color(red: 0.40, green: 0.66, blue: 0.50)
    

    // Season-dependent colours: they follow the current season (see Seasons.swift)
    static var backdropTop: Color { Season.current.backdropTop }
    static var backdropBottom: Color { Season.current.backdropBottom }
    static var card: Color { Season.current.card }
    static var accent: Color { Season.current.accent }

    // Colours that stay the same in every season
    /// Text on top of a solid accent-coloured button
    static let buttonText = Color(red: 0.05, green: 0.09, blue: 0.13)
    static let panelBorder = Color.white.opacity(0.12)
    static let text = Color(red: 0.88, green: 0.92, blue: 0.96)
    static let subtext = Color(red: 0.88, green: 0.92, blue: 0.96).opacity(0.6)
    static let good = Color(red: 0.45, green: 0.78, blue: 0.65)        // soft teal
    static let gold = Color(red: 0.93, green: 0.78, blue: 0.50)
    static let bad = Color(red: 0.88, green: 0.45, blue: 0.50)
    static let coin = "✦"

    static let cornerRadius: CGFloat = 16
    /// Sized from the screen width, so a plot looks the same share of every
    /// iPhone (about 94pt on an iPhone SE).
    static var tileSize: CGFloat { (UIScreen.main.bounds.width * 0.25).rounded() }
    // The garden is a small fixed grid, so there are only a few big plots.
    static let gardenCols = 4
    static let gardenRows = 4

    static func isInGarden(col: Int, row: Int) -> Bool {
        (0..<gardenCols).contains(col) && (0..<gardenRows).contains(row)
    }

    /// The offset that puts the whole garden in the middle of an area.
    static func centeredGardenOffset(in size: CGSize) -> CGSize {
        CGSize(width: (size.width - CGFloat(gardenCols) * tileSize) / 2,
               height: (size.height - CGFloat(gardenRows) * tileSize) / 2)
    }
    static let tickSeconds = 0.25           // how often plants grow
    /// Selling a spare sprinkler back gives half of what it cost. (Crops sell
    /// for MORE than their seed: see `Crop.sellMultiplier` in Catalog.swift.)
    static let sellRate = 0.5
    static let startingPoints = 150         // only used the very first time

    // Weather (rain, snow, sun rays). Fewer particles and a lower frame rate
    // keep the garden smooth on slower devices; raise them for a richer look.
    static let weatherFrameRate = 30.0
    static let rainDropCount = 70
    static let snowFlakeCount = 45

    // Rain
    static let rainColor = Color(red: 0.75, green: 0.85, blue: 1.0)
}
