//
//  GardenPlot.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - Garden ground: one flat green, nothing else
// =====================================================================

/// The ground is a single plain green. No tile shading, no grid lines and no
/// decorations, so the plants are the only thing you look at.
struct GardenPlot: View, Animatable {
    var offset: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    var body: some View {
        Theme.grass
    }
}
