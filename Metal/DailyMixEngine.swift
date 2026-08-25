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
        // Real audio analysis replaces this profile as soon as it is available.
        // Grouping the fallback by artist still makes the first launch coherent.
        let artistKey = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let baseKey = artistKey.isEmpty || artistKey == "unknown artist" ? id : artistKey
        let artistEnergy = stableUnitValue(for: "energy|\(baseKey)")
        let trackVariation = stableUnitValue(for: "variation|\(id)") - 0.5

        return AudioVibeProfile(
            bpm: clamp(82 + stableUnitValue(for: "tempo|\(baseKey)") * 70 + trackVariation * 8, 70, 180),
            energy: clamp(0.22 + artistEnergy * 0.62 + trackVariation * 0.12, 0, 1),
            brightness: clamp(0.18 + stableUnitValue(for: "brightness|\(baseKey)") * 0.68, 0, 1),
            dynamics: clamp(0.2 + stableUnitValue(for: "dynamics|\(id)") * 0.65, 0, 1)
        )
    }

    static func select(
        from candidates: [DailyMixCandidate],
        dayKey: Int64,
        now: TimeInterval,
        limit: Int = maximumTrackCount
    ) -> [String] {
        guard limit > 0, !candidates.isEmpty else { return [] }

        let anchor = candidates.max { lhs, rhs in
            anchorScore(lhs, dayKey: dayKey, now: now)
                < anchorScore(rhs, dayKey: dayKey, now: now)
        } ?? candidates[0]
        let theme = dailyTheme(from: anchor.vibe, dayKey: dayKey)

        let ranked = candidates.map { candidate in
            let similarity = 1 - vibeDistance(candidate.vibe, theme, duration: candidate.duration)
            let discovery = candidate.isUnheard ? 0.10 : 0
            let jitter = stableUnitValue(for: "pick|\(dayKey)|\(candidate.id)") * 0.10
            let recentPenalty = recencyPenalty(candidate.lastPlayedAt, now: now)
            return RankedCandidate(
                candidate: candidate,
                score: similarity * 0.52
                    + clamp(candidate.taste, 0, 1) * 0.28
                    + discovery
                    + jitter
                    - recentPenalty
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.000_001 { return $0.score > $1.score }
            return $0.candidate.id < $1.candidate.id
        }

        let desiredCount = min(limit, ranked.count)
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
        let rotation = stableUnitValue(for: "anchor|\(dayKey)|\(candidate.id)") * 0.38
        let discovery = candidate.isUnheard ? 0.06 : 0
        return clamp(candidate.taste, 0, 1) * 0.56
            + rotation
            + discovery
            - recencyPenalty(candidate.lastPlayedAt, now: now) * 0.8
    }

    private static func dailyTheme(from anchor: AudioVibeProfile, dayKey: Int64) -> AudioVibeProfile {
        let energyShift = (stableUnitValue(for: "theme-energy|\(dayKey)") - 0.5) * 0.28
        let brightnessShift = (stableUnitValue(for: "theme-brightness|\(dayKey)") - 0.5) * 0.22
        let tempoShift = (stableUnitValue(for: "theme-tempo|\(dayKey)") - 0.5) * 20
        return AudioVibeProfile(
            bpm: clamp(anchor.bpm + tempoShift, 70, 180),
            energy: clamp(anchor.energy + energyShift, 0.08, 0.92),
            brightness: clamp(anchor.brightness + brightnessShift, 0.05, 0.95),
            dynamics: anchor.dynamics
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
