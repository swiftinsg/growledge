//
//  SoundPlayer.swift
//  The app
//

import Foundation
import AVFoundation

// =====================================================================
// MARK: - Pop sound (you never need to touch this)
// =====================================================================
class SoundPlayer {
    static var player: AVAudioPlayer?
    static let popData = makePopWav()

    static func pop() {
        player = try? AVAudioPlayer(data: popData)
        player?.play()
    }

    static func makePopWav() -> Data {
        let sampleRate = 44100.0
        let duration = 0.12
        let count = Int(sampleRate * duration)

        var samples = [Int16]()
        var phase = 0.0
        for i in 0..<count {
            let progress = Double(i) / Double(count)
            let frequency = 700 - 450 * progress
            phase += 2 * Double.pi * frequency / sampleRate
            let fade = pow(1 - progress, 2)
            samples.append(Int16(sin(phase) * fade * 0.6 * Double(Int16.max)))
        }

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
