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
        print("Daily Mix behavioral checks passed")
    }
}
