//
//  FruitArt.swift
//  challenge3todolist
//
//  All the garden artwork, drawn in code (no picture files): a seed packet
//  for each seed, a sprout while it grows, and the fruit itself once it is
//  ready. Seeds, sprouts and fruits each have their own look so you can tell
//  at a glance what you are holding.
//

import SwiftUI

extension Color {
    /// A colour from a hex number such as 0x5BC0EB.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// The overall shape of a fruit.
enum FruitShape {
    case orb, drop, pear, star, crystal, flame, lotus, cluster, spiral
}

/// How one fruit looks: its shape and two colours (a deep one and a light one).
struct FruitStyle {
    var shape: FruitShape
    var primary: Color
    var secondary: Color
    /// Whether it grows on a leafy stem (flames, stars and gems don't).
    var leaf = true

    static let fallback = FruitStyle(shape: .orb, primary: Color(hex: 0x7BC950), secondary: Color(hex: 0xDDF7B0))
}

// MARK: - Shapes

/// A teardrop with its point at the top.
private struct TeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: p(0.5, 0))
        path.addCurve(to: p(0.95, 0.64), control1: p(0.62, 0.22), control2: p(0.95, 0.4))
        path.addCurve(to: p(0.5, 1), control1: p(0.95, 0.86), control2: p(0.74, 1))
        path.addCurve(to: p(0.05, 0.64), control1: p(0.26, 1), control2: p(0.05, 0.86))
        path.addCurve(to: p(0.5, 0), control1: p(0.05, 0.4), control2: p(0.38, 0.22))
        path.closeSubpath()
        return path
    }
}

/// A pear: a small circle on top of a big one.
private struct PearShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.26, y: rect.minY + h * 0.04, width: w * 0.48, height: h * 0.5))
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.1, y: rect.minY + h * 0.3, width: w * 0.8, height: h * 0.68))
        return path
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.5
        var path = Path()
        for i in 0..<10 {
            let radius = i % 2 == 0 ? outer : inner
            let angle = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// A cut gem.
private struct GemShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: p(0.27, 0.1))
        path.addLine(to: p(0.73, 0.1))
        path.addLine(to: p(0.97, 0.38))
        path.addLine(to: p(0.5, 0.98))
        path.addLine(to: p(0.03, 0.38))
        path.closeSubpath()
        return path
    }
}

private struct GemFacets: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: p(0.03, 0.38)); path.addLine(to: p(0.97, 0.38))
        path.move(to: p(0.27, 0.1)); path.addLine(to: p(0.38, 0.38)); path.addLine(to: p(0.5, 0.98))
        path.move(to: p(0.73, 0.1)); path.addLine(to: p(0.62, 0.38)); path.addLine(to: p(0.5, 0.98))
        return path
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: p(0.5, 0))
        path.addCurve(to: p(0.9, 0.62), control1: p(0.62, 0.22), control2: p(0.9, 0.36))
        path.addCurve(to: p(0.5, 1), control1: p(0.9, 0.84), control2: p(0.72, 1))
        path.addCurve(to: p(0.1, 0.62), control1: p(0.28, 1), control2: p(0.1, 0.84))
        path.addCurve(to: p(0.34, 0.3), control1: p(0.1, 0.46), control2: p(0.24, 0.4))
        path.addCurve(to: p(0.5, 0), control1: p(0.36, 0.2), control2: p(0.44, 0.1))
        path.closeSubpath()
        return path
    }
}

private struct SpiralLine: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2 * 0.8
        var path = Path()
        let steps = 90
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let radius = maxRadius * t
            let angle = t * 4 * .pi
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.3))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.3))
        return path
    }
}

private let leafGreen = Color(hex: 0x4CAF50)
private let stemBrown = Color(hex: 0x6D4C41)

// MARK: - Pixel pictures

/// One of the hand-made pixel pictures, drawn sharp (not blurred) at any size.
struct PixelImage: View {
    let name: String
    var size: CGFloat = 44
    var tint: Color? = nil

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .colorMultiply(tint ?? .white)
            .frame(width: size, height: size)
    }
}

/// The harvested fruit of a crop: its pixel picture if there is one,
/// otherwise the drawn fruit.
struct CropFruitView: View {
    let crop: Crop
    var size: CGFloat = 44
    var tint: Color? = nil

