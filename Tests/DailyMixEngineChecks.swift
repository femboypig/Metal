import Foundation

@main
enum DailyMixEngineChecks {
    static func main() {
        let calm = AudioVibeProfile(bpm: 80, energy: 0.15, brightness: 0.2, dynamics: 0.4)
        let loud = AudioVibeProfile(bpm: 145, energy: 0.95, brightness: 0.9, dynamics: 0.8)
        let candidates = (0..<40).map { index in
            DailyMixCandidate(id: "song-\(index)", artist: "artist-\(index)", duration: 180,
                taste: 0.5, isUnheard: false, lastPlayedAt: nil,
                vibe: index < 20 ? calm : loud,
                contextAffinity: index < 20 ? 0.95 : 0.05)
        }
        let now = 1_800_000_000.0
        func mix(_ pool: [DailyMixCandidate], limit: Int = 12) -> [String] {
            DailyMixEngine.select(from: pool, dayKey: 20260905, now: now, limit: limit)
        }
        let result = mix(candidates)
        precondition(result.count == 12 && Set(result).count == 12)
        precondition(result.allSatisfy { Int($0.dropFirst(5))! < 20 }, "Context must select the calm cluster")
        var evening = candidates
        for index in evening.indices { evening[index].contextAffinity = index < 20 ? 0.05 : 0.95 }
        precondition(mix(evening).allSatisfy { Int($0.dropFirst(5))! >= 20 }, "Changed preferences must change the cluster")
        var rejected = candidates
        rejected[0].recentRejection = 1
        precondition(!mix(rejected).contains("song-0"))
        precondition(mix(candidates) == result, "Same input must be deterministic")
        precondition(mix(candidates, limit: 1).count == 1)
        precondition(mix(candidates, limit: 0).isEmpty)
        precondition(mix([]).isEmpty)
        precondition(mix(Array(candidates.prefix(1))).count == 1)
        precondition(mix(Array(candidates.prefix(10)), limit: 30).count < 10)
        var sessionShift = candidates
        for index in sessionShift.indices {
            sessionShift[index].contextAffinity = 0.5
            sessionShift[index].sessionAffinity = index < 20 ? -0.8 : 0.8
        }
        precondition(mix(sessionShift).allSatisfy { Int($0.dropFirst(5))! >= 20 },
            "Current-session reactions must change the direction")
        var remixed = candidates
        for index in remixed.indices { remixed[index].remixPenalty = index < 20 ? 1 : 0 }
        precondition(mix(remixed) != result, "Remix must change the selection")
        checkRepeatedRemixes(candidates: candidates, now: now)
        print("Daily Mix behavioral checks passed")
    }

    static func checkRepeatedRemixes(candidates: [DailyMixCandidate], now: TimeInterval) {
        let day: Int64 = 20261104
        var history = [DailyMixEngine.select(from: candidates, dayKey: day, now: now, limit: 12)]
        var orders = Set<[String]>()
        var openings = Set<[String]>()
        for revision in 0..<16 {
            let context = DailyMixRemixContext(seed: UInt64(revision) &* 0x9e3779b97f4a7c15,
                recentMixes: Array(history.suffix(8)))
            let next = DailyMixEngine.select(from: candidates, dayKey: day, now: now, limit: 12, remix: context)
            precondition(next.count == 12 && Set(next).count == 12)
            precondition(!context.recentMixes.contains(next), "Remixes must not cycle through recent orders")
            precondition(next.allSatisfy { Int($0.dropFirst(5))! < 20 },
                "Variation must preserve strong taste/context preferences")
            let replay = DailyMixEngine.select(from: candidates, dayKey: day, now: now, limit: 12, remix: context)
            precondition(next == replay, "A seed and history must reproduce the same remix")
            orders.insert(next)
            openings.insert(Array(next.prefix(5)))
            history.append(next)
        }
        precondition(orders.count == 16 && openings.count >= 12,
            "Repeated shakes must vary the opening as well as the tail")
        precondition(Set(history.compactMap(\.first)).count >= 4,
            "The same anchor must not dominate every remix")

        // Real libraries often have one favorite far above the rest. It must
        // not force exactly the same path after every gesture.
        var dominant = candidates
        dominant = dominant.map { candidate in
            DailyMixCandidate(id: candidate.id, artist: candidate.artist, duration: candidate.duration,
                taste: candidate.id == "song-0" ? 1 : 0.35, isUnheard: false, lastPlayedAt: nil,
                vibe: candidate.vibe, contextAffinity: 0.5)
        }
        var recent = [[String]]()
        for revision in 0..<12 {
            let context = DailyMixRemixContext(seed: UInt64(revision + 100), recentMixes: Array(recent.suffix(8)))
            let next = DailyMixEngine.select(from: dominant, dayKey: day, now: now, limit: 12, remix: context)
            precondition(!recent.suffix(8).contains(next), "A dominant favorite must not cause a two-mix loop")
            recent.append(next)
        }

        var safe = candidates
        safe[0].recentRejection = 1
        safe[2].fatiguePenalty = 1
        let pinned = DailyMixRemixContext(seed: 123, recentMixes: history, excludedTrackID: "song-1")
        let next = DailyMixEngine.select(from: safe, dayKey: day, now: now, limit: 11, remix: pinned)
        precondition(next.count == 11 && !next.contains("song-1"), "The playing track is pinned by the caller")
        precondition(!next.contains("song-0") && !next.contains("song-2"), "Novelty must respect rejection and fatigue")

        let tiny = Array(candidates.prefix(2))
        var tinyHistory = [[String]]()
        for revision in 0..<8 {
            let context = DailyMixRemixContext(seed: UInt64(revision), recentMixes: tinyHistory)
            let next = DailyMixEngine.select(from: tiny, dayKey: day, now: now, remix: context)
            precondition(next.count == 2 && Set(next).count == 2)
            precondition(next != tinyHistory.last, "Avoid immediate repeats even when only two orders exist")
            tinyHistory.append(next)
        }
        let onlyUpcoming = DailyMixRemixContext(seed: 42, recentMixes: tinyHistory, excludedTrackID: tiny[0].id)
        precondition(DailyMixEngine.select(from: tiny, dayKey: day, now: now, remix: onlyUpcoming) == [tiny[1].id])
        precondition(DailyMixEngine.select(from: [], dayKey: day, now: now, remix: onlyUpcoming).isEmpty)
        precondition(DailyMixEngine.select(from: candidates, dayKey: day, now: now, limit: 0, remix: pinned).isEmpty)
    }

}
