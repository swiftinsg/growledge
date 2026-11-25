//
//  GardenPlot.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - Garden ground
// =====================================================================

/// A flat garden ground with visible boundaries for every cell in the fixed grid.
struct GardenPlot: View {
    let offset: CGSize

    var body: some View {
        Theme.grass
            .overlay {
                Path { path in
                    let width = CGFloat(Theme.gardenCols) * Theme.tileSize
                    let height = CGFloat(Theme.gardenRows) * Theme.tileSize

                    for column in 0...Theme.gardenCols {
                        let x = offset.width + CGFloat(column) * Theme.tileSize
                        path.move(to: CGPoint(x: x, y: offset.height))
                        path.addLine(to: CGPoint(x: x, y: offset.height + height))
                    }

                    for row in 0...Theme.gardenRows {
                        let y = offset.height + CGFloat(row) * Theme.tileSize
                        path.move(to: CGPoint(x: offset.width, y: y))
                        path.addLine(to: CGPoint(x: offset.width + width, y: y))
                    }
                }
                .stroke(.white.opacity(0.38), lineWidth: 2)
                .allowsHitTesting(false)
            }
    }
}
