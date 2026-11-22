import Foundation

/// A continuous taste-led station. Vibes adjust the sound target rather than
/// acting as the Daily Mix's favorites/unheard/forgotten collection filters.
enum PulseFlowEngine {
    static func nextTracks(from candidates: [DailyMixCandidate], vibe: PulseVibe,
        previousTrackID: String?, recentTrackIDs: [String], reservedTrackIDs: Set<String>,
        previousUpcoming: [String] = [], seed: UInt64, limit: Int = 10) -> [String] {
        guard limit > 0 else { return [] }
        let safe = candidates.filter { $0.recentRejection < 0.7 && $0.fatiguePenalty < 0.6 }
        let trusted = safe.filter { $0.taste >= 0.45 }
        let eligible = trusted.isEmpty ? safe : safe.filter { $0.taste >= 0.25 }
        var pool = eligible.filter { !reservedTrackIDs.contains($0.id) }
        guard !pool.isEmpty else { return [] }
        let learned = eligible.filter(\.hasAnalyzedVibe)
        let weight = learned.reduce(0.0) { $0 + max(0.1, $1.taste) }
        func average(_ key: KeyPath<AudioVibeProfile, Double>, fallback: Double) -> Double {
            guard weight > 0 else { return fallback }
            return learned.reduce(0) { $0 + $1.vibe[keyPath: key] * max(0.1, $1.taste) } / weight
        }
        let baseline = AudioVibeProfile(bpm: average(\.bpm, fallback: 110),
            energy: average(\.energy, fallback: 0.55), brightness: average(\.brightness, fallback: 0.5),
            dynamics: average(\.dynamics, fallback: 0.5))
        let target: AudioVibeProfile
        func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { min(high, max(low, value)) }
        switch vibe {
        case .forYou: target = baseline
        case .favorites:
            target = AudioVibeProfile(bpm: clamp(baseline.bpm - 14, 70, 112),
                energy: clamp(baseline.energy - 0.15, 0.25, 0.52),
                brightness: clamp(baseline.brightness - 0.12, 0.2, 0.52),
                dynamics: clamp(baseline.dynamics - 0.10, 0.25, 0.55))
        case .discover:
            target = AudioVibeProfile(bpm: clamp(baseline.bpm + 18, 110, 160),
                energy: clamp(baseline.energy + 0.22, 0.62, 0.9),
                brightness: clamp(baseline.brightness + 0.16, 0.55, 0.9),
                dynamics: clamp(baseline.dynamics + 0.2, 0.6, 0.95))
        case .rediscover:
            target = AudioVibeProfile(bpm: clamp(baseline.bpm - 26, 60, 96),
                energy: clamp(baseline.energy - 0.28, 0.12, 0.36),
                brightness: clamp(baseline.brightness - 0.2, 0.15, 0.42),
                dynamics: clamp(baseline.dynamics - 0.18, 0.15, 0.42))
        }
        let cooldownCount = min(8, max(1, pool.count / 2))
        let cooldown = Set(recentTrackIDs.suffix(cooldownCount))
        let rested = pool.filter { !cooldown.contains($0.id) }
        if !rested.isEmpty { pool = rested }
        let byID = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let oldUpcoming = Set(previousUpcoming)
        var selected: [DailyMixCandidate] = []
        var artists: [String: Int] = [:]
        func artist(_ track: DailyMixCandidate) -> String {
            let value = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return value.isEmpty || value == "unknown artist" ? track.id : value
        }
        func noise(_ id: String, step: Int) -> Double {
            var hash = seed ^ UInt64(step) &* 0x9e3779b97f4a7c15
            for byte in id.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
            hash = (hash ^ (hash >> 30)) &* 0xbf58476d1ce4e5b9
            hash ^= hash >> 27
            return Double(hash >> 11) / 9_007_199_254_740_992
        }
        while !pool.isEmpty && selected.count < limit {
            let previous = selected.last ?? previousTrackID.flatMap { byID[$0] }
            let ranked = pool.map { candidate -> (DailyMixCandidate, Double) in
                let distance = abs(candidate.vibe.bpm - target.bpm) / 100 * 0.25
                    + abs(candidate.vibe.energy - target.energy) * 0.43
                    + abs(candidate.vibe.brightness - target.brightness) * 0.17
                    + abs(candidate.vibe.dynamics - target.dynamics) * 0.15
                let moodFit = candidate.hasAnalyzedVibe ? max(0, 1 - distance) : 0.5
                let flowFit: Double
                if let previous, previous.hasAnalyzedVibe && candidate.hasAnalyzedVibe {
                    flowFit = 1 - DailyMixEngine.vibeDistance(candidate.vibe, previous.vibe, duration: candidate.duration)
                } else { flowFit = 0.5 }
                let familiarity: Double
                switch vibe {
                case .favorites: familiarity = candidate.isFavorite ? 0.1 : (candidate.isUnheard ? 0 : 0.04)
                case .discover: familiarity = candidate.isUnheard ? 0.06 : 0
                case .rediscover: familiarity = candidate.isRediscovery ? 0.06 : 0
                case .forYou: familiarity = 0
                }
                let repeatingArtist = previous.map { artist($0) == artist(candidate) } == true
                let score = moodFit * 0.48 + candidate.taste * 0.32
                    + flowFit * 0.10 + candidate.contextAffinity * 0.04 + candidate.sessionAffinity * 0.12
                    + familiarity - candidate.recentRejection * 0.65 - candidate.fatiguePenalty * 0.6
                    - (oldUpcoming.contains(candidate.id) ? 0.16 : 0)
                    - (repeatingArtist ? 0.1 : 0) - Double(artists[artist(candidate), default: 0]) * 0.045
                    + noise(candidate.id, step: selected.count) * 0.045
                return (candidate, score)
            }.sorted { abs($0.1 - $1.1) > 0.000001 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            guard let best = ranked.first?.0 else { break }
            selected.append(best)
            artists[artist(best), default: 0] += 1
            pool.removeAll { $0.id == best.id }
        }
        return selected.map(\.id)
    }
}
