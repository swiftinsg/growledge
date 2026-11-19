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
    static let grass = Color(red: 0.20, green: 0.34, blue: 0.30)
    static let soilDark = Color(red: 0.20, green: 0.16, blue: 0.14)
    static let soilLight = Color(red: 0.30, green: 0.24, blue: 0.20)

    // Season-dependent colours: they follow the current season (see Seasons.swift)
    static var backdropTop: Color { Season.current.backdropTop }
    static var backdropBottom: Color { Season.current.backdropBottom }
    static var card: Color { Season.current.card }
    static var accent: Color { Season.current.accent }

    // Colours that stay the same in every season
    static let panelBorder = Color.white.opacity(0.12)
    static let text = Color(red: 0.88, green: 0.92, blue: 0.96)
    static let subtext = Color(red: 0.88, green: 0.92, blue: 0.96).opacity(0.6)
    static let good = Color(red: 0.45, green: 0.78, blue: 0.65)        // soft teal
    static let gold = Color(red: 0.93, green: 0.78, blue: 0.50)
    static let bad = Color(red: 0.88, green: 0.45, blue: 0.50)
    static let coin = "✦"

    static let buttonImage = "Image 1"      // background of every button
    static let cornerRadius: CGFloat = 16
    static let tileSize: CGFloat = 80
    static let tickSeconds = 0.25           // how often plants grow
    static let sellRate = 0.7               // selling gives 50% of the price
    static let startingPoints = 100         // only used the very first time

    // Rain
    static let rainColor = Color(red: 0.75, green: 0.85, blue: 1.0)
}
