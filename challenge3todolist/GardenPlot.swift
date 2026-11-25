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
                GardenGridLines(offset: offset)
                    .stroke(.black.opacity(0.45), lineWidth: 6)
                    .overlay {
                        GardenGridLines(offset: offset)
                            .stroke(.white.opacity(0.62), lineWidth: 2)
                    }
                    .allowsHitTesting(false)
            }
    }
}

private struct GardenGridLines: Shape {
    let offset: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
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

        return path
    }
}
