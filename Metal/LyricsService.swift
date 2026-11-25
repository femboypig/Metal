import Foundation
import AVFoundation
import CryptoKit

actor LyricsService {
    static let shared = LyricsService()
    let store = LyricsStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MetalLyrics"))
    let provider: any LyricsProvider = LRCLIBProvider()
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
        return try await provider.search(query)
    }
    func choose(_ candidate: LyricsCandidate, query: LyricsQuery, id: String) async {
        var entry = await store.read(id)
        entry.cached = candidate.document(query); entry.checked = Date()
        try? await store.write(entry, id: id)
    }
    func load(url: URL, query: LyricsQuery, force: Bool = false) async -> (String, LyricsDocument?) {
        guard let id = try? Self.identity(url) else { return ("", nil) }
        let entry = await store.read(id)
        if var doc = entry.imported ?? entry.cached, !force || entry.imported != nil { doc.offset += entry.adjustment; return (id, doc) }
        if !force, let date = entry.checked, Date().timeIntervalSince(date) < 86400 { return (id, nil) }
        if let task = requests[id] { return (id, await task.value) }
        let task = Task<LyricsDocument?, Never> {
            let asset = AVURLAsset(url: url)
            let metadata = asset.metadata
            var q = query
            for item in metadata {
                if item.commonKey == .commonKeyAlbumName, let value = item.stringValue { q.album = value }
                if item.identifier?.rawValue.lowercased().contains("lyrics") == true,
                   let value = item.stringValue, !value.isEmpty {
                    var doc = LyricsParser.parse(value, source: "Embedded")
                    var updated = entry; updated.cached = doc; try? await self.store.write(updated, id: id)
                    doc.offset += entry.adjustment; return doc
                }
            }
            guard Date() >= self.retryAfter else { return nil }
            do {
                let results = try await self.provider.search(q)
                var updated = entry; updated.checked = Date()
                if let best = results.first, best.score(q) >= 80 { updated.cached = best.document(q) }
                try? await self.store.write(updated, id: id)
                var doc = updated.cached; doc?.offset += entry.adjustment; return doc
            } catch { self.retryAfter = Date().addingTimeInterval((error as? LyricsHTTPError)?.retryAfter ?? 60); return entry.cached }
        }
        requests[id] = task
        let result = await task.value; requests[id] = nil
        return (id, result)
    }
    func imported(_ doc: LyricsDocument?, id: String) async { var entry = await store.read(id); entry.imported = doc; try? await store.write(entry, id: id) }
    func adjust(_ seconds: Double, id: String) async { var entry = await store.read(id); entry.adjustment = seconds; try? await store.write(entry, id: id) }
}
