import Foundation

/// Sound and visual characters for a continuous, taste-led station.
enum PulseVibe: String, CaseIterable {
    case forYou, favorites, discover, rediscover

    var title: String {
        switch self {
        case .forYou: return "For you"
        case .favorites: return "Favorites"
        case .discover: return "Discover"
        case .rediscover: return "Rediscover"
        }
    }

    var subtitle: String {
        switch self {
        case .forYou: return "Живой, сбалансированный"
        case .favorites: return "Тёплый, плавный"
        case .discover: return "Динамичный, непредсказуемый"
        case .rediscover: return "Спокойный, атмосферный"
        }
    }

    // speed, deformation, fine detail, glow
    var dynamics: SIMD4<Float> {
        switch self {
        case .forYou: return SIMD4(1, 1, 1, 1)
        case .favorites: return SIMD4(0.68, 0.70, 0.55, 0.85)
        case .discover: return SIMD4(1.35, 1.25, 1.35, 1.10)
        case .rediscover: return SIMD4(0.48, 0.45, 0.40, 0.70)
        }
    }

    var tint: SIMD3<Float> {
        switch self {
        case .forYou: return SIMD3(0.66, 0.16, 0.76)
        case .favorites: return SIMD3(0.96, 0.43, 0.24)
        case .discover: return SIMD3(0.30, 0.35, 0.97)
        case .rediscover: return SIMD3(0.18, 0.62, 0.66)
        }
    }
}

/// Presentation only: playback and queue ownership stay in the existing player.
struct PulseHeroState {
    let hasPlayer: Bool
    let isVibe: Bool
    let isPlaying: Bool
    let hasTracks: Bool

    var title: String { hasPlayer && !isVibe ? "Now Playing" : "Your vibe." }
    var accessibilityLabel: String {
        if isPlaying { return "Pause" }
        return hasPlayer ? "Resume" : "Play your vibe"
    }
    var isEnabled: Bool { hasPlayer || hasTracks }
    var resumesPlayback: Bool { hasPlayer }
}

struct LibraryDrawerGeometry {
    static let searchOverscan = 10.0
    static let collapsedTopSpacing = 10.0 + 56.0 + searchOverscan
    static let miniPlayerHeight = 60.0
    static let miniPlayerBottomSpacing = 8.0
    let miniPlayerTop: Double
    let expandedTop: Double
    let collapsedTop: Double
    var travel: Double { max(0, collapsedTop - expandedTop) }

    init(safeTop: Double, safeBottom: Double, containerHeight: Double) {
        self.init(safeTop: safeTop, miniPlayerTop: containerHeight - safeBottom
            - Self.miniPlayerBottomSpacing - Self.miniPlayerHeight)
    }

    init(safeTop: Double, miniPlayerTop: Double) {
        self.miniPlayerTop = miniPlayerTop
        expandedTop = safeTop + 92 - Self.searchOverscan
        // 44 pt search field + 12 pt panel reveal; the mini-player never moves.
        collapsedTop = max(expandedTop, miniPlayerTop - Self.collapsedTopSpacing)
    }

    func top(progress: Double) -> Double { expandedTop + travel * min(1, max(0, progress)) }
    func destination(progress: Double, velocity: Double) -> Double {
        guard travel > 0 else { return 0 }
        return min(1, max(0, progress + velocity * 0.18 / travel)) > 0.5 ? 1 : 0
    }
}


struct LibraryDrawerMotion {
    static func step(position: Double, velocity: Double, target: Double, delta: Double)
        -> (position: Double, velocity: Double, finished: Bool) {
        let dt = min(1.0 / 30, max(0, delta))
        let nextVelocity = velocity + ((target - position) * 190 - velocity * 28) * dt
        let next = min(1, max(0, position + nextVelocity * dt))
        let finished = abs(target - next) < 0.0007 && abs(nextVelocity) < 0.01
        return (finished ? target : next, nextVelocity, finished)
    }
}

