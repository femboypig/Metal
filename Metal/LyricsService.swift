import Foundation
import AVFoundation
import CryptoKit

actor LyricsService {
    static let shared = LyricsService()
    let store: LyricsStore
    let provider: any LyricsProvider
    init(provider: any LyricsProvider = LyricsProviderManager(), directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MetalLyrics")) {
        self.provider = provider; self.store = LyricsStore(directory: directory)
    }
    var requests: [String: Task<LyricsDocument?, Never>] = [:]
    var retryAfter = Date.distantPast
    static func identity(_ url: URL) throws -> String {
        // Streaming content fingerprint survives a rename and does not load the audio file into RAM.
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 262144), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func identifier(url: URL) -> String { (try? Self.identity(url)) ?? "" }
    func alternatives(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        guard Date() >= retryAfter else { throw URLError(.resourceUnavailable) }
        do { return try await provider.search(query) }
        catch { retryAfter = Date().addingTimeInterval((error as? LyricsHTTPError)?.retryAfter ?? 60); throw error }
    }
    func choose(_ candidate: LyricsCandidate, query: LyricsQuery, id: String) async {
        var document = candidate.document(query)
        // Manual selection is an explicit recording confirmation for metadata-matched, unmodified audio.
        if !query.altered && candidate.score(query) > 0 { document.timingTrusted = true }
        try? await store.select(document, id: id)
    }
    func load(url: URL, query: LyricsQuery, force: Bool = false) async -> (String, LyricsDocument?) {
        guard let id = try? Self.identity(url) else { return ("", nil) }
        let entry = await store.read(id)
        if let doc = await store.resolved(id), !force || entry.imported != nil || entry.selected != nil { return (id, doc) }
        if !force, let date = entry.checked, Date().timeIntervalSince(date) < 86400 { return (id, nil) }
        if let task = requests[id] { return (id, await task.value) }
        let task = Task<LyricsDocument?, Never> {
            let asset = AVURLAsset(url: url)
            let metadata = asset.metadata + asset.availableMetadataFormats.flatMap { asset.metadata(forFormat: $0) }
            var q = query
            for item in metadata {
                if item.commonKey == .commonKeyAlbumName, let value = item.stringValue { q.album = value }
                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                if ["lyrics", "uslt", "©lyr"].contains(where: { identifier.contains($0) }),
                   let value = item.stringValue, !value.isEmpty {
                    var doc = LyricsParser.parse(value, source: "Embedded")
                    try? await self.store.cache(doc, id: id)
                    doc.offset += entry.adjustment; return doc
                }
            }
            guard Date() >= self.retryAfter else { return nil }
            do {
                let results = try await self.provider.search(q)
                let selected = results.first.flatMap { LyricsCandidateMatcher.score($0, q) >= 75 ? $0.document(q) : nil }
                try? await self.store.cache(selected, id: id)
                let latest = await self.store.read(id)
                return await self.store.resolved(id)
            } catch {
                self.retryAfter = Date().addingTimeInterval((error as? LyricsHTTPError)?.retryAfter ?? 60)
                let latest = await self.store.read(id)
                return await self.store.resolved(id)
            }
        }
        requests[id] = task
        let result = await task.value; requests[id] = nil
        return (id, result)
    }
    func automatic(id: String) async { try? await store.select(nil, id: id) }
    func imported(_ doc: LyricsDocument?, id: String) async { try? await store.install(doc, id: id) }
    func adjust(_ seconds: Double, id: String) async { try? await store.adjust(seconds, id: id) }
}
