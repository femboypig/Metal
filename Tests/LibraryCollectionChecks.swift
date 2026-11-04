import Foundation

@main
enum LibraryCollectionChecks {
    static func main() {
        let now = 1_800_000_000.0
        var tap = TrackListeningTelemetry()
        tap.playStarts = 3
        tap.totalListeningSeconds = 2
        var short = TrackListeningTelemetry()
        short.playStarts = 1
        short.completedPlays = 1
        short.totalListeningSeconds = 18
        var heard = TrackListeningTelemetry()
        heard.playStarts = 1
        heard.totalListeningSeconds = 31
        var loved = TrackListeningTelemetry()
        loved.playStarts = 4
        loved.completedPlays = 3
        loved.totalListeningSeconds = 550
        loved.lastPlayedAt = now - 30 * 86_400
        var rejected = loved
        rejected.consecutiveEarlySkips = 2
        rejected.lastEarlySkipAt = now - 86_400
        var recent = loved
        recent.lastPlayedAt = now - 86_400
        func item(_ id: String, stats: TrackListeningTelemetry = TrackListeningTelemetry(),
                  favorite: Bool = false, duration: Double = 180, imported: Double = 0) -> LibraryCollectionItem {
            LibraryCollectionItem(id: id, title: id, duration: duration,
                importedAt: imported, isFavorite: favorite, listening: stats)
        }
        let items = [item("new", imported: now), item("tapped", stats: tap),
                     item("short", stats: short, duration: 20), item("heard", stats: heard),
                     item("old-favorite", stats: loved, favorite: true), item("old-loved", stats: loved),
                     item("old-rejected", stats: rejected, favorite: true),
                     item("recent-favorite", stats: recent, favorite: true), item("unheard-favorite", favorite: true)]
        let unheard = LibraryCollectionEngine.select(from: items, collection: .unheard, now: now)
        precondition(Set(unheard) == ["new", "tapped", "unheard-favorite"],
            "Brief attempts remain unplayed; completed short songs count as heard")
        let rediscovered = LibraryCollectionEngine.select(from: items, collection: .rediscover, now: now)
        precondition(rediscovered == ["old-favorite", "old-loved"],
            "Rediscovery requires positive history, meaningful listening and a cooldown")
        let imported = LibraryCollectionEngine.select(from: items, collection: .recentlyAdded, now: now)
        precondition(imported.first == "new" && imported.count == items.count)
        precondition(LibraryCollectionEngine.select(from: items, collection: .all, now: now) == items.map(\.id))
        let many = (0..<70).map { item("item-\($0)", imported: Double($0)) }
        let latest = LibraryCollectionEngine.select(from: many, collection: .recentlyAdded, now: now)
        precondition(latest.count == 50 && latest.first == "item-69" && latest.last == "item-20")
        precondition(LibraryCollectionEngine.select(from: [], collection: .rediscover, now: now).isEmpty)

        let vibe = AudioVibeProfile(bpm: 100, energy: 0.4, brightness: 0.4, dynamics: 0.4)
        func song(_ id: String, favorite: Bool = false, plays: Double = 0, taste: Double = 0.2,
                  unheard: Bool = false, rediscovery: Bool = false) -> DailyMixCandidate {
            DailyMixCandidate(id: id, artist: id, duration: 180, taste: taste,
                isUnheard: unheard, lastPlayedAt: nil, vibe: vibe,
                isFavorite: favorite, equivalentPlays: plays, isRediscovery: rediscovery)
        }
        var disliked = song("disliked", favorite: true, plays: 1, taste: 1)
        disliked.recentRejection = 1
        let songs = [song("favorite", favorite: true, plays: 12, taste: 0.8),
                     song("learned", plays: 8, taste: 0.8), song("rare", plays: 0.2, taste: 0.35),
                     song("new", unheard: true), song("forgotten", plays: 5, taste: 0.7, rediscovery: true), disliked]
        let favoriteIDs: Set<String> = ["favorite", "learned", "forgotten"]
        precondition(Set(DailyMixEngine.candidates(for: .favorites, from: songs).map(\.id)) == favoriteIDs)
        precondition(Set(DailyMixEngine.candidates(for: .discovery, from: songs).map(\.id)) == ["rare", "new"])
        precondition(DailyMixEngine.candidates(for: .rediscover, from: songs).map(\.id) == ["forgotten"])
        let favoriteMix = DailyMixEngine.select(from: songs, dayKey: 20261104, now: now, mode: .favorites)
        precondition(!favoriteMix.isEmpty && Set(favoriteMix).isSubset(of: favoriteIDs))
        precondition(DailyMixEngine.select(from: [song("new", unheard: true)], dayKey: 20261104,
            now: now, mode: .favorites).isEmpty, "Do not invent favorites in a cold-start library")
        let discovery = MixSessionEngine.nextTracks(from: songs, seedTrackID: "rare", previousTrackID: "rare",
            recentTrackIDs: [], reservedTrackIDs: ["rare"], randomSeed: 1, mode: .discovery)
        precondition(discovery == ["new"], "Continuous generation must keep the selected mode")
        let returnMix = MixSessionEngine.nextTracks(from: songs, seedTrackID: "favorite", previousTrackID: "favorite",
            recentTrackIDs: [], reservedTrackIDs: ["favorite"], randomSeed: 2, mode: .rediscover)
        precondition(returnMix == ["forgotten"])
        print("Smart library collections and daily mix mode checks passed")
    }
}
