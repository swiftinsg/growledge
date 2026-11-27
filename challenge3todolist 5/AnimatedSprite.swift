//
//  AnimatedSprite.swift
//  challenge3todolist
//
//  Plays your hand-made animations. It understands more than one file type:
//    .gif                  -> decoded frame by frame (see GIFCache), crisp pixels,
//                             and the white background is cut away so the
//                             plant sits straight on the grass
//    .mp4 / .mov / .m4v    -> played with AVPlayer (muted)
//  Use `AnimatedSprite(file: "emberfigseedplanting.gif")` and it picks the right one.
//

import SwiftUI
import UIKit
import AVFoundation
import ImageIO

// MARK: - Finding the files

enum AnimationFiles {
    /// The file in the app bundle for a name like "sunscale.gif".
    static func url(for file: String) -> URL? {
        let ns = file as NSString
        return Bundle.main.url(forResource: ns.deletingPathExtension, withExtension: ns.pathExtension)
    }

    static func isVideo(_ file: String) -> Bool {
        ["mp4", "mov", "m4v"].contains((file as NSString).pathExtension.lowercased())
    }

    static func isGIF(_ file: String) -> Bool {
        (file as NSString).pathExtension.lowercased() == "gif"
    }
}

// MARK: - GIF decoding

/// A GIF turned into pictures + how long each one is shown. Decoded once,
/// then reused every time the animation plays.
struct GIFClip {
    let frames: [UIImage]
    let durations: [Double]
    var total: Double { durations.reduce(0, +) }

    /// The picture to show `t` seconds after the animation started.
    func frame(at t: Double, loops: Bool) -> UIImage {
        guard let last = frames.last else { return UIImage() }
        guard total > 0 else { return frames[0] }
        var time = loops ? t.truncatingRemainder(dividingBy: total) : min(max(t, 0), total - 0.0001)
        for (i, d) in durations.enumerated() {
            if time < d { return frames[i] }
            time -= d
        }
        return last
    }
}

final class GIFCache {
    static let shared = GIFCache()
    private var clips: [String: GIFClip] = [:]

    /// `clearBackground`: make the white around the picture see-through, so
    /// the plant sits on the garden instead of in a white square. Only white
    /// that touches the edge is removed, so white highlights inside the
    /// picture stay.
    func clip(named file: String, clearBackground: Bool = true) -> GIFClip? {
        let key = "\(file)|\(clearBackground)"
        if let cached = clips[key] { return cached }
        guard let url = AnimationFiles.url(for: file),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [UIImage] = []
        var durations: [Double] = []
        for i in 0..<count {
            guard var cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            if clearBackground { cg = Self.removeEdgeWhite(from: cg) }
            frames.append(UIImage(cgImage: cg))
            durations.append(Self.delay(of: source, at: i))
        }
        guard !frames.isEmpty else { return nil }
        let clip = GIFClip(frames: frames, durations: durations)
        clips[key] = clip
        return clip
    }

    private static func delay(of source: CGImageSource, at index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? 0
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double ?? 0
        let d = unclamped > 0 ? unclamped : clamped
        return d > 0.01 ? d : 0.1
    }

    /// Flood-fills from the picture's edges, turning near-white pixels clear.
    private static func removeEdgeWhite(from cg: CGImage) -> CGImage {
        let w = cg.width, h = cg.height
        guard w > 1, h > 1 else { return cg }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        var result: CGImage?
        pixels.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(data: base, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            let p = raw.bindMemory(to: UInt8.self)

            func isBackground(_ index: Int) -> Bool {
                let o = index * 4
                if p[o + 3] == 0 { return true }
                return p[o] >= 238 && p[o + 1] >= 238 && p[o + 2] >= 238
            }

            var visited = [Bool](repeating: false, count: w * h)
            var stack: [Int] = []
            func seed(_ x: Int, _ y: Int) {
                let i = y * w + x
                if !visited[i] && isBackground(i) { visited[i] = true; stack.append(i) }
            }
            for x in 0..<w { seed(x, 0); seed(x, h - 1) }
            for y in 0..<h { seed(0, y); seed(w - 1, y) }

            while let i = stack.popLast() {
                let o = i * 4
                p[o] = 0; p[o + 1] = 0; p[o + 2] = 0; p[o + 3] = 0
                let x = i % w, y = i / w
                if x > 0 { seed(x - 1, y) }
                if x < w - 1 { seed(x + 1, y) }
                if y > 0 { seed(x, y - 1) }
                if y < h - 1 { seed(x, y + 1) }
            }
            result = ctx.makeImage()
        }
        return result ?? cg
    }
}

// MARK: - The view

/// Plays one animation file (GIF or MP4). `loops: false` plays it once and
/// then calls `onFinished`.
struct AnimatedSprite: View {
    let file: String
    var loops = true
    /// Cut the white background off GIFs (not needed on a white card).
    var clearBackground = true
    var onFinished: (() -> Void)? = nil

    @State private var startDate = Date()

    var body: some View {
        Group {
            if AnimationFiles.isVideo(file) {
                VideoSprite(file: file, loops: loops, onFinished: onFinished)
            } else if let clip = GIFCache.shared.clip(named: file, clearBackground: clearBackground) {
                TimelineView(.animation) { context in
                    Image(uiImage: clip.frame(at: context.date.timeIntervalSince(startDate), loops: loops))
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                }
                .task(id: file) {
                    startDate = Date()
                    if !loops {
                        try? await Task.sleep(nanoseconds: UInt64(clip.total * 1_000_000_000))
                        onFinished?()
                    }
                }
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - MP4 playback

final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct VideoSprite: UIViewRepresentable {
    let file: String
    var loops = true
    var onFinished: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(loops: loops, onFinished: onFinished) }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .white
        view.playerLayer.videoGravity = .resizeAspect
        if let url = AnimationFiles.url(for: file) {
            let player = AVPlayer(url: url)
            player.isMuted = true
            view.playerLayer.player = player
            context.coordinator.attach(player)
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        uiView.playerLayer.player?.pause()
        coordinator.detach()
    }

    final class Coordinator {
        let loops: Bool
        let onFinished: (() -> Void)?
        private var observer: NSObjectProtocol?
        private weak var player: AVPlayer?

        init(loops: Bool, onFinished: (() -> Void)?) {
            self.loops = loops
            self.onFinished = onFinished
        }

        func attach(_ player: AVPlayer) {
            self.player = player
            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if self.loops {
                    self.player?.seek(to: .zero)
                    self.player?.play()
                } else {
                    self.onFinished?()
                }
            }
        }

        func detach() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }

        deinit { detach() }
    }
}

// MARK: - A white card for showing an animation (used by the crop info sheet)

/// The animations were drawn on white, so they look best on a white card.
struct AnimationCard: View {
    let title: String
    let file: String

    var body: some View {
        VStack(spacing: 6) {
            AnimatedSprite(file: file, loops: true, clearBackground: false)
                .frame(width: 130, height: 130)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.panelBorder, lineWidth: 1))
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
        }
    }
}
