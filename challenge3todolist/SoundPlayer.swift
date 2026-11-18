//
//  SoundPlayer.swift
//  The app
//

import Foundation
import AVFoundation
import Combine

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
    /// A bigger, sparklier version of the harvest chime for a rare mutation.
    static func mutation() { play(mutationData) }
    /// A tiny, dry tick — picking an item up to drag it.
    static func pickUp() { play(pickUpData) }
    /// A soft, low thud — dropping/placing something down.
    static func dropDown() { play(dropDownData) }
    /// A light, neutral click for switching tabs/segments/pages.
    static func select() { play(selectData) }
    /// A quick two-step "whoosh" for opening a screen (shop, sell, full screen timer).
    static func whoosh() { play(whooshData) }
    /// A short, urgent alarm blip for the tornado disaster striking.
    static func alarm() { play(alarmData) }
    /// A warm cash-register-style "cha-ching" for the shop opening.
    static func shopBell() { play(shopBellData) }
    /// A satisfying downward tick for checking off a to-do item.
    static func taskDone() { play(taskDoneData) }
    /// A bigger fanfare for finishing a whole study session.
    static func fanfare() { play(fanfareData) }
    /// A soft descending blip for removing/clearing something.
    static func remove() { play(removeData) }

    private static let popData = makeTone(startFrequency: 760, endFrequency: 280, duration: 0.11, volume: 0.55)
    private static let plantData = makeChime(notes: [(520, 0.06), (820, 0.08)], volume: 0.45)
    private static let harvestData = makeChime(notes: [(620, 0.06), (930, 0.06), (1260, 0.12)], volume: 0.5)
    private static let coinData = makeChime(notes: [(740, 0.05), (1110, 0.05), (1480, 0.12)], volume: 0.5)
    private static let errorData = makeTone(startFrequency: 230, endFrequency: 150, duration: 0.16, volume: 0.4)
    private static let mutationData = makeChime(notes: [(700, 0.05), (1000, 0.05), (1400, 0.05), (1900, 0.16)], volume: 0.6)
    private static let pickUpData = makeTone(startFrequency: 900, endFrequency: 1100, duration: 0.045, volume: 0.35)
    private static let dropDownData = makeTone(startFrequency: 340, endFrequency: 180, duration: 0.09, volume: 0.45)
    private static let selectData = makeTone(startFrequency: 980, endFrequency: 860, duration: 0.05, volume: 0.3)
    private static let whooshData = makeChime(notes: [(260, 0.05), (420, 0.07)], volume: 0.35)
    private static let alarmData = makeChime(notes: [(880, 0.09), (660, 0.09), (880, 0.09), (660, 0.12)], volume: 0.55)
    private static let shopBellData = makeChime(notes: [(900, 0.07), (1350, 0.07), (900, 0.05), (1350, 0.14)], volume: 0.5)
    private static let taskDoneData = makeChime(notes: [(560, 0.05), (840, 0.1)], volume: 0.45)
    private static let fanfareData = makeChime(notes: [(660, 0.08), (880, 0.08), (1100, 0.08), (1320, 0.18)], volume: 0.6)
    private static let removeData = makeTone(startFrequency: 500, endFrequency: 260, duration: 0.1, volume: 0.35)

    // MARK: - Tiny WAV synthesizer
    //
    // Every effect is two slightly-detuned oscillators layered together (a
    // "unison" sound, the same trick synth patches use to sound fuller and
    // less like a single flat beep) with a soft, rounded envelope instead of
    // a hard linear fade — this is what makes it read as a modern UI sound
    // rather than an old arcade blip.

    /// One tone that slides from `startFrequency` to `endFrequency` over `duration`.
    private static func makeTone(startFrequency: Double, endFrequency: Double, duration: Double, volume: Double) -> Data {
        let sampleRate = 44100.0
        let count = Int(sampleRate * duration)
        var samples = [Int16]()
        var phaseA = 0.0
        var phaseB = 0.0
        for i in 0..<count {
            let progress = Double(i) / Double(count)
            let frequency = startFrequency + (endFrequency - startFrequency) * progress
            phaseA += 2 * Double.pi * frequency / sampleRate
            phaseB += 2 * Double.pi * (frequency * 1.006) / sampleRate   // tiny detune for a fuller tone
            // Raised-cosine attack into a gentle decay — no harsh clicks.
            let attack = min(1, progress / 0.08)
            let envelope = (0.5 - 0.5 * cos(.pi * attack)) * pow(1 - progress, 1.3)
            let sample = sin(phaseA) * 0.62 + sin(phaseB) * 0.38
            samples.append(Int16(sample * envelope * volume * Double(Int16.max)))
        }
        return wav(from: samples, sampleRate: sampleRate)
    }

    /// Several short tones back to back, each at a fixed frequency — a simple
    /// "chime", with a bright octave-up shimmer layered on top of each note.
    private static func makeChime(notes: [(frequency: Double, duration: Double)], volume: Double) -> Data {
        let sampleRate = 44100.0
        var samples = [Int16]()
        for note in notes {
            let count = Int(sampleRate * note.duration)
            var phase = 0.0
            var shimmerPhase = 0.0
            for i in 0..<count {
                let progress = Double(i) / Double(count)
                phase += 2 * Double.pi * note.frequency / sampleRate
                shimmerPhase += 2 * Double.pi * (note.frequency * 2.01) / sampleRate
                let envelope = sin(.pi * progress) // fades in and out smoothly
                let bell = sin(phase) * 0.82 + sin(shimmerPhase) * 0.18
                samples.append(Int16(bell * envelope * volume * Double(Int16.max)))
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

// =====================================================================
// MARK: - Background music (your own bundled tracks, looped)
// =====================================================================

/// Filenames for the music you added to the project. Make sure each file is
/// dragged into Xcode with its Target Membership checkbox ticked, or the
/// app will simply find nothing to play and stay silent for that track.
enum Music {
    static let garden = "Garden Music.mp3"
    static let moogCity = "Moog City.mp3"
    static let ariaMath = "C418 - Aria Math (Minecraft Volume Beta).mp3"
    static let sundowner = "SUNDOWNER - Brandon Works Map Theme Forsaken OST.mp3"
    // Funny track — garden only, kept out of the study playlist on purpose.
    static let verityDisstrack = "Verity Disstrack - Official Music Video.mp3"
    static let hollowEvening = "A Hollow Evening Halloween Event Track (FORSAKEN).mp3"
    static let infiniteAmethyst = "Infinite Amethyst.mp3"
    static let nuclearOverture = "NUCLEAR OVERTURE.mp3"

    /// Plays while the garden is on screen.
    static let gardenPlaylist = [garden, sundowner, verityDisstrack, infiniteAmethyst, nuclearOverture]
    /// Plays while a study session is running. No Verity Disstrack here —
    /// it's a funny song, not one for focusing.
    static let studyPlaylist = [moogCity, ariaMath, sundowner, infiniteAmethyst, nuclearOverture]

    /// Tracks that should come up less often than the rest when a playlist
    /// is shuffled — a nice surprise rather than something heard every loop.
    /// (The "weathergirl" track is the Garden Music file itself — see the
    /// duplicate-file note from before.)
    static let rareTracks: Set<String> = [garden]

    /// Every track in the app, with a friendly display name, for the Relax
    /// tab's song library — so there's one list to pick any of them from
    /// freely, outside of the garden/study playlists.
    static let library: [MusicTrack] = [
        MusicTrack(name: "Garden Afternoon", file: garden),
        MusicTrack(name: "Moog City", file: moogCity),
        MusicTrack(name: "Aria Math", file: ariaMath),
        MusicTrack(name: "Sundowner", file: sundowner),
        MusicTrack(name: "Verity Disstrack", file: verityDisstrack),
        MusicTrack(name: "A Hollow Evening", file: hollowEvening),
        MusicTrack(name: "Infinite Amethyst", file: infiniteAmethyst),
        MusicTrack(name: "Nuclear Overture", file: nuclearOverture)
    ]
}

/// One entry in the Relax tab's song library.
struct MusicTrack: Identifiable {
    var id: String { file }
    let name: String
    let file: String
}

/// Loops background music — the garden theme, or the study playlist.
/// Separate from `SoundPlayer`'s short one-shot effects so the two never
/// interrupt each other.
final class MusicPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = MusicPlayer()

    /// The filename currently playing (or fading in/out), so UI like the
    /// Relax tab's song library can show which track is active and react
    /// live when it changes — including from somewhere else entirely, like
    /// the garden playlist advancing to its next song.
    @Published private(set) var currentFile: String?

    private var player: AVAudioPlayer?
    private var playlist: [String] = []
    private var playlistIndex = 0
    private var fadeWorkItems: [DispatchWorkItem] = []

    private override init() {
        super.init()
        // .playback (not .ambient) so this keeps playing reliably even with
        // the silent switch on or the screen locked, and mixWithOthers so it
        // never fights the short sound effects for the speaker. This is the
        // main fix for music being "a gamble" about whether it plays.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Loops a single track forever. Calling this again with the same track
    /// while it's already playing does nothing, so it's safe to call from
    /// `onAppear`.
    func loop(_ filename: String, volume: Float = 0.35) {
        guard let url = Self.url(for: filename) else { return }
        if player?.url == url, player?.isPlaying == true { return }
        playlist = []
        currentFile = filename
        start(url: url, loopForever: true, volume: volume)
    }

    /// Plays a list of tracks, picked at random (some rarer than others —
    /// see `Music.rareTracks`), forever. Calling this again with the exact
    /// same list while it's already playing does nothing, so switching
    /// screens that both want the garden playlist doesn't restart the song
    /// from the top every time.
    func playPlaylist(_ filenames: [String], volume: Float = 0.3) {
        guard !filenames.isEmpty else { return }
        if playlist == filenames, player?.isPlaying == true { return }
        playlist = filenames
        playlistIndex = Self.weightedPick(filenames)
        currentFile = playlist[playlistIndex]
        guard let url = Self.url(for: playlist[playlistIndex]) else { return }
        start(url: url, loopForever: false, volume: volume)
    }

    func pause() { player?.pause() }
    func resume() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }

    func stop() {
        cancelFades()
        player?.stop()
        player = nil
        playlist = []
        currentFile = nil
    }

    /// Smoothly fades the current track out, then stops it. Safe to call
    /// even if a different track has started playing in the meantime — it
    /// only ever stops the exact player it started fading, never whatever
    /// happens to be playing by the time the fade finishes. (Without this
    /// check, a fade-out left over from a screen you already navigated away
    /// from could silently kill music a different screen just started —
    /// this was the cause of music stopping itself a couple of seconds in.)
    func fadeOutAndStop(duration: TimeInterval = 0.8) {
        guard let activePlayer = player, activePlayer.isPlaying else { stop(); return }
        cancelFades()
        let steps = 12
        let startVolume = activePlayer.volume
        for i in 0...steps {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.player === activePlayer else { return }
                let remaining = 1 - Double(i) / Double(steps)
                activePlayer.volume = startVolume * Float(remaining)
                if i == steps {
                    activePlayer.stop()
                    self.player = nil
                    self.playlist = []
                    self.currentFile = nil
                }
            }
            fadeWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i) / Double(steps), execute: work)
        }
    }

    private func cancelFades() {
        fadeWorkItems.forEach { $0.cancel() }
        fadeWorkItems.removeAll()
    }

    private func start(url: URL, loopForever: Bool, volume: Float) {
        // Cancelling any in-flight fade-out below means its final "stop the
        // old player" step never runs — so the old player must be stopped
        // here explicitly, or it keeps playing, orphaned, underneath the new
        // track. This (silent, overlapping, long-dead players) was the real
        // cause of music feeling like "a gamble" whenever screens switched
        // quickly, e.g. opening the Buy shop right after entering the game.
        cancelFades()
        player?.stop()
        player = nil

        // Re-activating here (not just once at init) recovers automatically
        // from interruptions — a phone call, another app's audio, AirPods
        // switching — that can otherwise silently deactivate the session and
        // leave every future track refusing to play.
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        p.numberOfLoops = loopForever ? -1 : 0
        p.volume = 0
        p.prepareToPlay()
        p.play()
        player = p

        // A short fade-in instead of snapping straight to full volume, so
        // switching tracks (e.g. garden → shop music) feels smooth instead
        // of an abrupt jolt.
        let steps = 8
        let fadeInDuration = 0.4
        for i in 0...steps {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.player === p else { return }
                p.volume = volume * Float(i) / Float(steps)
            }
            fadeWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeInDuration * Double(i) / Double(steps), execute: work)
        }
    }

    private static func url(for filename: String) -> URL? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        if !ext.isEmpty, let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        for candidate in ["mp3", "m4a", "wav", "aac"] {
            if let url = Bundle.main.url(forResource: name, withExtension: candidate) { return url }
        }
        return nil
    }

    /// How likely a track is to be picked — tracks in `Music.rareTracks`
    /// come up far less often than the rest.
    private static func weight(for filename: String) -> Double {
        Music.rareTracks.contains(filename) ? 0.25 : 1.0
    }

    private static func weightedPick(_ list: [String]) -> Int {
        guard list.count > 1 else { return 0 }
        let weights = list.map { weight(for: $0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return Int.random(in: 0..<list.count) }
        var r = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            if r < w { return i }
            r -= w
        }
        return list.count - 1
    }

    /// Picks a weighted-random track, avoiding an immediate repeat of
    /// `avoiding` when there's more than one track to choose from.
    private static func weightedPickAvoiding(_ list: [String], _ avoiding: Int) -> Int {
        guard list.count > 1 else { return 0 }
        for _ in 0..<6 {
            let idx = weightedPick(list)
            if idx != avoiding { return idx }
        }
        return weightedPick(list)
    }

    // Picks the next track at random (weighted so rare tracks stay rare)
    // rather than the next one in order, so the playlist never feels like
    // it's on a fixed rotation.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard !playlist.isEmpty else { return }
        playlistIndex = Self.weightedPickAvoiding(playlist, playlistIndex)
        currentFile = playlist[playlistIndex]
        if let url = Self.url(for: playlist[playlistIndex]) {
            start(url: url, loopForever: false, volume: player.volume)
        }
    }
}
