//
//  SoundPlayer.swift
//  The app
//

import Foundation
import AVFoundation

// =====================================================================
// MARK: - Sound effects (synthesized in code, no audio files needed)
// =====================================================================
class SoundPlayer {
    // Keep a player alive per sound so two effects can overlap without
    // cutting each other off (e.g. a plant sound right after a pop).
    private static var players: [AVAudioPlayer] = []

    private static func play(_ data: Data) {
        guard let player = try? AVAudioPlayer(data: data) else { return }
        players.append(player)
        player.play()
        players.removeAll { !$0.isPlaying }
    }

    /// Short neutral click — menu taps, buy/sell buttons.
    static func pop() { play(popData) }
    /// A little upward "pop-pop" for planting a seed.
    static func plant() { play(plantData) }
    /// A bright two-note chime for a successful harvest.
    static func harvest() { play(harvestData) }
    /// A cheerful rising chime for coins/rewards (session end, task done).
    static func coin() { play(coinData) }
    /// A soft low buzz for things that didn't work.
    static func error() { play(errorData) }

    private static let popData = makeTone(startFrequency: 700, endFrequency: 250, duration: 0.12, volume: 0.6)
    private static let plantData = makeChime(notes: [(500, 0.06), (780, 0.08)], volume: 0.5)
    private static let harvestData = makeChime(notes: [(600, 0.07), (900, 0.07), (1200, 0.1)], volume: 0.55)
    private static let coinData = makeChime(notes: [(700, 0.06), (1050, 0.06), (1400, 0.12)], volume: 0.55)
    private static let errorData = makeTone(startFrequency: 220, endFrequency: 160, duration: 0.18, volume: 0.45)

    // MARK: - Tiny WAV synthesizer

    /// One tone that slides from `startFrequency` to `endFrequency` over `duration`.
    private static func makeTone(startFrequency: Double, endFrequency: Double, duration: Double, volume: Double) -> Data {
        let sampleRate = 44100.0
        let count = Int(sampleRate * duration)
        var samples = [Int16]()
        var phase = 0.0
        for i in 0..<count {
            let progress = Double(i) / Double(count)
            let frequency = startFrequency + (endFrequency - startFrequency) * progress
            phase += 2 * Double.pi * frequency / sampleRate
            let fade = pow(1 - progress, 2)
            samples.append(Int16(sin(phase) * fade * volume * Double(Int16.max)))
        }
        return wav(from: samples, sampleRate: sampleRate)
    }

    /// Several short tones back to back, each at a fixed frequency — a simple "chime".
    private static func makeChime(notes: [(frequency: Double, duration: Double)], volume: Double) -> Data {
        let sampleRate = 44100.0
        var samples = [Int16]()
        for note in notes {
            let count = Int(sampleRate * note.duration)
            var phase = 0.0
            for i in 0..<count {
                let progress = Double(i) / Double(count)
                phase += 2 * Double.pi * note.frequency / sampleRate
                let fade = sin(.pi * progress) // fades in and out smoothly
                samples.append(Int16(sin(phase) * fade * volume * Double(Int16.max)))
            }
        }
        return wav(from: samples, sampleRate: sampleRate)
    }

    private static func wav(from samples: [Int16], sampleRate: Double) -> Data {
        var data = Data()
        func add32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func add16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }

        let dataSize = UInt32(samples.count * 2)
        data.append("RIFF".data(using: .ascii)!)
        add32(36 + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        add32(16)
        add16(1)
        add16(1)
        add32(UInt32(sampleRate))
        add32(UInt32(sampleRate) * 2)
        add16(2)
        add16(16)
        data.append("data".data(using: .ascii)!)
        add32(dataSize)
        for s in samples { add16(UInt16(bitPattern: s)) }
        return data
    }
}
