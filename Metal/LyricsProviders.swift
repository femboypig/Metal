import Foundation

struct AMLLProvider: LyricsProvider {
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
        let page = try JSONDecoder().decode(Page.self, from: await get("search", query: [URLQueryItem(name: "musicName", value: q.lookupTitle), URLQueryItem(name: "artistName", value: q.searchArtist), URLQueryItem(name: "pageSize", value: "8")]))
        var candidates: [LyricsCandidate] = []
        for item in page.data.items.prefix(3) {
            guard item.musicNames.contains(where: { LyricsQuery.normalized($0) == LyricsQuery.normalized(q.lookupTitle) }), LyricsCandidate.artists(item.artistNames.joined(separator: ",")) == LyricsCandidate.artists(q.searchArtist) else { continue }
            let record = try JSONDecoder().decode(Result.self, from: await get("get", query: [URLQueryItem(name: "id", value: String(item.id))]))
            guard let text = record.data.lyrics else { continue }
            var doc = LyricsFormats.parse(text, format: "ttml", source: "AMLL #\(item.id)")
            doc.attribution = "https://github.com/amll-dev/amll-ttml-db"
            candidates.append(LyricsCandidate(id: item.id, trackName: item.musicNames.first(where: { LyricsQuery.normalized($0) == LyricsQuery.normalized(q.lookupTitle) }) ?? q.title, artistName: item.artistNames.joined(separator: ","), albumName: item.albumNames.first, duration: 0, instrumental: false, plainLyrics: doc.lines.map(\.text).joined(separator: "\n"), syncedLyrics: nil, providerID: "AMLL", nativeDocument: doc))
        }
        return candidates
    }
}
// Public cache reads only. Fresh Better Lyrics fetches require a key reserved for
// their extension; Metal never supplies that key or retries through a private proxy.
struct BetterLyricsProvider: LyricsProvider {
    var session: URLSession = .shared
    struct Response: Decodable { var ttml: String }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        let exact = try await request(query)
        guard exact.isEmpty, query.lookupTitle != query.searchTitle else { return exact }
        var normalized = query; normalized.title = query.lookupTitle; normalized.artist = query.searchArtist
        return try await request(normalized)
    }
    private func request(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        let data = try await LyricsProviderHTTP.get("https://api.betterlyrics.org/getLyrics", items: [
            URLQueryItem(name: "s", value: query.searchTitle), URLQueryItem(name: "a", value: query.searchArtist),
            URLQueryItem(name: "al", value: query.album), URLQueryItem(name: "d", value: String(Int(max(0, query.duration).rounded())))
        ], session: session, unavailable: [401, 404])
        guard let data else { return [] }
        return try Self.candidates(data, query: query)
    }
    static func candidates(_ data: Data, query: LyricsQuery) throws -> [LyricsCandidate] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        var doc = LyricsFormats.parse(response.ttml, format: "ttml", source: "Better Lyrics")
        guard !doc.lines.isEmpty else { return [] }
        // The public response contains no recording metadata. Do not present the
        // request's duration as a verified source duration. Manual selection can confirm it.
        doc.timingTrusted = false
        doc.attribution = "https://betterlyrics.org"
        doc.resultKey = "BetterLyrics:" + LyricsResultIdentity.digest(response.ttml) + ":ttml"
        return [LyricsCandidate(id: 0, trackName: query.searchTitle, artistName: query.searchArtist,
            albumName: query.album, duration: 0, instrumental: false, plainLyrics: nil, syncedLyrics: nil,
            providerID: "Better Lyrics", nativeDocument: doc)]
    }
}

