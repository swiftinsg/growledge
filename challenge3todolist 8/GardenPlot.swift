//
//  GardenPlot.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - Garden ground: your 12 x 12 tiles
// =====================================================================

/// Draws the garden from your three tile pictures:
///   gardenplot        the soil in the middle
///   gardenplotedge    the border (drawn with grass on its LEFT, so it is
///                     turned to face the right way on each side)
///   gardenplotcorner  the corners (drawn as the BOTTOM-LEFT corner)
struct GardenPlot: View, Animatable {
    var offset: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    /// The picture and how far to turn it for the tile at (col, row).
    static func art(col: Int, row: Int) -> (name: String, degrees: Double) {
        let last = Theme.gardenCols - 1
        let bottom = Theme.gardenRows - 1
        let isLeft = col == 0, isRight = col == last
        let isTop = row == 0, isBottom = row == bottom

        // Corners (the picture is the bottom-left one)
        if isLeft && isBottom { return ("gardenplotcorner", 0) }
        if isLeft && isTop { return ("gardenplotcorner", 90) }
        if isRight && isTop { return ("gardenplotcorner", 180) }
        if isRight && isBottom { return ("gardenplotcorner", 270) }
        // Edges (the picture has its grass on the left)
        if isLeft { return ("gardenplotedge", 0) }
        if isTop { return ("gardenplotedge", 90) }
        if isRight { return ("gardenplotedge", 180) }
        if isBottom { return ("gardenplotedge", 270) }
        return ("gardenplot", 0)
    }

    var body: some View {
        let size = Theme.tileSize
        ZStack(alignment: .topLeading) {
            Theme.grass
            ForEach(0..<Theme.gardenRows, id: \.self) { row in
                ForEach(0..<Theme.gardenCols, id: \.self) { col in
                    let tile = GardenPlot.art(col: col, row: row)
                    Image(tile.name)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: size + 1, height: size + 1)
                        .rotationEffect(.degrees(tile.degrees))
                        .position(x: (CGFloat(col) + 0.5) * size + offset.width,
                                  y: (CGFloat(row) + 0.5) * size + offset.height)
                }
            }
        }
    }
}
