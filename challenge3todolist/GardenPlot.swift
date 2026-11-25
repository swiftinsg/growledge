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
struct GardenPlot: View {
    let offset: CGSize

    var body: some View {
        Theme.grass
    }
}
