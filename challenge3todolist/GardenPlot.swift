
import SwiftUI

struct GardenPlot: View, Animatable {
    var offset: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset.width, offset.height) }
        set {
            offset = CGSize(width: newValue.first, height: newValue.second)
        }
    }

    var body: some View {
        let size = Theme.tileSize
        let plotSize = size * 3

        ZStack {
            // Green grass surrounding the entire garden
            Theme.grass

            // One neat square of brown soil
            Rectangle()
                .fill(Color(red: 0.48, green: 0.29, blue: 0.16))
                .frame(width: plotSize, height: plotSize)
                .position(
                    x: plotSize / 2 + offset.width,
                    y: plotSize / 2 + offset.height
                )
        }
    }
}

