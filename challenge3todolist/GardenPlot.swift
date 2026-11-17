//
//  GardenPlot.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - Endless garden ground (you never need to touch this)
// =====================================================================

/// A deterministic 0...1 "random" value for a tile, so the ground looks
/// textured and alive without changing every frame or needing to be saved.
private func groundNoise(_ col: Int, _ row: Int, _ salt: Int = 0) -> Double {
    var hasher = Hasher()
    hasher.combine(col)
    hasher.combine(row)
    hasher.combine(salt)
    let v = UInt32(truncatingIfNeeded: hasher.finalize())
    return Double(v % 10_000) / 10_000
}

struct GardenPlot: View, Animatable {
    var offset: CGSize
    let tileSize: CGFloat = Theme.tileSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    var body: some View {
        // Refreshes every 20s on its own, so the random weather change shows
        // up on the ground without the player doing anything.
        TimelineView(.periodic(from: .now, by: 20)) { _ in
            let season = Season.current
            Canvas { context, size in
                // One continuous ground colour (no checkerboard) with soft
                // mottled texture, so it reads as grass/soil, not a grid.
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(season.grass))

                let firstCol = Int(floor(-offset.width / tileSize)) - 1
                let lastCol = Int(floor((size.width - offset.width) / tileSize)) + 1
                let firstRow = Int(floor(-offset.height / tileSize)) - 1
                let lastRow = Int(floor((size.height - offset.height) / tileSize)) + 1
                guard firstCol <= lastCol, firstRow <= lastRow else { return }

                for col in firstCol...lastCol {
                    for row in firstRow...lastRow {
                        let rect = CGRect(
                            x: CGFloat(col) * tileSize + offset.width,
                            y: CGFloat(row) * tileSize + offset.height,
                            width: tileSize,
                            height: tileSize
                        )

                        // Gentle, irregular shading per tile instead of a strict
                        // light/dark alternation — reads as natural ground.
                        let n = groundNoise(col, row)
                        context.fill(
                            Path(rect),
                            with: .color(season.soilDark.opacity(0.10 + n * 0.10))
                        )

                        // A seasonal decoration, scattered sparsely and never on
                        // every tile, so it feels like a biome rather than a grid.
                        if groundNoise(col, row, 7) > 0.86 {
                            let dot = CGRect(
                                x: rect.midX - 3 + (groundNoise(col, row, 11) - 0.5) * tileSize * 0.5,
                                y: rect.midY - 3 + (groundNoise(col, row, 13) - 0.5) * tileSize * 0.5,
                                width: 6, height: 6
                            )
                            switch season {
                            case .sunny:
                                // tiny wildflower / grass tuft
                                context.fill(Path(ellipseIn: dot), with: .color(.yellow.opacity(0.55)))
                            case .rainy:
                                // a little puddle shimmer
                                context.fill(Path(ellipseIn: dot.insetBy(dx: -3, dy: -1)), with: .color(.white.opacity(0.12)))
                            case .snowy:
                                // a small snow drift
                                context.fill(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)), with: .color(.white.opacity(0.5)))
                            }
                        }

                        // Faint seam between tiles so the grid is still readable
                        // up close (for planting), without being the dominant look.
                        context.stroke(
                            Path(rect.insetBy(dx: 1, dy: 1)),
                            with: .color(.black.opacity(0.05)),
                            lineWidth: 1
                        )
                    }
                }
            }
        }
    }
}