    var body: some View {
        if let name = crop.art?.fruit {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(tint ?? crop.style.primary).opacity(0.4), .clear],
                                         center: .center, startRadius: 0, endRadius: size * 0.55))
                    .frame(width: size * 1.1, height: size * 1.1)
                PixelImage(name: name, size: size * 0.8, tint: tint)
            }
            .frame(width: size, height: size)
        } else {
            FruitView(style: crop.style, size: size, tint: tint)
        }
    }
}

/// A crop's seed: its pixel picture if there is one, otherwise a drawn seed packet.
struct CropSeedView: View {
    let crop: Crop
    var size: CGFloat = 44

    var body: some View {
        if let name = crop.art?.seed {
            ZStack {
                Circle().fill(crop.style.primary.opacity(0.22))
                PixelImage(name: name, size: size * 0.78)
            }
            .frame(width: size, height: size)
        } else if let fruit = crop.art?.fruit {
            // No seed picture yet: a little seed pouch with the fruit it grows.
            ZStack {
                Circle().fill(Theme.card)
                Circle().stroke(Theme.panelBorder, lineWidth: max(1.5, size * 0.04))
                PixelImage(name: fruit, size: size * 0.58)
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.2))
                    .foregroundStyle(Theme.good)
                    .offset(x: size * 0.28, y: size * 0.28)
            }
            .frame(width: size, height: size)
        } else {
            SeedPacketView(style: crop.style, size: size)
        }
    }
}

// MARK: - The grown fruit

/// A fully grown fruit, with a soft glow behind it. `tint` is used by
/// mutations (gold, silver, ...) to recolour it.
struct FruitView: View {
    let style: FruitStyle
    var size: CGFloat = 44
    var tint: Color? = nil

    var body: some View {
        ZStack {
            // soft glow
            Circle()
                .fill(RadialGradient(colors: [(tint ?? style.primary).opacity(0.5), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.55))
                .frame(width: size * 1.1, height: size * 1.1)

            body(for: style.shape)
                .frame(width: size * 0.74, height: size * 0.74)
                .colorMultiply(tint ?? .white)
                .offset(y: size * 0.04)

            if style.leaf && style.shape != .lotus {
                stem
            }

            // a little sparkle so every fruit feels special
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: size * 0.3, y: -size * 0.28)
        }
        .frame(width: size, height: size)
    }

