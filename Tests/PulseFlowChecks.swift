import Foundation

@main
enum PulseFlowChecks {
    static func main() {
        let profiles = [
            AudioVibeProfile(bpm: 74, energy: 0.15, brightness: 0.22, dynamics: 0.22),
            AudioVibeProfile(bpm: 100, energy: 0.40, brightness: 0.42, dynamics: 0.45),
            AudioVibeProfile(bpm: 146, energy: 0.88, brightness: 0.84, dynamics: 0.88)
        ]
        var pool = (0..<36).map { index in
            DailyMixCandidate(id: "song-\(index)", artist: "artist-\(index % 9)", duration: 180,
                taste: 0.7, isUnheard: false, lastPlayedAt: 0, vibe: profiles[index / 12])
        }
        func next(_ vibe: PulseVibe, candidates: [DailyMixCandidate]? = nil, recent: [String] = [],
                  reserved: Set<String> = [], previous: [String] = [], seed: UInt64 = 20, limit: Int = 6) -> [String] {
            PulseFlowEngine.nextTracks(from: candidates ?? pool, vibe: vibe, previousTrackID: nil,
                recentTrackIDs: recent, reservedTrackIDs: reserved, previousUpcoming: previous, seed: seed, limit: limit)
        }
        func energy(_ ids: [String]) -> Double {
            ids.map { pool[Int($0.dropFirst(5))!].vibe.energy }.reduce(0, +) / Double(max(1, ids.count))
        }
        let lively = next(.discover)
        let calm = next(.rediscover)
        let warm = next(.favorites)
        precondition(lively.count == 6 && calm.count == 6 && warm.count == 6)
        precondition(energy(lively) > energy(calm) + 0.3, "Sound targets must change the selection")
        precondition(energy(lively) > energy(warm) + 0.2)
        precondition(!warm.isEmpty, "Warm must work without a hard favorites-only filter")
        precondition(next(.discover) == lively, "A seeded request should be reproducible")
        let refreshed = next(.discover, previous: lively, seed: 45)
        precondition(refreshed != lively, "Shake must rebuild upcoming songs when alternatives exist")
        precondition(Set(refreshed).count == refreshed.count)
        let reserved = Set(lively)
        precondition(Set(next(.discover, reserved: reserved)).isDisjoint(with: reserved))
        precondition(Set(next(.rediscover, recent: calm)).isDisjoint(with: Set(calm)))
        pool[0].recentRejection = 1
        pool[1].fatiguePenalty = 1
        for vibe in PulseVibe.allCases {
            let ids = next(vibe, limit: 36)
            precondition(!ids.contains("song-0") && !ids.contains("song-1"))
        }
        let disliked = DailyMixCandidate(id: "bad-fit", artist: "bad", duration: 180, taste: 0.05,
            isUnheard: false, lastPlayedAt: nil, vibe: profiles[2])
        precondition(!next(.discover, candidates: pool + [disliked], limit: 40).contains(disliked.id),
            "The requested energy must not override strong negative taste evidence")
        precondition(next(.forYou, candidates: []).isEmpty)
        precondition(next(.forYou, candidates: [pool[2]], reserved: [pool[2].id]).isEmpty)
        print("Personal vibe: mood selection, taste safeguards, queue refresh, cooldown and tiny libraries passed")
    }
}