struct LiriQoProvider: LyricsProvider {
    var session: URLSession = .shared
    struct Metadata: Decodable { var title: String?; var artist: String?; var album: String?; var duration: Double? }
    struct Word: Decodable { var text: String; var start: Double; var end: Double? }
    struct Line: Decodable {
        var text: String; var start: Double?; var end: Double?; var words: [Word]?
        var isInstrumental: Bool?
    }
    struct Track: Decodable {
        var provider: String; var title: String?; var artist: String?; var album: String?; var duration: Double?
        var upstreamProvider: String?; var lyricsSource: String?; var plain: String?; var timed: [Line]?
        var nativeWordTiming: Bool?; var syncLevel: String?
    }
    struct Response: Decodable { var metadata: Metadata?; var tracks: [Track]?; var error: String? }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        let exact = try await request(query)
        guard exact.isEmpty, query.lookupTitle != query.searchTitle else { return exact }
        var normalized = query; normalized.title = query.lookupTitle; normalized.artist = query.searchArtist
        return try await request(normalized)
    }
    private func request(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        let data = try await LyricsProviderHTTP.get("https://api.liriqo-alfarrizi.my.id/v1/lyrics", items: [
            URLQueryItem(name: "title", value: query.searchTitle), URLQueryItem(name: "artist", value: query.searchArtist),
            URLQueryItem(name: "album", value: query.album), URLQueryItem(name: "duration", value: String(query.duration))
        ], session: session, unavailable: [404])
        guard let data else { return [] }
        return try Self.candidates(data, query: query)
    }
    static func candidates(_ data: Data, query: LyricsQuery) throws -> [LyricsCandidate] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.error == nil, let tracks = response.tracks else { throw URLError(.badServerResponse) }
        return tracks.compactMap { track in
            // Metadata belongs to the returned recording, never copied from the local query.
            guard let title = track.title ?? response.metadata?.title,
                  let artist = track.artist ?? response.metadata?.artist else { return nil }
            var lines: [LyricLine] = []
            for line in track.timed ?? [] {
                guard !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let start = line.start.flatMap { $0.isFinite && $0 >= 0 ? $0 / 1000 : nil }
                let end = line.end.flatMap { value in start.flatMap { value.isFinite && value / 1000 >= $0 ? value / 1000 : nil } }
                // Trust only native timing evidence; never synthesize word windows.
                let words: [LyricWord]? = track.nativeWordTiming == true ? line.words?.compactMap { word in
                    guard word.start.isFinite, word.start >= 0, !word.text.isEmpty else { return nil }
                    let end = word.end.flatMap { $0.isFinite && $0 >= word.start ? $0 / 1000 : nil }
                    return LyricWord(start: word.start / 1000, end: end, text: word.text)
                } : nil
                lines.append(LyricLine(time: start, text: line.text, end: end, words: words?.isEmpty == false ? words : nil))
            }
            if lines.isEmpty { lines = LyricsParser.parse(track.plain ?? "", source: "LiriQo").lines }
            guard !lines.isEmpty else { return nil }
            lines.sort { ($0.time ?? .greatestFiniteMagnitude) < ($1.time ?? .greatestFiniteMagnitude) }
            let source = track.upstreamProvider ?? track.provider
            var doc = LyricsDocument(lines: lines, source: "LiriQo · " + source, format: "liriqo-json")
            doc.attribution = "https://github.com/AlFarrizi-Studio/LiriQo — " + source + (track.lyricsSource.map { " / " + $0 } ?? "")
            let duration = track.duration ?? 0 // envelope duration may be only a metadata lookup, not this provider's recording
            let identity = [track.provider, title, artist, track.album ?? "", String(duration), LyricsResultIdentity.content(doc)].joined(separator: "\n")
            doc.resultKey = "LiriQo:" + LyricsResultIdentity.digest(identity) + ":json"
            return LyricsCandidate(id: 0, trackName: title, artistName: artist, albumName: track.album ?? response.metadata?.album,
                duration: duration, instrumental: false, plainLyrics: track.plain, syncedLyrics: nil,
                providerID: "LiriQo", nativeDocument: doc)
        }
    }
}

enum LyricsProviderHTTP {
    static func get(_ base: String, items: [URLQueryItem], session: URLSession, unavailable: Set<Int>) async throws -> Data? {
        try Task.checkCancellation()
        var url = URLComponents(string: base)!; url.queryItems = items
        var request = URLRequest(url: url.url!, timeoutInterval: 25)
        request.setValue("Metal v1.0 (https://github.com/femboypig/Metal)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if unavailable.contains(http.statusCode) { return nil }
        guard http.statusCode == 200 else {
            throw LyricsHTTPError(retryAfter: max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60))
        }
        guard data.count <= 8 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
        return data
    }
}

actor LyricsProviderManager: LyricsProvider {
    let providers: [(String, any LyricsProvider)]
    var blockedUntil: [String: Date] = [:]
    var requests: [String: Task<[LyricsCandidate], Error>] = [:]
    init(providers: [(String, any LyricsProvider)] = [("LRCLIB", LRCLIBProvider()), ("AMLL", AMLLProvider()), ("Better Lyrics", BetterLyricsProvider()), ("LiriQo", LiriQoProvider())]) { self.providers = providers }
    func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        try Task.checkCancellation()
        let key = [query.title, query.artist, query.album, String(query.duration)].joined(separator: "\n")
        if let task = requests[key] {
            let result = try await task.value; try Task.checkCancellation(); return result
        }
        let task = Task { try await self.performSearch(query) }
        requests[key] = task
        defer { requests[key] = nil }
        let result = try await task.value
        try Task.checkCancellation()
        return result
    }
    private func performSearch(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
        // Two providers maximum in flight, with provider-specific backoff and partial-failure tolerance.
        let online = providers
        let available = online.filter { Date() >= (blockedUntil[$0.0] ?? .distantPast) }
        var results: [LyricsCandidate] = []
        var hadFailure = available.count < online.count
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
        let sorted = results.sorted { lhs, rhs in
            let a = LyricsCandidateMatcher.score(lhs, query), b = LyricsCandidateMatcher.score(rhs, query)
            return a == b ? lhs.key < rhs.key : a > b
        }
        return LyricsResultIdentity.deduplicate(sorted, query: query)
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