struct PulseAudioFrame {
    var bass: Float = 0
    var treble: Float = 0
    var loudness: Float = 0
    var energy: Float = 0
    var vocalPresence: Float = 0
    var bpm: Float = 120

    static func blend(_ values: [(PulseAudioFrame, Float)]) -> PulseAudioFrame {
        let total = values.reduce(Float(0)) { $0 + max(0, $1.1) }
        guard total > 0.0001 else { return PulseAudioFrame() }
        var result = PulseAudioFrame(bpm: 0)
        for (frame, rawWeight) in values {
            let weight = max(0, rawWeight) / total
            result.bass += frame.bass * weight
            result.treble += frame.treble * weight
            result.loudness += frame.loudness * weight
            result.energy += frame.energy * weight
            result.vocalPresence += frame.vocalPresence * weight
            result.bpm += frame.bpm * weight
        }
        return result
    }
}

/// Low/high bands plus a two-stage 300–3400 Hz band-pass for vocal presence.
/// This measures midrange energy, not isolated or recognized singing.
/// The same processor is exercised with silence and synthetic tones in CI.
struct PulseBandAnalyzer {
    private var bassLow = 0.0
    private var trebleLow = 0.0
    private var vocalHigh = SIMD2<Double>.zero
    private var vocalLow = SIMD2<Double>.zero
    private var squares = SIMD4<Double>.zero
    private var count = 0
    private var previousRMS = 0.0
    private let bassCoefficient: Double
    private let trebleCoefficient: Double
    private let vocalHighCoefficient: Double
    private let vocalLowCoefficient: Double
    let hop: Int

    init(sampleRate: Double, hop: Int = 1024) {
        self.hop = hop
        bassCoefficient = 1 - exp(-2 * Double.pi * 180 / sampleRate)
        trebleCoefficient = 1 - exp(-2 * Double.pi * 2500 / sampleRate)
        vocalHighCoefficient = 1 - exp(-2 * Double.pi * 300 / sampleRate)
        vocalLowCoefficient = 1 - exp(-2 * Double.pi * 3400 / sampleRate)
    }

    mutating func consume(_ sample: Double) -> PulseAudioFrame? {
        let value = sample.isFinite ? sample : 0
        bassLow += bassCoefficient * (value - bassLow)
        trebleLow += trebleCoefficient * (value - trebleLow)
        let high = value - trebleLow
        vocalHigh.x += vocalHighCoefficient * (value - vocalHigh.x)
        let highPassed = value - vocalHigh.x
        vocalHigh.y += vocalHighCoefficient * (highPassed - vocalHigh.y)
        vocalLow.x += vocalLowCoefficient * (highPassed - vocalHigh.y - vocalLow.x)
        vocalLow.y += vocalLowCoefficient * (vocalLow.x - vocalLow.y)
        squares += SIMD4(bassLow * bassLow, high * high, value * value, vocalLow.y * vocalLow.y)
        count += 1
        guard count >= hop else { return nil }
        let rms = sqrt(squares.z / Double(count))
        func normalized(_ rms: Double, floor: Double, span: Double) -> Float {
            Float(min(1, max(0, (20 * log10(max(rms, 0.000001)) - floor) / span)))
        }
        let vocalRMS = sqrt(squares.w / Double(count))
        let presence = min(1, vocalRMS / max(rms, 0.000001) / 0.65)
        let result = PulseAudioFrame(
            bass: normalized(sqrt(squares.x / Double(count)), floor: -55, span: 45),
            treble: normalized(sqrt(squares.y / Double(count)), floor: -65, span: 50),
            loudness: normalized(rms, floor: -60, span: 55),
            energy: Float(min(1, max(0, (rms - previousRMS) * 9 + rms * 2))),
            vocalPresence: normalized(vocalRMS, floor: -55, span: 45) * Float(presence))
        previousRMS = rms
        squares = .zero
        count = 0
        return result
    }
}
