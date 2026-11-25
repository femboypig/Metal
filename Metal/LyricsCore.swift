import Foundation
import CryptoKit

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
    var sourceAttributions: [String]?
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
    var searchArtist: String {
        if Self.normalized(artist) == "unknown artist", title.contains(" - ") { return title.components(separatedBy: " - ")[0] }
        return artist
    }
    var searchTitle: String {
        var value = Self.normalized(artist) == "unknown artist" && title.contains(" - ") ? title.components(separatedBy: " - ").dropFirst().joined(separator: " - ") : title
        if Self.normalized(artist) != "unknown artist" {
            for separator in [" - ", " – ", " — "] {
                let parts = value.components(separatedBy: separator)
                guard parts.count > 1 else { continue }
                if Self.normalized(parts[0]) == Self.normalized(artist) { value = parts.dropFirst().joined(separator: separator); break }
                if Self.normalized(parts.last!) == Self.normalized(artist) { value = parts.dropLast().joined(separator: separator); break }
            }
        }
        return value.replacingOccurrences(of: #"(?i)\s*[\[(](?:official audio|official video|lyric video|lyrics|hd|hq)[\])]\s*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }
    var altered: Bool { searchTitle.range(of: #"(?i)\b(?:slowed|sped[ -]+up|remix|instrumental|edit|nightcore|reverb|speed[ -]+up|unofficial)\b"#, options: .regularExpression) != nil }
    var lookupTitle: String {
        guard altered else { return searchTitle }
        let pattern = #"(?i)\s*[\[(].*(?:slowed|sped up|remix|instrumental|edit|nightcore|reverb|speed up|unofficial).*?[\])]"#
        let base = searchTitle.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return base.replacingOccurrences(of: #"(?i)\s*[-–]?\s*(?:slowed|sped up|remix|instrumental|edit|nightcore|reverb|speed up|unofficial).*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }
    static func normalized(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") }
}
struct LyricsCandidate: Codable {
    var id: Int; var trackName: String; var artistName: String; var albumName: String?; var duration: Double
    var instrumental: Bool; var plainLyrics: String?; var syncedLyrics: String?
    var providerID: String?; var nativeDocument: LyricsDocument?
    var key: String { nativeDocument?.resultKey ?? "\(providerID ?? "LRCLIB"):\(id):\(nativeDocument?.format ?? "lrc")" }
    static func artists(_ text: String) -> Set<String> { Set(text.components(separatedBy: CharacterSet(charactersIn: ",&、")).map { LyricsQuery.normalized($0) }.filter { !$0.isEmpty }) }
    func matchesMetadata(_ q: LyricsQuery) -> Bool {
        [LyricsQuery.normalized(q.title), LyricsQuery.normalized(q.searchTitle), LyricsQuery.normalized(q.lookupTitle)].contains(LyricsQuery.normalized(trackName)) && Self.artists(artistName) == Self.artists(q.searchArtist)
    }
    func score(_ q: LyricsQuery) -> Double {
        guard matchesMetadata(q) else { return 0 }
        let knownDuration = duration.isFinite && q.duration.isFinite && duration > 0 && q.duration > 0
        return 100 - (q.altered || !knownDuration ? 0 : min(90, abs(duration - q.duration) * 4)) + (LyricsQuery.normalized(albumName ?? "") == LyricsQuery.normalized(q.album) && !q.album.isEmpty ? 10 : 0)
    }
    func document(_ q: LyricsQuery) -> LyricsDocument {
        let safe = !q.altered && matchesMetadata(q) && duration > 0 && q.duration > 0 && abs(duration - q.duration) <= 2
        var doc = nativeDocument ?? LyricsFormats.parse(syncedLyrics ?? plainLyrics ?? "", format: "lrc", source: "\(providerID ?? "LRCLIB") #\(id)")
        doc.resultKey = key
        doc.provenance = LyricsProvenance(provider: providerID ?? "LRCLIB", identifier: String(id), title: trackName, artist: artistName, album: albumName, duration: duration)
        if doc.attribution == nil { doc.attribution = providerID == "AMLL" ? "https://github.com/amll-dev/amll-ttml-db" : "https://lrclib.net" }
        if !safe { doc.timingTrusted = false }
        doc.instrumental = instrumental
        return doc
    }
}
struct LyricsHTTPError: Error { var retryAfter: Double }
protocol LyricsProvider { func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] }
struct LRCLIBProvider: LyricsProvider {
    var session: URLSession = .shared
    // Missing durations occur in real LRCLIB search results. A single incomplete
    // record must not invalidate every other lyric in the response.
    private struct Record: Decodable {
        var id: Int; var trackName: String; var artistName: String; var albumName: String?
        var duration: Double?; var instrumental: Bool?; var plainLyrics: String?; var syncedLyrics: String?
    }
    private struct SearchRecord: Decodable {
        var value: Record?
        init(from decoder: Decoder) throws { value = try? Record(from: decoder) }
    }
    static func candidates(_ data: Data) throws -> [LyricsCandidate] {
        let records = try JSONDecoder().decode([SearchRecord].self, from: data)
        guard records.isEmpty || records.contains(where: { $0.value != nil }) else { throw URLError(.cannotParseResponse) }
        return records.compactMap { item in
            guard let record = item.value, !record.trackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  record.instrumental == true || !(record.syncedLyrics ?? "").isEmpty || !(record.plainLyrics ?? "").isEmpty else { return nil }
            return LyricsCandidate(id: record.id, trackName: record.trackName, artistName: record.artistName,
                albumName: record.albumName, duration: record.duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 0,
                instrumental: record.instrumental ?? false, plainLyrics: record.plainLyrics,
                syncedLyrics: record.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? record.syncedLyrics : nil)
        }
    }
    func search(_ q: LyricsQuery) async throws -> [LyricsCandidate] {
        var results: [LyricsCandidate] = [], searched: Set<String> = []
        for (title, album) in [(q.title, q.album), (q.searchTitle, ""), (q.lookupTitle, "")] {
            guard searched.insert(title + "\n" + album).inserted else { continue }
            let found = try await request(q, title: title, album: album)
            let existing = Set(results.map(\.key))
            results += found.filter { !existing.contains($0.key) }
            if found.contains(where: { $0.matchesMetadata(q) }) { break }
        }
        return results.sorted { LyricsCandidateMatcher.score($0, q) > LyricsCandidateMatcher.score($1, q) }
    }
    private func request(_ q: LyricsQuery, title: String, album: String) async throws -> [LyricsCandidate] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: q.searchArtist)]
        if !album.isEmpty { components.queryItems?.append(URLQueryItem(name: "album_name", value: album)) }
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("Metal v1.0 (https://github.com/femboypig/Metal)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw LyricsHTTPError(retryAfter: max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60)) }
        return try Self.candidates(data).sorted { $0.score(q) > $1.score(q) }
    }
}
actor LyricsStore {
    struct Entry: Codable { var cached: LyricsDocument?; var imported: LyricsDocument?; var checked: Date?; var adjustment: Double = 0; var results: [String: LyricsDocument]?; var selected: String?; var offsets: [String: Double]?; var lookupSignature: String? }
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
    func cache(_ doc: LyricsDocument?, id: String, lookupSignature: String? = nil) throws { var entry = read(id); entry.cached = doc; if let doc, let key = doc.resultKey { if entry.results == nil { entry.results = [:] }; entry.results?[key] = doc }; entry.checked = Date(); entry.lookupSignature = lookupSignature; try write(entry, id: id) }
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

// Exact normalized payload identity includes native word windows.
// Different recordings or timing precision must never be collapsed into one result.
enum LyricsResultIdentity {
    static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func content(_ doc: LyricsDocument) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let lines = (try? encoder.encode(doc.lines)) ?? Data()
        return digest(String(decoding: lines, as: UTF8.self) + "|\(doc.offset)|\(doc.instrumental)")
    }
    static func deduplicate(_ candidates: [LyricsCandidate], query: LyricsQuery, preferredKey: String? = nil) -> [LyricsCandidate] {
        var results: [LyricsCandidate] = [], positions: [String: [Int]] = [:]
        for candidate in candidates {
            let doc = candidate.document(query)
            let identity = [LyricsQuery.normalized(candidate.trackName), LyricsCandidate.artists(candidate.artistName).sorted().joined(separator: ","), content(doc)].joined(separator: "|")
            // Missing metadata is not a different lyric payload; conflicting known
            // recording durations still remain independent selectable results.
            if let index = positions[identity]?.first(where: {
                candidate.duration <= 0 || results[$0].duration <= 0 || abs(candidate.duration - results[$0].duration) <= 2
            }) {
                let old = results[index]
                var winner = candidate.key == preferredKey ? candidate : old
                var merged = winner.document(query)
                merged.sourceAttributions = Array(Set((old.document(query).sourceAttributions ?? [old.document(query).attribution ?? old.providerID ?? "LRCLIB"]) + (doc.sourceAttributions ?? [doc.attribution ?? candidate.providerID ?? "LRCLIB"]))).sorted()
                merged.attribution = merged.sourceAttributions?.joined(separator: " · ")
                winner.nativeDocument = merged; results[index] = winner
            } else {
                positions[identity, default: []].append(results.count); results.append(candidate)
            }
        }
        return results
    }
}
