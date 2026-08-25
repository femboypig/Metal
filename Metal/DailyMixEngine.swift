//
//  DailyMixEngine.swift
//  Metal
//

import Foundation

struct DailyMixCandidate: Equatable {
    let id: String
    let artist: String
    let affinity: Double
    let playStarts: Int
    let skips: Int
    let lastPlayedAt: TimeInterval?
}

enum DailyMixEngine {
    // Test cadence requested for the current build. Change this to 86_400 when
    // the feature graduates from minute-by-minute testing to a real daily mix.
    static let refreshInterval: TimeInterval = 60
    static let maximumTrackCount = 30

    static func bucket(for date: Date = Date()) -> Int64 {
        Int64(floor(date.timeIntervalSince1970 / refreshInterval))
    }

    static func select(
        from candidates: [DailyMixCandidate],
        bucket: Int64,
        now: TimeInterval,
        limit: Int = maximumTrackCount
    ) -> [String] {
        guard limit > 0, !candidates.isEmpty else { return [] }

        let ranked = candidates.map { candidate in
            let starts = max(0, candidate.playStarts)
            let skipRate = starts == 0
                ? 0
                : min(1, Double(max(0, candidate.skips)) / Double(starts))
            let discoveryBonus = starts == 0 ? 18.0 : 0
            let jitter = stableUnitValue(for: "\(bucket)|\(candidate.id)") * 24

            var recencyAdjustment = 0.0
            if let lastPlayedAt = candidate.lastPlayedAt {
                let minutesSincePlay = max(0, now - lastPlayedAt) / 60
                if minutesSincePlay < 5 {
                    recencyAdjustment = -30
                } else if minutesSincePlay < 60 {
                    recencyAdjustment = -14 * (1 - minutesSincePlay / 60)
                } else if minutesSincePlay > 14 * 24 * 60 {
                    recencyAdjustment = min(8, minutesSincePlay / (14 * 24 * 60))
                }
            }

            return RankedCandidate(
                candidate: candidate,
                score: candidate.affinity
                    + discoveryBonus
                    + jitter
                    + recencyAdjustment
                    - skipRate * 12
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.000_001 {
                return $0.score > $1.score
            }
            return $0.candidate.id < $1.candidate.id
        }

        let desiredCount = min(limit, ranked.count)
        let perArtistLimit = ranked.count >= 10 ? 2 : desiredCount
        var artistCounts: [String: Int] = [:]
        var selected: [RankedCandidate] = []
        var selectedIDs: Set<String> = []

        // First pass keeps the mix varied instead of allowing one heavily
        // played artist to consume the whole playlist.
        for rankedCandidate in ranked {
            let artistKey = normalizedArtistKey(for: rankedCandidate.candidate)
            guard artistCounts[artistKey, default: 0] < perArtistLimit else { continue }

            selected.append(rankedCandidate)
            selectedIDs.insert(rankedCandidate.candidate.id)
            artistCounts[artistKey, default: 0] += 1
            if selected.count == desiredCount { break }
        }

        // Small or single-artist libraries still get a full mix.
        if selected.count < desiredCount {
            for rankedCandidate in ranked where !selectedIDs.contains(rankedCandidate.candidate.id) {
                selected.append(rankedCandidate)
                if selected.count == desiredCount { break }
            }
        }

        return selected.map { $0.candidate.id }
    }

    private struct RankedCandidate {
        let candidate: DailyMixCandidate
        let score: Double
    }

    private static func normalizedArtistKey(for candidate: DailyMixCandidate) -> String {
        let artist = candidate.artist
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if artist.isEmpty || artist == "unknown artist" {
            return "unknown:\(candidate.id)"
        }
        return artist
    }

    private static func stableUnitValue(for value: String) -> Double {
        // Swift's Hasher is intentionally randomized between launches. FNV-1a
        // keeps the same mix for every process during one refresh bucket.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let mantissa = hash & 0x001f_ffff_ffff_ffff
        return Double(mantissa) / Double(0x001f_ffff_ffff_ffff as UInt64)
    }
}
