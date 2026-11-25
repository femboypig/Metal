import Foundation

struct LyricLine: Codable, Equatable { var time: Double?; var text: String; var end: Double?; var words: [LyricWord]?; var translation: String?; var background: Bool? }
struct LyricsProvenance: Codable { var provider: String; var identifier: String; var title: String; var artist: String; var album: String?; var duration: Double }
struct LyricsDocument: Codable {
    var version = 1
    var lines: [LyricLine]
    var instrumental = false
    var source: String
    var offset: Double = 0
    var provenance: LyricsProvenance?
    var timingTrusted: Bool?
    var format: String?
    var resultKey: String?
    var attribution: String?
    var synchronizationLevel: String { !synchronized ? "Plain" : lines.contains { !($0.words?.isEmpty ?? true) } ? "Word synced" : "Line synced" }
    var synchronized: Bool { timingTrusted != false && !lines.isEmpty && lines.allSatisfy { $0.time != nil } }
    func active(at time: Double) -> Int? { LyricsSyncEngine(document: self)?.active(at: time) }

}
enum LyricsParser {
    static func parse(_ input: String, source: String) -> LyricsDocument {
        let regex = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#)
        let offsetRE = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
        var timed: [LyricLine] = [], plain: [LyricLine] = [], offset = 0.0
        var lastBatchStart = 0
        for raw in input.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            let ns = raw as NSString, range = NSRange(location: 0, length: ns.length)
            if let m = offsetRE.firstMatch(in: raw, range: range) { offset = (Double(ns.substring(with: m.range(at: 1))) ?? 0) / 1000; continue }
            let matches = regex.matches(in: raw, range: range)
            if let last = matches.last {
                lastBatchStart = timed.count
                let text = ns.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
                for m in matches {
                    let seconds = Double(ns.substring(with: m.range(at: 2))) ?? 60
                    guard seconds < 60 else { continue }
                    let fraction = m.range(at: 3).location == NSNotFound ? "" : ns.substring(with: m.range(at: 3))
                    let time = (Double(ns.substring(with: m.range(at: 1))) ?? 0) * 60 + seconds + (Double("0." + fraction) ?? 0)
                    timed.append(LyricLine(time: max(0, time), text: text))
                }
            } else if !raw.trimmingCharacters(in: .whitespaces).isEmpty && !raw.hasPrefix("[") {
                plain.append(LyricLine(time: nil, text: raw))
                if !timed.isEmpty { for index in lastBatchStart..<timed.count { timed[index].text += "\n" + raw } }
            }
        }
        timed.sort { $0.time! < $1.time! }
        var grouped: [LyricLine] = []
        for line in timed {
            if grouped.last?.time == line.time { grouped[grouped.count - 1].text += "\n" + line.text }
            else { grouped.append(line) }
        }
        return LyricsDocument(lines: timed.isEmpty ? plain : grouped, source: source, offset: -offset)
    }
}
struct LyricsQuery: Sendable {
    var title: String; var artist: String; var album: String; var duration: Double
    var altered: Bool { ["slowed", "sped up", "remix", "instrumental", "edit", "nightcore", "reverb", "speed up"].contains { title.lowercased().contains($0) } }
    var lookupTitle: String {
        guard altered else { return title }
        let pattern = #"(?i)\s*[\[(].*(?:slowed|sped up|remix|instrumental|edit|nightcore|reverb|speed up).*?[\])]"#
        let base = title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return base.replacingOccurrences(of: #"(?i)\s*[-–]?\s*(?:slowed|sped up|remix|instrumental|edit|nightcore|reverb|speed up).*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }
    static func normalized(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") }
}
struct LyricsCandidate: Codable {
    var id: Int; var trackName: String; var artistName: String; var albumName: String?; var duration: Double
    var instrumental: Bool; var plainLyrics: String?; var syncedLyrics: String?
    var providerID: String?; var nativeDocument: LyricsDocument?
    var key: String { "\(providerID ?? "LRCLIB"):\(id):\(nativeDocument?.format ?? "lrc")" }
    static func artists(_ text: String) -> Set<String> { Set(text.components(separatedBy: CharacterSet(charactersIn: ",&、")).map { LyricsQuery.normalized($0) }.filter { !$0.isEmpty }) }
    func score(_ q: LyricsQuery) -> Double {
        guard [LyricsQuery.normalized(q.title), LyricsQuery.normalized(q.lookupTitle)].contains(LyricsQuery.normalized(trackName)), Self.artists(artistName) == Self.artists(q.artist) else { return 0 }
        return 100 - (q.altered ? 0 : min(90, abs(duration - q.duration) * 4)) + (LyricsQuery.normalized(albumName ?? "") == LyricsQuery.normalized(q.album) && !q.album.isEmpty ? 10 : 0)
    }
    func document(_ q: LyricsQuery) -> LyricsDocument {
        let safe = !q.altered && score(q) > 0 && abs(duration - q.duration) <= 2
        var doc = nativeDocument ?? LyricsFormats.parse(syncedLyrics ?? plainLyrics ?? "", format: "lrc", source: "\(providerID ?? "LRCLIB") #\(id)")
        doc.resultKey = key
        doc.provenance = LyricsProvenance(provider: providerID ?? "LRCLIB", identifier: String(id), title: trackName, artist: artistName, album: albumName, duration: duration)
        doc.attribution = providerID == "AMLL" ? "https://github.com/amll-dev/amll-ttml-db" : "https://lrclib.net"
        if !safe { doc.timingTrusted = false }
        doc.instrumental = instrumental
        return doc
    }
}
struct LyricsHTTPError: Error { var retryAfter: Double }
protocol LyricsProvider { func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] }
struct LRCLIBProvider: LyricsProvider {
    func search(_ q: LyricsQuery) async throws -> [LyricsCandidate] {
        let exact = try await request(q, title: q.title, album: q.album)
        if !exact.isEmpty { return exact }
        if q.lookupTitle != q.title || !q.album.isEmpty { return try await request(q, title: q.lookupTitle, album: "") }
        return exact
    }
    private func request(_ q: LyricsQuery, title: String, album: String) async throws -> [LyricsCandidate] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: q.artist)]
        if !album.isEmpty { components.queryItems?.append(URLQueryItem(name: "album_name", value: album)) }
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("Metal v1.0 (https://github.com/femboypig/Metal)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw LyricsHTTPError(retryAfter: max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60)) }
        return try JSONDecoder().decode([LyricsCandidate].self, from: data).sorted { $0.score(q) > $1.score(q) }
    }
}
actor LyricsStore {
    struct Entry: Codable { var cached: LyricsDocument?; var imported: LyricsDocument?; var checked: Date?; var adjustment: Double = 0; var results: [String: LyricsDocument]?; var selected: String?; var offsets: [String: Double]? }
    let directory: URL
    init(directory: URL) { self.directory = directory; try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    func read(_ id: String) -> Entry {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(id + ".json")),
              var entry = try? JSONDecoder().decode(Entry.self, from: data) else { return Entry() }
        if entry.offsets == nil && entry.adjustment != 0 {
            let key = entry.imported != nil ? "imported" : entry.cached?.resultKey ?? "legacy"
            entry.offsets = [key: entry.adjustment]; entry.adjustment = 0
        }
        return entry
    }
    func cache(_ doc: LyricsDocument?, id: String) throws { var entry = read(id); entry.cached = doc; if let doc, let key = doc.resultKey { if entry.results == nil { entry.results = [:] }; entry.results?[key] = doc }; entry.checked = Date(); try write(entry, id: id) }
    func install(_ doc: LyricsDocument?, id: String) throws { var entry = read(id); entry.imported = doc; try write(entry, id: id) }
    func adjust(_ value: Double, id: String, sourceKey: String? = nil) throws { var entry = read(id); let key = sourceKey ?? entry.imported?.resultKey ?? entry.imported.map { _ in "imported" } ?? entry.selected ?? entry.cached?.resultKey ?? "legacy"
        if entry.offsets == nil { entry.offsets = [:] }; entry.offsets?[key] = value
        entry.adjustment = 0; try write(entry, id: id) }
    func select(_ doc: LyricsDocument?, id: String) throws { var entry = read(id); entry.selected = doc?.resultKey; if let doc, let key = doc.resultKey { if entry.results == nil { entry.results = [:] }; entry.results?[key] = doc }; try write(entry, id: id) }
    func resolved(_ id: String) -> LyricsDocument? {
        let entry = read(id)
        var doc = entry.imported ?? entry.selected.flatMap { entry.results?[$0] } ?? entry.cached
        let key = entry.imported != nil ? "imported" : doc?.resultKey ?? "legacy"
        doc?.offset += entry.offsets?[key] ?? entry.adjustment
        return doc
    }
    func write(_ entry: Entry, id: String) throws { try JSONEncoder().encode(entry).write(to: directory.appendingPathComponent(id + ".json"), options: .atomic) }
}

enum LyricsFollowPolicy {
    static func intentionallyMoved(_ distance: Double) -> Bool { abs(distance) >= 12 }
    static func awayFromCurrent(distance: Double, viewport: Double) -> Bool { abs(distance) > max(24, viewport * 0.25) }
}

struct LyricsSyncEngine {
    let starts: [Double]
    let ends: [Double?]
    let offset: Double
    init?(document: LyricsDocument) {
        guard document.synchronized else { return nil }
        starts = document.lines.compactMap(\.time); ends = document.lines.map(\.end); offset = document.offset
    }
    func active(at time: Double) -> Int? {
        var low = 0, high = starts.count
        while low < high {
            let mid = (low + high) / 2
            if starts[mid] + offset <= time { low = mid + 1 } else { high = mid }
        }
        guard low > 0 else { return nil }
        let index = low - 1
        if let end = ends[index], time > end + offset { return nil }
        return index
    }
}
