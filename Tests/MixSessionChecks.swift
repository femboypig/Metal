import Foundation

@main
enum MixSessionChecks {
    static func main() throws {
        let calm = AudioVibeProfile(bpm: 80, energy: 0.15, brightness: 0.2, dynamics: 0.4)
        let loud = AudioVibeProfile(bpm: 145, energy: 0.95, brightness: 0.9, dynamics: 0.8)
        let candidates = (0..<48).map { index in
            DailyMixCandidate(id: "song-\(index)", artist: "artist-\(index % 8)", duration: 180,
                taste: 0.5, isUnheard: false, lastPlayedAt: nil,
                vibe: index < 24 ? calm : loud)
        }
        func next(seed: String = "song-0", recent: [String] = [], reserved: Set<String> = ["song-0"],
                  pool: [DailyMixCandidate]? = nil, random: UInt64 = 123, limit: Int = 10) -> [String] {
            MixSessionEngine.nextTracks(from: pool ?? candidates, seedTrackID: seed,
                previousTrackID: seed, recentTrackIDs: recent, reservedTrackIDs: reserved,
                randomSeed: random, limit: limit)
        }
        let first = next()
        precondition(first.count == 10 && Set(first).count == 10 && !first.contains("song-0"))
        precondition(first.allSatisfy { Int($0.dropFirst(5))! < 24 }, "Seed sound must define the radio")
        precondition(next(seed: "song-24", reserved: ["song-24"]).allSatisfy { Int($0.dropFirst(5))! >= 24 })
        precondition(next() == first, "Seeded generation must be reproducible")
        precondition(next(random: 456) != first, "Fresh requests must vary the next batch")

        let reserved = Set(first + ["song-0"])
        let second = next(recent: ["song-0"], reserved: reserved)
        precondition(Set(second).isDisjoint(with: reserved), "Never duplicate a scheduled song")
        var unsafe = candidates
        unsafe[1].recentRejection = 1
        unsafe[2].fatiguePenalty = 1
        precondition(next(pool: unsafe).allSatisfy { $0 != "song-1" && $0 != "song-2" })

        let almostAll = (0..<22).map { "song-\($0)" }
        let fresh = next(recent: almostAll)
        precondition(Set(fresh) == ["song-22", "song-23"], "Do not pad fresh batches with recent repeats")
        let rested = next(recent: (0..<24).map { "song-\($0)" })
        precondition(!rested.isEmpty && rested.allSatisfy { Int($0.dropFirst(5))! < 24 },
            "Keep the requested sound when only unrelated tracks are unheard")
        precondition(Set(rested).isDisjoint(with: Set((18..<24).map { "song-\($0)" })), "Honor the recent cooldown")

        // Consume many batches: refill without looping the original queue or
        // replaying the current/scheduled tracks, including after the first lap.
        var current = "song-0"
        var history = [current]
        var upcoming = [String]()
        var heard = Set<String>([current])
        for step in 0..<100 {
            if upcoming.count <= 3 {
                let appended = next(recent: Array(history.suffix(64)), reserved: Set(upcoming + [current]), random: UInt64(step))
                precondition(Set(appended).isDisjoint(with: Set(upcoming + [current])))
                upcoming.append(contentsOf: appended)
            }
            precondition(!upcoming.isEmpty, "The session must continue past the initial batch")
            let newCurrent = upcoming.removeFirst()
            precondition(newCurrent != current, "Never immediately repeat the playing track")
            current = newCurrent
            history.append(current)
            heard.insert(current)
        }
        precondition(heard.count == 24, "Explore the compatible library rather than cycling a small template")

        let tiny = Array(candidates.prefix(2))
        precondition(next(reserved: ["song-0"], pool: tiny) == ["song-1"])
        precondition(next(seed: "song-1", recent: ["song-0", "song-1"], reserved: ["song-1"], pool: tiny) == ["song-0"])
        precondition(next(reserved: ["song-0"], pool: Array(tiny.prefix(1))).isEmpty)
        precondition(next(pool: []).isEmpty && next(limit: 0).isEmpty)
        var rejected = tiny
        for index in rejected.indices { rejected[index].recentRejection = 1 }
        precondition(next(pool: rejected).isEmpty, "Do not revive rejected songs to fill a queue")

        let snapshot = PlaybackQueueSnapshot(trackIDs: ["a", "b", "a", "c", "d"], source: "trackVibe",
            context: "VIBE · A", seedTrackID: "a", currentIndex: 2)
        let restored = snapshot.restored(availableIDs: ["a", "c", "d"], currentTrackID: "a")
        precondition(restored.ids == ["a", "a", "c", "d"] && restored.index == 1,
            "Restore the current occurrence after deleting an earlier file")
        let decoded = try JSONDecoder().decode(PlaybackQueueSnapshot.self, from: JSONEncoder().encode(snapshot))
        precondition(decoded.source == "trackVibe" && decoded.seedTrackID == "a" && decoded.currentIndex == 2)
        precondition(snapshot.restored(availableIDs: [], currentTrackID: "a").ids.isEmpty)
        precondition(snapshot.restored(availableIDs: ["b", "c"], currentTrackID: "a").index == nil)
        print("Track vibe, continuous mix and queue restoration checks passed")
    }
}
