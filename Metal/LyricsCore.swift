import Foundation

struct LyricLine: Codable, Equatable { var time: Double?; var text: String }
struct LyricsDocument: Codable {
    var version = 1
    var lines: [LyricLine]
    var instrumental = false
    var source: String
    var offset: Double = 0
    var synchronized: Bool { !lines.isEmpty && lines.allSatisfy { $0.time != nil } }
    func active(at time: Double) -> Int? {
        guard synchronized else { return nil }
        var low = 0, high = lines.count
        while low < high { let mid = (low + high) / 2
            if lines[mid].time! + offset <= time { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }
}
enum LyricsParser {
    static func parse(_ input: String, source: String) -> LyricsDocument {
        let regex = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#)
        let offsetRE = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
        var timed: [LyricLine] = [], plain: [LyricLine] = [], offset = 0.0
        for raw in input.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            let ns = raw as NSString, range = NSRange(location: 0, length: ns.length)
            if let m = offsetRE.firstMatch(in: raw, range: range) { offset = (Double(ns.substring(with: m.range(at: 1))) ?? 0) / 1000; continue }
            let matches = regex.matches(in: raw, range: range)
            if let last = matches.last {
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
                if !timed.isEmpty { timed[timed.count - 1].text += "\n" + raw }
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
    static func normalized(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") }
}
struct LyricsCandidate: Codable {
    var id: Int; var trackName: String; var artistName: String; var albumName: String?; var duration: Double
    var instrumental: Bool; var plainLyrics: String?; var syncedLyrics: String?
    func score(_ q: LyricsQuery) -> Double {
        guard LyricsQuery.normalized(trackName) == LyricsQuery.normalized(q.title), LyricsQuery.normalized(artistName) == LyricsQuery.normalized(q.artist) else { return 0 }
        return 100 - min(90, abs(duration - q.duration) * 4) + (LyricsQuery.normalized(albumName ?? "") == LyricsQuery.normalized(q.album) && !q.album.isEmpty ? 10 : 0)
    }
    func document(_ q: LyricsQuery) -> LyricsDocument {
        let safe = !q.altered && abs(duration - q.duration) <= 2
        var doc = LyricsParser.parse(safe ? (syncedLyrics ?? plainLyrics ?? "") : (plainLyrics ?? syncedLyrics ?? ""), source: "LRCLIB #\(id)")
        if !safe { doc.lines = doc.lines.map { LyricLine(time: nil, text: $0.text) }; doc.offset = 0 }
        doc.instrumental = instrumental
        return doc
    }
}
struct LyricsHTTPError: Error { var retryAfter: Double }
protocol LyricsProvider { func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] }
struct LRCLIBProvider: LyricsProvider {
    func search(_ q: LyricsQuery) async throws -> [LyricsCandidate] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "track_name", value: q.title), URLQueryItem(name: "artist_name", value: q.artist)]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("Metal v1.0 (https://github.com/femboypig/Metal)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw LyricsHTTPError(retryAfter: max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60)) }
        return try JSONDecoder().decode([LyricsCandidate].self, from: data).sorted { $0.score(q) > $1.score(q) }
    }
}
actor LyricsStore {
    struct Entry: Codable { var cached: LyricsDocument?; var imported: LyricsDocument?; var checked: Date?; var adjustment: Double = 0 }
    let directory: URL
    init(directory: URL) { self.directory = directory; try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    func read(_ id: String) -> Entry { guard let data = try? Data(contentsOf: directory.appendingPathComponent(id + ".json")), let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return Entry() }; return entry }
    func write(_ entry: Entry, id: String) throws { try JSONEncoder().encode(entry).write(to: directory.appendingPathComponent(id + ".json"), options: .atomic) }
}
