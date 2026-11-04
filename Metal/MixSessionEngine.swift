import Foundation

/// Generates the next part of a listening session without restarting its queue.
enum MixSessionEngine {
    static let batchSize = 10
    static let retainedHistoryCount = 64

    static func nextTracks(
        from candidates: [DailyMixCandidate],
        seedTrackID: String?,
        previousTrackID: String?,
        recentTrackIDs: [String],
        reservedTrackIDs: Set<String>,
        randomSeed: UInt64,
        limit: Int = batchSize
    ) -> [String] {
        guard limit > 0 else { return [] }
        let byID = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var pool = candidates.filter {
            !reservedTrackIDs.contains($0.id) && $0.recentRejection < 0.7 && $0.fatiguePenalty < 0.6
        }
        guard !pool.isEmpty else { return [] }

        let seed = seedTrackID.flatMap { byID[$0] }
        let previous = previousTrackID.flatMap { byID[$0] }
        let theme = seed ?? previous
        if let theme, theme.hasAnalyzedVibe {
            let compatible = pool.filter {
                !$0.hasAnalyzedVibe || DailyMixEngine.vibeDistance($0.vibe, theme.vibe, duration: $0.duration) < 0.32
            }
            // A rested matching song is preferable to an unheard song with a
            // completely different sound. Unknown profiles remain discoverable.
            if !compatible.isEmpty { pool = compatible }
        }
        let recent = Set(recentTrackIDs)
        let unheardThisSession = pool.filter { !recent.contains($0.id) }
        if !unheardThisSession.isEmpty {
            pool = unheardThisSession
        } else {
            let cooldownCount = min(6, max(1, pool.count / 2))
            let cooldown = Set(recentTrackIDs.suffix(cooldownCount))
            let rested = pool.filter { !cooldown.contains($0.id) }
            if !rested.isEmpty { pool = rested }
        }

        let recentPositions = Dictionary(recentTrackIDs.enumerated().map { ($0.element, $0.offset) },
                                         uniquingKeysWith: { _, latest in latest })
        let desiredCount = min(limit, pool.count)
        var selected: [DailyMixCandidate] = []
        var artistCounts: [String: Int] = [:]

        while selected.count < desiredCount && !pool.isEmpty {
            let last = selected.last ?? previous
            let ranked = pool.map { candidate -> (candidate: DailyMixCandidate, score: Double) in
                let seedFit: Double
                if let theme, candidate.hasAnalyzedVibe && theme.hasAnalyzedVibe {
                    seedFit = 1 - DailyMixEngine.vibeDistance(candidate.vibe, theme.vibe, duration: candidate.duration)
                } else if let theme, artistKey(candidate) == artistKey(theme), !candidate.artist.isEmpty,
                          candidate.artist.lowercased() != "unknown artist" {
                    seedFit = 0.75
                } else {
                    seedFit = 0.45
                }
                let flowFit: Double
                if let last, candidate.hasAnalyzedVibe && last.hasAnalyzedVibe {
                    flowFit = 1 - DailyMixEngine.vibeDistance(candidate.vibe, last.vibe, duration: candidate.duration)
                } else { flowFit = 0.45 }
                let exposure = recentPositions[candidate.id].map {
                    Double($0 + 1) / Double(max(1, recentTrackIDs.count))
                } ?? 0
                let repeatedArtist = last.map { artistKey($0) == artistKey(candidate) } == true
                let score = seedFit * 0.52 + flowFit * 0.16
                    + candidate.taste * 0.18 + candidate.contextAffinity * 0.06
                    + candidate.sessionAffinity * 0.22
                    - candidate.recentRejection * 0.55 - candidate.fatiguePenalty * 0.6
                    - exposure * 0.20 - (repeatedArtist ? 0.10 : 0)
                    + unit(seed: randomSeed, key: "pick|\(candidate.id)") * 0.10
                return (candidate, score)
            }.sorted {
                if abs($0.score - $1.score) > 0.000_001 { return $0.score > $1.score }
                return $0.candidate.id < $1.candidate.id
            }
            guard let best = ranked.first else { break }
            let artistLimit = candidates.count >= 10 ? 2 : desiredCount
            let diverse = ranked.filter { artistCounts[artistKey($0.candidate), default: 0] < artistLimit }
            let viable = diverse.isEmpty ? ranked : diverse
            let bestViable = viable.first ?? best
            let shortlist = viable.filter { $0.score >= bestViable.score - 0.12 }.prefix(4)
            let picked = shortlist.max {
                let left = unit(seed: randomSeed, key: "flow|\(selected.count)|\($0.candidate.id)")
                let right = unit(seed: randomSeed, key: "flow|\(selected.count)|\($1.candidate.id)")
                return $0.score - log(-log(left)) * 0.035 < $1.score - log(-log(right)) * 0.035
            }?.candidate ?? best.candidate
            selected.append(picked)
            artistCounts[artistKey(picked), default: 0] += 1
            pool.removeAll { $0.id == picked.id }
        }
        return selected.map(\.id)
    }

    private static func artistKey(_ candidate: DailyMixCandidate) -> String {
        let artist = candidate.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return artist.isEmpty || artist == "unknown artist" ? "unknown:\(candidate.id)" : artist
    }

    private static func unit(seed: UInt64, key: String) -> Double {
        var hash = seed ^ 0xcbf29ce484222325
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        hash = (hash ^ (hash >> 30)) &* 0xbf58476d1ce4e5b9
        hash = (hash ^ (hash >> 27)) &* 0x94d049bb133111eb
        hash ^= hash >> 31
        return min(0.999_999, max(0.000_001, Double(hash >> 11) / 9_007_199_254_740_992))
    }
}

/// The queue is independent of the current search/filter and can include repeated
/// filenames in its played history. Preserve the selected occurrence on restore.
struct PlaybackQueueSnapshot: Codable {
    let trackIDs: [String]
    let source: String
    let context: String
    let seedTrackID: String?
    let currentIndex: Int?

    func restored(availableIDs: Set<String>, currentTrackID: String?) -> (ids: [String], index: Int?) {
        let retained = trackIDs.enumerated().filter { availableIDs.contains($0.element) }
        let ids = retained.map(\.element)
        if let currentIndex,
           let index = retained.firstIndex(where: {
               $0.offset == currentIndex && (currentTrackID == nil || $0.element == currentTrackID)
           }) {
            return (ids, index)
        }
        return (ids, currentTrackID.flatMap { id in ids.lastIndex(of: id) })
    }
}