    private var gradient: LinearGradient {
        LinearGradient(colors: [style.secondary, style.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var stem: some View {
        ZStack {
            Capsule().fill(stemBrown).frame(width: size * 0.05, height: size * 0.14)
            LeafShape().fill(leafGreen).frame(width: size * 0.22, height: size * 0.11)
                .rotationEffect(.degrees(-25)).offset(x: size * 0.1, y: size * 0.02)
        }
        .offset(y: -size * 0.34)
    }

    private var highlight: some View {
        Ellipse().fill(.white.opacity(0.5))
            .frame(width: size * 0.16, height: size * 0.09)
            .rotationEffect(.degrees(-35))
            .offset(x: -size * 0.14, y: -size * 0.14)
    }

    @ViewBuilder
    private func body(for shape: FruitShape) -> some View {
        switch shape {
        case .orb:
            ZStack { Circle().fill(gradient); Circle().stroke(style.primary.opacity(0.6), lineWidth: 1); highlight }
        case .drop:
            ZStack { TeardropShape().fill(gradient); TeardropShape().stroke(style.primary.opacity(0.6), lineWidth: 1); highlight.offset(y: size * 0.06) }
        case .pear:
            ZStack { PearShape().fill(gradient); PearShape().stroke(style.primary.opacity(0.5), lineWidth: 1); highlight.offset(y: size * 0.1) }
        case .star:
            ZStack {
                StarShape().fill(gradient)
                StarShape().stroke(style.primary, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        case .crystal:
            ZStack {
                GemShape().fill(gradient)
                GemFacets().stroke(.white.opacity(0.55), lineWidth: 1)
                GemShape().stroke(style.primary, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        case .flame:
            ZStack {
                FlameShape().fill(LinearGradient(colors: [style.secondary, style.primary], startPoint: .top, endPoint: .bottom))
                FlameShape().fill(style.secondary.opacity(0.7)).scaleEffect(0.45, anchor: .bottom)
            }
        case .lotus:
            ZStack {
                ForEach([-52.0, -26.0, 26.0, 52.0, 0.0], id: \.self) { angle in
                    TeardropShape()
                        .fill(LinearGradient(colors: [style.secondary, style.primary], startPoint: .top, endPoint: .bottom))
                        .overlay(TeardropShape().stroke(style.primary.opacity(0.5), lineWidth: 0.8))
                        .frame(width: size * 0.3, height: size * 0.5)
                        .rotationEffect(.degrees(angle), anchor: .bottom)
                        .offset(y: -size * 0.08)
                }
                Circle().fill(style.secondary).frame(width: size * 0.16, height: size * 0.16).offset(y: size * 0.06)
            }
        case .cluster:
            ZStack {
                ForEach(Array(clusterPoints.enumerated()), id: \.offset) { _, point in
                    Circle().fill(gradient)
                        .overlay(Circle().stroke(style.primary.opacity(0.6), lineWidth: 0.8))
                        .frame(width: size * 0.27, height: size * 0.27)
                        .offset(x: (point.x - 0.5) * size * 0.74, y: (point.y - 0.5) * size * 0.74)
                }
            }
        case .spiral:
            ZStack {
                Circle().fill(gradient)
                SpiralLine().stroke(style.secondary.opacity(0.8), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                Circle().stroke(style.primary.opacity(0.6), lineWidth: 1)
                highlight
            }
        }
    }

    private var clusterPoints: [CGPoint] {
        [CGPoint(x: 0.2, y: 0.22), CGPoint(x: 0.5, y: 0.2), CGPoint(x: 0.8, y: 0.22),
         CGPoint(x: 0.33, y: 0.5), CGPoint(x: 0.67, y: 0.5), CGPoint(x: 0.5, y: 0.8)]
    }
}

// MARK: - The seed

/// A seed packet: a cream envelope with the fruit's colour on the flap and a
/// small seed in the middle. This is only ever used for seeds, never fruits.
struct SeedPacketView: View {
    let style: FruitStyle
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color(hex: 0xF4ECD8))
            RoundedRectangle(cornerRadius: size * 0.1)
                .stroke(style.primary.opacity(0.7), lineWidth: 1.5)

            VStack(spacing: 0) {
                // the coloured top flap
                UnevenRoundedRectangle(topLeadingRadius: size * 0.1, topTrailingRadius: size * 0.1)
                    .fill(style.primary)
                    .frame(height: size * 0.2)
                Spacer(minLength: 0)
            }

            // the seed
            TeardropShape()
                .fill(LinearGradient(colors: [style.secondary, style.primary.opacity(0.9)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(TeardropShape().stroke(style.primary, lineWidth: 1))
                .frame(width: size * 0.26, height: size * 0.34)
                .rotationEffect(.degrees(20))
                .offset(y: size * 0.1)
        }
        .frame(width: size * 0.66, height: size * 0.82)
        .shadow(color: .black.opacity(0.25), radius: size * 0.04, y: size * 0.03)
        .frame(width: size, height: size)
    }
}

// MARK: - The growing plant

/// What grows in a plot: a small seed on the grass, then a sapling that gets
/// bigger, then a full-grown tree (taller than the plot, so it looks like a
/// real tree). Just the plant, nothing around it. `size` is the plot size.
struct PlantStageView: View {
    let crop: Crop
    private var style: FruitStyle { crop.style }
    /// 0...1: how far along the growing is.
    let progress: Double
    /// The size of one plot.
    var size: CGFloat = 32

    /// How much taller than its plot a full-grown tree is.
    static let treeScale: CGFloat = 1.45

    var body: some View {
        ZStack(alignment: .bottom) {
            if progress >= 1 {
                grownTree
            } else if progress < 0.12 {
                seed
            } else {
                sapling
            }
        }
        // The plant may stand taller than its plot; it is anchored at the bottom.
        .frame(width: size, height: size, alignment: .bottom)
    }

    private var grownTree: some View {
        Group {
            if let tree = crop.art?.tree {
                PixelImage(name: tree, size: size * Self.treeScale)
            } else {
                VectorTree(style: style, size: size * Self.treeScale)
            }
        }
        .padding(.bottom, size * 0.04)
    }

    private var seed: some View {
        Group {
            if let name = crop.art?.seed {
                PixelImage(name: name, size: size * 0.34)
            } else if let fruit = crop.art?.fruit {
                PixelImage(name: fruit, size: size * 0.26)
                    .saturation(0.6)
            } else {
                TeardropShape()
                    .fill(style.primary)
                    .frame(width: size * 0.12, height: size * 0.17)
                    .rotationEffect(.degrees(25))
            }
        }
        .padding(.bottom, size * 0.3)
    }

    private var sapling: some View {
        // 0...1 across the sapling stage only
        let t = min(max((progress - 0.12) / 0.88, 0), 1)
        return Group {
            if let name = crop.art?.sapling {
                PixelImage(name: name, size: size * (0.5 + 0.45 * t))
            } else {
                VectorSprout(style: style, t: t, size: size * 0.8)
            }
        }
        .padding(.bottom, size * 0.04)
    }
}

/// A drawn sapling, for crops that have no sapling picture yet.
private struct VectorSprout: View {
    let style: FruitStyle
    let t: Double
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(leafGreen)
                .frame(width: size * 0.08, height: size * (0.25 + 0.5 * t))
            LeafShape().fill(leafGreen)
                .frame(width: size * (0.18 + 0.3 * t), height: size * (0.1 + 0.15 * t))
                .rotationEffect(.degrees(-30))
                .offset(x: -size * (0.12 + 0.1 * t), y: -size * (0.25 + 0.3 * t))
            LeafShape().fill(leafGreen.opacity(0.85))
                .frame(width: size * (0.18 + 0.3 * t), height: size * (0.1 + 0.15 * t))
                .rotationEffect(.degrees(30))
                .offset(x: size * (0.12 + 0.1 * t), y: -size * (0.33 + 0.3 * t))
            if t > 0.6 {
                Circle().fill(style.primary)
                    .frame(width: size * 0.2 * ((t - 0.6) / 0.4), height: size * 0.2 * ((t - 0.6) / 0.4))
                    .offset(y: -size * (0.25 + 0.5 * t))
            }
        }
        .frame(width: size, height: size, alignment: .bottom)
    }
}

/// A drawn tree with the fruit hanging on it, for crops that have no tree picture yet.
private struct VectorTree: View {
    let style: FruitStyle
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            // trunk
            RoundedRectangle(cornerRadius: size * 0.03)
                .fill(stemBrown)
                .frame(width: size * 0.12, height: size * 0.4)
            // leafy top
            ZStack {
                Circle().fill(leafGreen).frame(width: size * 0.5, height: size * 0.5).offset(x: -size * 0.14, y: size * 0.05)
                Circle().fill(leafGreen.opacity(0.92)).frame(width: size * 0.5, height: size * 0.5).offset(x: size * 0.14, y: size * 0.05)
                Circle().fill(Color(hex: 0x57B85A)).frame(width: size * 0.56, height: size * 0.56).offset(y: -size * 0.08)
                // the fruit
                ForEach(Array([CGPoint(x: -0.17, y: 0.0), CGPoint(x: 0.12, y: -0.14), CGPoint(x: 0.2, y: 0.08), CGPoint(x: -0.04, y: 0.12)].enumerated()), id: \.offset) { _, p in
                    Circle().fill(style.primary)
                        .overlay(Circle().fill(style.secondary.opacity(0.5)).frame(width: size * 0.03).offset(x: -size * 0.015, y: -size * 0.015))
                        .frame(width: size * 0.09, height: size * 0.09)
                        .offset(x: p.x * size, y: p.y * size)
                }
            }
            .offset(y: -size * 0.3)
        }
        .frame(width: size, height: size, alignment: .bottom)
    }
}

#Preview("Fruits and seeds") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            ForEach(Catalog.crops) { crop in
                VStack(spacing: 6) {
                    CropFruitView(crop: crop, size: 64)
                    CropSeedView(crop: crop, size: 48)
                    PlantStageView(crop: crop, progress: 0.7, size: 48)
                    PlantStageView(crop: crop, progress: 1, size: 48)
                    Text(crop.name).font(.caption2)
                }
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
