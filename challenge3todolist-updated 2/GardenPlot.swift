//
//  GardenPlot.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - Endless garden ground (you never need to touch this)
// =====================================================================
struct GardenPlot: View, Animatable {
    var offset: CGSize
    let tileSize: CGFloat = Theme.tileSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Theme.grass)
            )

            let firstCol = Int(floor(-offset.width / tileSize))
            let lastCol = Int(floor((size.width - offset.width) / tileSize))
            let firstRow = Int(floor(-offset.height / tileSize))
            let lastRow = Int(floor((size.height - offset.height) / tileSize))
            guard firstCol <= lastCol, firstRow <= lastRow else { return }

            for col in firstCol...lastCol {
                for row in firstRow...lastRow {
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize + offset.width,
                        y: CGFloat(row) * tileSize + offset.height,
                        width: tileSize,
                        height: tileSize
                    ).insetBy(dx: 3, dy: 3)

                    let isDark = (col + row) % 2 == 0
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 12),
                        with: .color(isDark ? Theme.soilDark : Theme.soilLight)
                    )
                }
            }
        }
    }
}
