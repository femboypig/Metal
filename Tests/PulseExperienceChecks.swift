import Foundation
import AVFoundation

@main
enum PulseExperienceChecks {
    static func main() throws {
        for isVibe in [false, true] {
            for isPlaying in [false, true] {
                let state = PulseHeroState(hasPlayer: true, isVibe: isVibe,
                    isPlaying: isPlaying, hasTracks: true)
                precondition(state.title == (isVibe ? "Your vibe." : "Now Playing"))
                precondition(state.resumesPlayback && state.isEnabled)
                precondition(state.accessibilityLabel == (isPlaying ? "Pause" : "Resume"))
            }
        }
        let idle = PulseHeroState(hasPlayer: false, isVibe: false, isPlaying: false, hasTracks: true)
        precondition(idle.title == "Your vibe." && !idle.resumesPlayback && idle.isEnabled)
        precondition(!PulseHeroState(hasPlayer: false, isVibe: false, isPlaying: false, hasTracks: false).isEnabled)
        for height in [568.0, 667, 812, 844, 932, 1024] {
            for safeTop in [20.0, 47, 59] {
                let miniTop = height - 34 - 8 - 60
                let drawer = LibraryDrawerGeometry(safeTop: safeTop, miniPlayerTop: miniTop)
                precondition(drawer.top(progress: 0) + LibraryDrawerGeometry.searchOverscan == safeTop + 92)
                precondition(abs(drawer.top(progress: 1) + 56 + LibraryDrawerGeometry.searchOverscan - (miniTop - 10)) < 0.001)
                precondition(drawer.top(progress: -1) == drawer.expandedTop)
                precondition(drawer.top(progress: 2) == drawer.collapsedTop)
                precondition(drawer.destination(progress: 0.6, velocity: 0) == 1)
                precondition(drawer.destination(progress: 0.4, velocity: 0) == 0)
                precondition(drawer.destination(progress: 0.4, velocity: 2000) == 1)
                precondition(drawer.destination(progress: 0.6, velocity: -2000) == 0)
            }
        }
        // Restore collapsed geometry before any mini-player child frame exists.
        for height in [568.0, 667, 844, 932, 1024] {
            for safeBottom in [0.0, 21, 34] {
                let drawer = LibraryDrawerGeometry(safeTop: 59, safeBottom: safeBottom, containerHeight: height)
                let miniTop = height - safeBottom - LibraryDrawerGeometry.miniPlayerBottomSpacing
                    - LibraryDrawerGeometry.miniPlayerHeight
                precondition(drawer.miniPlayerTop == miniTop)
                precondition(abs(drawer.top(progress: 1) - (miniTop - LibraryDrawerGeometry.collapsedTopSpacing)) < 0.001)
                let searchBottom = drawer.top(progress: 1) + LibraryDrawerGeometry.searchOverscan + 44
                precondition(searchBottom < miniTop - 10,
                    "A restored collapsed search field must stay above the mini-player on the first layout")
                let resolved = LibraryDrawerGeometry(safeTop: 59, miniPlayerTop: miniTop)
                precondition(drawer.top(progress: 1) == resolved.top(progress: 1),
                    "Initial and subsequent layouts must use the same collapsed position")
            }
        }
        let tiny = LibraryDrawerGeometry(safeTop: 59, miniPlayerTop: 140)
        precondition(tiny.travel == 0 && tiny.destination(progress: 1, velocity: 2000) == 0)

        for destination in [0.0, 1.0] {
            for velocity in [-3.0, 0, 3] {
                var state = (position: 1 - destination, velocity: velocity, finished: false)
                for _ in 0..<120 {
                    state = LibraryDrawerMotion.step(position: state.position, velocity: state.velocity,
                        target: destination, delta: 1.0 / 60)
                    precondition((0...1).contains(state.position), "Drawer must never overshoot")
                    if state.finished { break }
                }
                precondition(state.finished && state.position == destination, "Drawer must settle precisely")
            }
        }
        func analyze(frequency: Double, amplitude: Double) -> PulseAudioFrame {
            var analyzer = PulseBandAnalyzer(sampleRate: 44100)
            var frames: [(PulseAudioFrame, Float)] = []
            for index in 0..<44100 {
                if let frame = analyzer.consume(amplitude * sin(2 * .pi * frequency * Double(index) / 44100)) {
                    if index > 4410 { frames.append((frame, 1)) }
                }
            }
            return PulseAudioFrame.blend(frames)
        }
        let silence = analyze(frequency: 0, amplitude: 0)
        precondition(silence.bass == 0 && silence.treble == 0 && silence.loudness == 0 && silence.vocalPresence == 0)
        let bass = analyze(frequency: 70, amplitude: 0.25)
        let treble = analyze(frequency: 6000, amplitude: 0.25)
        let vocal = analyze(frequency: 1000, amplitude: 0.25)
        precondition(vocal.vocalPresence > bass.vocalPresence + 0.25,
            "Vocal-band energy must react independently of bass")
        precondition(vocal.vocalPresence > analyze(frequency: 10000, amplitude: 0.25).vocalPresence + 0.2)
        precondition(analyze(frequency: 1000, amplitude: 0.01).vocalPresence < vocal.vocalPresence)
        precondition(bass.bass > treble.bass + 0.2)
        precondition(treble.treble > bass.treble + 0.2)
        precondition(analyze(frequency: 70, amplitude: 0.01).loudness < bass.loudness)
        let blend = PulseAudioFrame.blend([(bass, 0.5), (treble, 0.5)])
        let vocalBlend = PulseAudioFrame.blend([(vocal, 0.3), (bass, 0.7)])
        precondition(abs(vocalBlend.vocalPresence - (vocal.vocalPresence * 0.3 + bass.vocalPresence * 0.7)) < 0.0001)
        var invalidAnalyzer = PulseBandAnalyzer(sampleRate: 44100)
        for _ in 0..<2048 {
            if let frame = invalidAnalyzer.consume(.nan) {
                precondition(frame.vocalPresence == 0 && frame.energy == 0)
            }
        }
        precondition(abs(blend.bass - (bass.bass + treble.bass) / 2) < 0.0001)
        precondition(PulseAudioFrame.blend([(bass, 0), (treble, 1)]).bass == treble.bass)
        for vibe in PulseVibe.allCases {
            precondition(vibe.dynamics.x > 0 && vibe.dynamics.x <= 1.5)
            precondition(!vibe.subtitle.isEmpty)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pulse-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let rate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 8)!
        buffer.frameLength = buffer.frameCapacity
        for index in 0..<Int(buffer.frameLength) {
            let frequency = index < 44100 * 4 ? 70.0 : 6000.0
            let value = Float(0.25 * sin(2 * .pi * frequency * Double(index) / rate))
            buffer.floatChannelData![0][index] = value
            buffer.floatChannelData![1][index] = -value // Anti-phase stereo must not cancel the visual signal.
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let sampler = PulseAudioSampler()
        func sample(at time: Double) -> PulseAudioFrame {
            var result: PulseAudioFrame?
            sampler.sample([PulseAudioSource(url: url, time: time, weight: 1, bpm: 136)]) { result = $0 }
            let deadline = Date().addingTimeInterval(10)
            while result == nil && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            precondition(result != nil, "Audio decoding timed out")
            return result!
        }
        let decodedBass = sample(at: 1)
        let decodedTreble = sample(at: 6)
        precondition(decodedBass.bass > decodedTreble.bass + 0.2)
        precondition(decodedTreble.treble > decodedBass.treble + 0.2)
        precondition(decodedBass.bpm == 136 && decodedBass.loudness > 0.5)
        precondition(abs(sample(at: 1).bass - decodedBass.bass) < 0.01, "Seeking should recover the original spectrum")
        print("Pulse: layout, snapping, shared playback state, vocal presence, frequency bands, loudness, crossfade, stereo decoding and seeking passed")
    }
}
