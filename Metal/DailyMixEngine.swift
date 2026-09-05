//
//  DailyMixEngine.swift
//  Metal
//

import Foundation

struct AudioVibeProfile: Codable, Equatable {
    let bpm: Double
    let energy: Double
    let brightness: Double
    let dynamics: Double
}

struct DailyMixCandidate: Equatable {
    let id: String
    let artist: String
    let duration: TimeInterval
    let taste: Double
    let isUnheard: Bool
    let lastPlayedAt: TimeInterval?
    let vibe: AudioVibeProfile
    var contextAffinity: Double = 0
    var hasAnalyzedVibe: Bool = true
    var recentRejection: Double = 0
}

enum DailyMixEngine {
    static let maximumTrackCount = 30

    static func dayKey(for date: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Int64 {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return Int64((components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0))
    }

    static func fallbackVibe(
        id: String,
        artist: String,
        duration: TimeInterval
    ) -> AudioVibeProfile {
        // Unknown audio is neutral, never a fabricated artist/filename mood.
        return AudioVibeProfile(
            bpm: 120, energy: 0.5, brightness: 0.5, dynamics: 0.5
        )
    }

    static func select(
        from candidates: [DailyMixCandidate],
        dayKey: Int64,
        now: TimeInterval,
        limit: Int = maximumTrackCount
    ) -> [String] {
        guard limit > 0, !candidates.isEmpty else { return [] }

        let eligible = candidates.filter { $0.recentRejection < 0.7 }
        let pool = eligible.isEmpty ? candidates : eligible
        let anchor = pool.max { lhs, rhs in
            anchorScore(lhs, dayKey: dayKey, now: now)
                < anchorScore(rhs, dayKey: dayKey, now: now)
        } ?? candidates[0]
        // Learn a coherent neighborhood around the strongest contextual seed,
        // rather than averaging incompatible calm/energetic listening sessions.
        let neighbors = pool.filter {
            $0.hasAnalyzedVibe && vibeDistance($0.vibe, anchor.vibe, duration: $0.duration) < 0.22
        }
        let theme = learnedTheme(neighbors, fallback: anchor.vibe)

        let ranked = pool.map { candidate in
            let similarity = candidate.hasAnalyzedVibe
                ? 1 - vibeDistance(candidate.vibe, theme, duration: candidate.duration) : 0.45
            let discovery = candidate.isUnheard ? 0.06 : 0
            let jitter = stableUnitValue(for: "pick|\(dayKey)|\(candidate.id)") * 0.035
            let recentPenalty = recencyPenalty(candidate.lastPlayedAt, now: now)
            return RankedCandidate(
                candidate: candidate,
                score: similarity * 0.48
                    + clamp(candidate.taste, 0, 1) * 0.18
                    + candidate.contextAffinity * 0.28
                    + discovery
                    + jitter
                    - recentPenalty
                    - candidate.recentRejection * 0.5
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.000_001 { return $0.score > $1.score }
            return $0.candidate.id < $1.candidate.id
        }

        // A mix is a focused session, not the whole library in another order.
        let sessionCount = pool.count <= 5 ? pool.count : max(5, Int(ceil(Double(pool.count) * 0.6)))
        let desiredCount = min(limit, sessionCount)
        if desiredCount == 1 { return [anchor.id] }
        let perArtistLimit = ranked.count >= 10 ? 2 : desiredCount
        var artistCounts = [normalizedArtistKey(for: anchor): 1]
        var selected = [anchor]
        var selectedIDs: Set<String> = [anchor.id]

        for item in ranked where !selectedIDs.contains(item.candidate.id) {
            let artistKey = normalizedArtistKey(for: item.candidate)
            guard artistCounts[artistKey, default: 0] < perArtistLimit else { continue }
            selected.append(item.candidate)
            selectedIDs.insert(item.candidate.id)
            artistCounts[artistKey, default: 0] += 1
            if selected.count == desiredCount { break }
        }

        // A small or single-artist library should still get a full session.
        if selected.count < desiredCount {
            for item in ranked where !selectedIDs.contains(item.candidate.id) {
                selected.append(item.candidate)
                selectedIDs.insert(item.candidate.id)
                if selected.count == desiredCount { break }
            }
        }

        return orderAsEnergyArc(selected, anchor: anchor, theme: theme, dayKey: dayKey)
            .map(\.id)
    }

    private struct RankedCandidate {
        let candidate: DailyMixCandidate
        let score: Double
    }

    private static func anchorScore(
        _ candidate: DailyMixCandidate,
        dayKey: Int64,
        now: TimeInterval
    ) -> Double {
        let rotation = stableUnitValue(for: "anchor|\(dayKey)|\(candidate.id)") * 0.04
        let discovery = candidate.isUnheard ? 0.02 : 0
        return clamp(candidate.taste, 0, 1) * 0.30
            + candidate.contextAffinity * 0.60
            + (candidate.hasAnalyzedVibe ? 0.10 : 0)
            + rotation
            + discovery
            - candidate.recentRejection
            - recencyPenalty(candidate.lastPlayedAt, now: now) * 0.8
    }

    private static func learnedTheme(_ candidates: [DailyMixCandidate], fallback: AudioVibeProfile) -> AudioVibeProfile {
        guard !candidates.isEmpty else { return fallback }
        let weights = candidates.map { max(0.05, $0.contextAffinity + $0.taste * 0.3) }
        let total = weights.reduce(0, +)
        func mean(_ key: KeyPath<AudioVibeProfile, Double>) -> Double {
            zip(candidates, weights).reduce(0) { $0 + $1.0.vibe[keyPath: key] * $1.1 } / total
        }
        return AudioVibeProfile(
            bpm: mean(\.bpm), energy: mean(\.energy),
            brightness: mean(\.brightness), dynamics: mean(\.dynamics)
        )
    }

    private static func vibeDistance(
        _ lhs: AudioVibeProfile,
        _ rhs: AudioVibeProfile,
        duration: TimeInterval
    ) -> Double {
        let tempo = tempoDistance(lhs.bpm, rhs.bpm)
        let energy = abs(lhs.energy - rhs.energy)
        let brightness = abs(lhs.brightness - rhs.brightness)
        let dynamics = abs(lhs.dynamics - rhs.dynamics)
        let extremeDurationPenalty = duration > 0 && (duration < 55 || duration > 720) ? 0.08 : 0
        return clamp(
            tempo * 0.38 + energy * 0.34 + brightness * 0.20 + dynamics * 0.08
                + extremeDurationPenalty,
            0,
            1
        )
    }

    private static func orderAsEnergyArc(
        _ candidates: [DailyMixCandidate],
        anchor: DailyMixCandidate,
        theme: AudioVibeProfile,
        dayKey: Int64
    ) -> [DailyMixCandidate] {
        guard candidates.count > 1 else { return candidates }
        var ordered = [anchor]
        var remaining = candidates.filter { $0.id != anchor.id }

        while !remaining.isEmpty {
            let progress = Double(ordered.count) / Double(max(1, candidates.count - 1))
            let arc = sin(progress * .pi)
            let targetEnergy = clamp(theme.energy - 0.08 + arc * 0.24, 0, 1)
            let targetTempo = clamp(theme.bpm - 5 + arc * 12, 70, 180)
            let previous = ordered[ordered.count - 1]

            let nextIndex = remaining.indices.max { lhs, rhs in
                flowScore(
                    remaining[lhs],
                    previous: previous,
                    targetEnergy: targetEnergy,
                    targetTempo: targetTempo,
                    dayKey: dayKey,
                    position: ordered.count
                ) < flowScore(
                    remaining[rhs],
                    previous: previous,
                    targetEnergy: targetEnergy,
                    targetTempo: targetTempo,
                    dayKey: dayKey,
                    position: ordered.count
                )
            } ?? remaining.startIndex
            ordered.append(remaining.remove(at: nextIndex))
        }
        return ordered
    }

    private static func flowScore(
        _ candidate: DailyMixCandidate,
        previous: DailyMixCandidate,
        targetEnergy: Double,
        targetTempo: Double,
        dayKey: Int64,
        position: Int
    ) -> Double {
        let energyFit = 1 - abs(candidate.vibe.energy - targetEnergy)
        let tempoFit = 1 - tempoDistance(candidate.vibe.bpm, targetTempo)
        let transitionTempo = 1 - tempoDistance(candidate.vibe.bpm, previous.vibe.bpm)
        let transitionTone = 1 - abs(candidate.vibe.brightness - previous.vibe.brightness)
        let tieBreak = stableUnitValue(for: "flow|\(dayKey)|\(position)|\(candidate.id)")
        return energyFit * 0.30
            + tempoFit * 0.22
            + transitionTempo * 0.22
            + transitionTone * 0.14
            + clamp(candidate.taste, 0, 1) * 0.09
            + tieBreak * 0.03
    }

    private static func tempoDistance(_ lhs: Double, _ rhs: Double) -> Double {
        let direct = abs(lhs - rhs)
        let halfTime = abs(lhs * 2 - rhs)
        let doubleTime = abs(lhs - rhs * 2)
        return clamp(min(direct, halfTime, doubleTime) / 70, 0, 1)
    }

    private static func recencyPenalty(_ lastPlayedAt: TimeInterval?, now: TimeInterval) -> Double {
        guard let lastPlayedAt else { return 0 }
        let days = max(0, now - lastPlayedAt) / 86_400
        if days < 1 { return 0.24 }
        if days < 4 { return 0.24 * (1 - (days - 1) / 3) }
        return 0
    }

    private static func normalizedArtistKey(for candidate: DailyMixCandidate) -> String {
        let artist = candidate.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return artist.isEmpty || artist == "unknown artist" ? "unknown:\(candidate.id)" : artist
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }

    private static func stableUnitValue(for value: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let mantissa = hash & 0x001f_ffff_ffff_ffff
        return Double(mantissa) / Double(0x001f_ffff_ffff_ffff as UInt64)
    }
}
