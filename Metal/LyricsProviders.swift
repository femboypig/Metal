import Foundation

enum LyricsProviderAvailability { case online, localOnly(String) }
protocol NamedLyricsProvider: LyricsProvider { var name: String { get }; var availability: LyricsProviderAvailability { get } }
struct AMLLProvider: NamedLyricsProvider {
    let name = "AMLL"
    var availability: LyricsProviderAvailability { .online }
    struct Item: Decodable { var id: Int; var musicNames: [String]; var artistNames: [String]; var albumNames: [String]; var lyrics: String? }
    struct Page: Decodable { struct DataPage: Decodable { var items: [Item] }; var data: DataPage }
    struct Result: Decodable { var data: Item }
    func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        var url = URLComponents(string: "https://api.amll.dev/v1/lyrics/" + path)!
        url.queryItems = query
        var request = URLRequest(url: url.url!, timeoutInterval: 15)
        request.setValue("Metal v1.0 (https://github.com/femboypig/Metal)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw LyricsHTTPError(retryAfter: 60) }
        return data
    }
    func search(_ q: LyricsQuery) async throws -> [LyricsCandidate] {
        let page = try JSONDecoder().decode(Page.self, from: await get("search", query: [URLQueryItem(name: "musicName", value: q.lookupTitle), URLQueryItem(name: "artistName", value: q.artist), URLQueryItem(name: "pageSize", value: "8")]))
        var candidates: [LyricsCandidate] = []
        for item in page.data.items.prefix(3) {
            guard item.musicNames.contains(where: { LyricsQuery.normalized($0) == LyricsQuery.normalized(q.lookupTitle) }), LyricsCandidate.artists(item.artistNames.joined(separator: ",")) == LyricsCandidate.artists(q.artist) else { continue }
            let record = try JSONDecoder().decode(Result.self, from: await get("get", query: [URLQueryItem(name: "id", value: String(item.id))]))
            guard let text = record.data.lyrics else { continue }
            var doc = LyricsFormats.parse(text, format: "ttml", source: "AMLL #\(item.id)")
            doc.attribution = "https://github.com/amll-dev/amll-ttml-db"
            candidates.append(LyricsCandidate(id: item.id, trackName: item.musicNames.first ?? q.title, artistName: item.artistNames.joined(separator: ","), albumName: item.albumNames.first, duration: 0, instrumental: false, plainLyrics: doc.lines.map(\.text).joined(separator: "\n"), syncedLyrics: nil, providerID: "AMLL", nativeDocument: doc))
        }
        return candidates
    }
}
// These adapters intentionally perform no unofficial, authenticated or encrypted requests.
// Their textual export formats are handled by LyricsFormats until a permitted API is configured.
struct NetEaseProvider: NamedLyricsProvider {
    let name = "NetEase"
    var availability: LyricsProviderAvailability { .localOnly("No authorized public lyrics API configured; import LRC/YRC exports.") }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { throw URLError(.unsupportedURL) }
}
struct KuGouProvider: NamedLyricsProvider {
    let name = "KuGou"
    var availability: LyricsProviderAvailability { .localOnly("No authorized public lyrics API configured; import plaintext LRC/KRC exports. Protected envelopes are unsupported.") }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { throw URLError(.unsupportedURL) }
}
struct QQMusicProvider: NamedLyricsProvider {
    let name = "QQ Music"
    var availability: LyricsProviderAvailability { .localOnly("No authorized public lyrics API configured; import plaintext LRC/QRC exports. Protected envelopes are unsupported.") }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { throw URLError(.unsupportedURL) }
}
actor LyricsProviderManager: LyricsProvider {
    let providers: [(String, any LyricsProvider)]
    var blockedUntil: [String: Date] = [:]
    init(providers: [(String, any LyricsProvider)] = [("LRCLIB", LRCLIBProvider()), ("AMLL", AMLLProvider())]) { self.providers = providers }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        // Two providers maximum in flight, with provider-specific backoff and partial-failure tolerance.
        let available = providers.filter { Date() >= (blockedUntil[$0.0] ?? .distantPast) }
        var results: [LyricsCandidate] = []
        var hadFailure = available.count < providers.count
        for batch in stride(from: 0, to: available.count, by: 2) {
            await withTaskGroup(of: (String, [LyricsCandidate], Double?).self) { group in
                for (name, provider) in available[batch..<min(batch + 2, available.count)] {
                    group.addTask {
                        do { return (name, try await provider.search(query), nil) }
                        catch { return (name, [], (error as? LyricsHTTPError)?.retryAfter ?? 60) }
                    }
                }
                for await (name, found, retry) in group {
                    results += found
                    if let retry { hadFailure = true; blockedUntil[name] = Date().addingTimeInterval(retry) }
                }
            }
        }
        if results.isEmpty && hadFailure { throw URLError(.resourceUnavailable) }
        return results.sorted { lhs, rhs in
            let a = LyricsCandidateMatcher.score(lhs, query), b = LyricsCandidateMatcher.score(rhs, query)
            return a == b ? lhs.key < rhs.key : a > b
        }
    }
}
enum LyricsCandidateMatcher {
    static func score(_ candidate: LyricsCandidate, _ query: LyricsQuery) -> Double {
        let base = candidate.score(query)
        guard base > 0 else { return 0 }
        // Unknown recording duration cannot beat a verified recording on word timing alone.
        if candidate.duration <= 0 { return 75 + (query.album.isEmpty ? 0 : (LyricsQuery.normalized(query.album) == LyricsQuery.normalized(candidate.albumName ?? "") ? 4 : 0)) }
        return base + (candidate.document(query).synchronized ? 2 : 0)
    }
}
