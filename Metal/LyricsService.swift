import Foundation
import AVFoundation
import CryptoKit

enum LyricsLookupState: Equatable { case ready, missing, unavailable, unreadable }

actor LyricsService {
    static let shared = LyricsService()
    let store: LyricsStore
    let provider: any LyricsProvider
    init(provider: any LyricsProvider = LyricsProviderManager(), directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MetalLyrics")) {
        self.provider = provider; self.store = LyricsStore(directory: directory)
    }
    var revisions: [String: Int] = [:]
    var requests: [String: Task<(LyricsDocument?, LyricsLookupState), Never>] = [:]
    static func identity(_ url: URL) throws -> String {
        // Streaming content fingerprint survives a rename and does not load the audio file into RAM.
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 262144), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func identifier(url: URL) -> String { (try? Self.identity(url)) ?? "" }
    func effectiveQuery(url: URL, fallback: LyricsQuery, id: String) async -> LyricsQuery {
        var query = fallback
        let asset = AVURLAsset(url: url)
        for item in asset.commonMetadata {
            guard let value = item.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { continue }
            if item.commonKey == .commonKeyTitle { query.title = value }
            if item.commonKey == .commonKeyArtist { query.artist = value }
            if item.commonKey == .commonKeyAlbumName { query.album = value }
        }
        if query.duration <= 0 {
            let duration = CMTimeGetSeconds(asset.duration)
            if duration.isFinite && duration > 0 { query.duration = duration }
        }
        let entry = await store.read(id)
        if let override = entry.searchOverride { query.title = override.title; query.artist = override.artist; query.album = "" }
        return query
    }
    func updateSearch(_ metadata: LyricsSearchMetadata?, id: String) async {
        revisions[id, default: 0] += 1
        requests[id]?.cancel(); requests[id] = nil
        try? await store.searchMetadata(metadata, id: id)
    }
    func sourceCatalog(url: URL, query: LyricsQuery) async -> (String, LyricsQuery, [LyricsCandidate], [LyricsProviderAttempt]) {
        let id = identifier(url: url)
        let effective = await effectiveQuery(url: url, fallback: query, id: id)
        let candidates = (try? await alternatives(effective, id: id)) ?? []
        let attempts = await (provider as? LyricsProviderManager)?.report(effective) ?? []
        return (id, effective, candidates, attempts)
    }
    func alternatives(_ query: LyricsQuery, id: String? = nil) async throws -> [LyricsCandidate] {
        var cached: [LyricsCandidate] = []
        var selectedKey: String?
        if let id {
            let entry = await store.read(id)
            selectedKey = entry.selected
            cached = (entry.results ?? [:]).values.compactMap { doc in
                guard let p = doc.provenance, let sourceID = Int(p.identifier) else { return nil }
                return LyricsCandidate(id: sourceID, trackName: p.title, artistName: p.artist, albumName: p.album,
                    duration: p.duration, instrumental: doc.instrumental, plainLyrics: doc.lines.map(\.text).joined(separator: "\n"),
                    syncedLyrics: nil, providerID: p.provider, nativeDocument: doc)
            }
        }
        do {
            let online = try await provider.search(query)
            let keys = Set(online.map(\.key))
            return LyricsResultIdentity.deduplicate(online + cached.filter { !keys.contains($0.key) }, query: query, preferredKey: selectedKey)
        } catch {
            if !cached.isEmpty { return cached }; throw error
        }
    }
    func choose(_ candidate: LyricsCandidate, query: LyricsQuery, id: String) async {
        var document = candidate.document(query)
        // Manual selection is an explicit recording confirmation for metadata-matched, unmodified audio.
        let titleConfirmed = !query.hasArtist && LyricsQuery.normalized(candidate.trackName) == LyricsQuery.normalized(query.searchTitle)
        if !query.altered && (candidate.score(query) > 0 || titleConfirmed) { document.timingTrusted = true }
        try? await store.select(document, id: id)
    }
    func load(url: URL, query: LyricsQuery, force: Bool = false) async -> (String, LyricsDocument?, LyricsLookupState) {
        guard let id = try? Self.identity(url) else { return ("", nil, .unreadable) }
        let q = await effectiveQuery(url: url, fallback: query, id: id)
        let signature = "lyrics-search-v4:" + q.cacheKey
        let revision = revisions[id, default: 0]
        let entry = await store.read(id)
        if let doc = await store.resolved(id), (!doc.lines.isEmpty || doc.instrumental), !force || entry.imported != nil { return (id, doc, .ready) }
        // Ignore legacy negative entries and metadata changes. Never cache transport
        // failures as missing lyrics; only a completed lookup can create a negative entry.
        if !force, entry.lookupSignature == signature, let date = entry.checked, Date().timeIntervalSince(date) < 1800 { return (id, nil, .missing) }
        if let task = requests[id] { let result = await task.value; return (id, result.0, result.1) }
        let task = Task<(LyricsDocument?, LyricsLookupState), Never> {
            let asset = AVURLAsset(url: url)
            let metadata = asset.metadata + asset.availableMetadataFormats.flatMap { asset.metadata(forFormat: $0) }
            for item in metadata {
                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                if ["lyrics", "uslt", "©lyr"].contains(where: { identifier.contains($0) }),
                   let value = item.stringValue, !value.isEmpty {
                    var doc = LyricsParser.parse(value, source: "Embedded")
                    guard !doc.lines.isEmpty else { continue }
                    try? await self.store.cache(doc, id: id)
                    doc.offset += entry.adjustment; return (doc, .ready)
                }
            }
            do {
                let results = try await self.provider.search(q)
                guard !Task.isCancelled else { return (await self.store.resolved(id), .unavailable) }
                for candidate in results.prefix(8) { try? await self.store.cache(candidate.document(q), id: id) }
                let selected = LyricsCandidateMatcher.best(results, query: q)
                try? await self.store.cache(selected, id: id, lookupSignature: signature)
                let resolved = await self.store.resolved(id)
                return (resolved, resolved == nil ? .missing : .ready)
            } catch {
                // The manager already backs off individual failing providers. A
                // global service cooldown would suppress healthy providers on other songs.
                let resolved = await self.store.resolved(id)
                return (resolved, resolved == nil ? .unavailable : .ready)
            }
        }
        requests[id] = task
        let result = await task.value
        if revisions[id, default: 0] == revision { requests[id] = nil }
        return (id, result.0, result.1)
    }
    func automatic(id: String) async { try? await store.select(nil, id: id) }
    func imported(_ doc: LyricsDocument?, id: String) async { try? await store.install(doc, id: id) }
    func adjustment(id: String, key: String) async -> Double { let entry = await store.read(id); return entry.offsets?[key] ?? entry.adjustment }
    func adjust(_ seconds: Double, id: String, key: String? = nil) async { try? await store.adjust(seconds, id: id, sourceKey: key) }
}
