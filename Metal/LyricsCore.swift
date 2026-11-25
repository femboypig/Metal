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
    var onDeviceTiming: LyricsOnDeviceTiming?
    var synchronizationLevel: String {
        if !synchronized { return "Plain" }
        if onDeviceTiming != nil { return lines.allSatisfy { $0.time != nil } ? "On-device sync" : "Partial on-device sync" }
        return lines.contains { !($0.words?.isEmpty ?? true) } ? "Word synced" : "Line synced"
    }
    var synchronized: Bool {
        timingTrusted != false && !lines.isEmpty &&
            (onDeviceTiming != nil ? lines.contains { $0.time != nil } : lines.allSatisfy { $0.time != nil })
    }
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
    var cacheKey: String { [title, artist, album, String(duration)].joined(separator: "\n") }
    var hasArtist: Bool { !Self.normalized(artist).isEmpty && Self.normalized(artist) != "unknown artist" }
    private var titleParts: [String] {
        // Treat separator dashes consistently without splitting hyphenated artist names.
        title.replacingOccurrences(of: #"\s*(?:-{2,}|[–—−])\s*|\s+-\s+"#, with: "\u{001f}", options: .regularExpression)
            .components(separatedBy: "\u{001f}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    var searchArtist: String {
        if !hasArtist, titleParts.count > 1 { return titleParts[0] }
        return artist.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var searchTitle: String {
        let parts = titleParts
        var value = title
        if parts.count > 1 {
            if !hasArtist || Self.normalized(parts[0]) == Self.normalized(artist) { value = parts.dropFirst().joined(separator: " - ") }
            else if Self.normalized(parts.last!) == Self.normalized(artist) { value = parts.dropLast().joined(separator: " - ") }
        }
        return value.replacingOccurrences(of: #"(?i)\s*[\[(](?:official audio|official video|lyric video|lyrics|hd|hq)[\])]\s*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
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
        if !q.hasArtist {
            // Untagged filenames occur in both orders. Require the full artist/title
            // pair rather than assuming the first component is always the artist.
            let filenames = Set([LyricsQuery.normalized(q.title), LyricsQuery.normalized(q.searchArtist + " " + q.lookupTitle)])
            return !trackName.isEmpty && !artistName.isEmpty &&
                (filenames.contains(LyricsQuery.normalized(trackName + " " + artistName)) || filenames.contains(LyricsQuery.normalized(artistName + " " + trackName)))
        }
        return [LyricsQuery.normalized(q.title), LyricsQuery.normalized(q.searchTitle), LyricsQuery.normalized(q.lookupTitle)].contains(LyricsQuery.normalized(trackName)) && Self.artists(artistName) == Self.artists(q.searchArtist)
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
        if !safe && doc.onDeviceTiming == nil { doc.timingTrusted = false }
        doc.instrumental = instrumental
        return doc
    }
}
struct LyricsHTTPError: Error { var retryAfter: Double; var statusCode: Int? = nil }
struct LyricsProviderAttempt {
    var name: String; var resultCount: Int; var matchCount: Int
    var failed = false; var statusCode: Int?
    var summary: String {
        if failed {
            if statusCode == 401 && name == "Better Lyrics" { return "Not in public cache" }
            return statusCode == 429 ? "Try again later" : "Unavailable"
        }
        if matchCount > 0 { return "\(matchCount) matching versions" }
        return resultCount > 0 ? "No matching recording" : "No results"
    }
}

struct LyricsSearchOutcome {
    var candidates: [LyricsCandidate]
    var attempts: [LyricsProviderAttempt]
    var hasFailures: Bool { attempts.contains { $0.failed } }
}
enum LyricsProviderConfigurationError: Error { case noProviders }
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
        if !q.hasArtist {
            let term = LyricsQuery.normalized(q.searchArtist) == "unknown artist" || q.searchArtist.isEmpty ? q.lookupTitle : q.searchArtist + " " + q.lookupTitle
            return try await request(q, title: term, album: "", freeform: true)
        }
        var results: [LyricsCandidate] = [], searched: Set<String> = []
        for (title, album) in [(q.title, q.album), (q.searchTitle, ""), (q.lookupTitle, "")] {
            guard searched.insert(title + "\n" + album).inserted else { continue }
            let found = try await request(q, title: title, album: album)
            let existing = Set(results.map(\.key))
            results += found.filter { !existing.contains($0.key) }
            if found.contains(where: { $0.matchesMetadata(q) }) { break }
        }
        if !results.contains(where: { $0.matchesMetadata(q) }) {
            let found = try await request(q, title: q.searchTitle + " " + q.searchArtist, album: "", freeform: true)
            let existing = Set(results.map(\.key)); results += found.filter { !existing.contains($0.key) }
        }
        return results.sorted { LyricsCandidateMatcher.score($0, q) > LyricsCandidateMatcher.score($1, q) }
    }
    private func request(_ q: LyricsQuery, title: String, album: String, freeform: Bool = false) async throws -> [LyricsCandidate] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = freeform ? [URLQueryItem(name: "q", value: title)] : [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: q.searchArtist)]
        if !album.isEmpty { components.queryItems?.append(URLQueryItem(name: "album_name", value: album)) }
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Metal v1.0 (https://github.com/femboypig/Metal)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw LyricsHTTPError(retryAfter: max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60), statusCode: http.statusCode) }
        return try Self.candidates(data).sorted { $0.score(q) > $1.score(q) }
    }
}
struct LyricsSearchMetadata: Codable { var title: String; var artist: String }

actor LyricsStore {
    struct Entry: Codable { var cached: LyricsDocument?; var imported: LyricsDocument?; var checked: Date?; var adjustment: Double = 0; var results: [String: LyricsDocument]?; var selected: String?; var offsets: [String: Double]?; var lookupSignature: String?; var searchOverride: LyricsSearchMetadata?; var syncAttempt: LyricsSyncAttempt? }
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
    private func retainingTiming(_ incoming: LyricsDocument?, from old: LyricsDocument?) -> LyricsDocument? {
        guard let incoming, !incoming.synchronized, let old, old.onDeviceTiming != nil,
              incoming.lines.map(\.text) == old.lines.map(\.text) else { return incoming }
        return old
    }
    func cache(_ doc: LyricsDocument?, id: String, lookupSignature: String? = nil) throws {
        var entry = read(id)
        let existing = (doc?.resultKey).flatMap { entry.results?[$0] }
        let value = retainingTiming(doc, from: existing)
        entry.cached = value
        if let value, let key = value.resultKey { if entry.results == nil { entry.results = [:] }; entry.results?[key] = value }
        entry.checked = Date(); entry.lookupSignature = lookupSignature; try write(entry, id: id)
    }
    func syncAttempt(_ fingerprint: String?, id: String) throws {
        var entry = read(id)
        entry.syncAttempt = fingerprint.map { LyricsSyncAttempt(fingerprint: $0, date: Date()) }
        try write(entry, id: id)
    }
    func saveOnDeviceTiming(_ proposed: LyricsDocument, id: String, sourceKey: String, fingerprint: String) throws -> Bool {
        var entry = read(id)
        guard let base = entry.imported ?? entry.selected.flatMap({ entry.results?[$0] }) ?? entry.cached else { return false }
        let currentKey = entry.imported != nil ? "imported" : base.resultKey ?? "legacy"
        guard currentKey == sourceKey, LyricsAlignment.fingerprint(base) == fingerprint,
              !base.synchronized, proposed.lines.map(\.text) == base.lines.map(\.text) else { return false }
        var document = proposed
        document.offset = base.offset
        document.onDeviceTiming?.originalOffset = base.offset
        document.onDeviceTiming?.originalLines = base.lines
        document.onDeviceTiming?.originalTimingTrusted = base.timingTrusted
        if entry.imported != nil { entry.imported = document }
        else {
            if let key = document.resultKey { if entry.results == nil { entry.results = [:] }; entry.results?[key] = document }
            if entry.selected == nil || entry.cached?.resultKey == base.resultKey { entry.cached = document }
        }
        entry.syncAttempt = LyricsSyncAttempt(fingerprint: fingerprint, date: Date())
        try write(entry, id: id); return true
    }
    func removeOnDeviceTiming(id: String) throws {
        var entry = read(id)
        guard var document = entry.imported ?? entry.selected.flatMap({ entry.results?[$0] }) ?? entry.cached,
              let generated = document.onDeviceTiming else { return }
        document.lines = generated.originalLines; document.offset = generated.originalOffset
        document.timingTrusted = generated.originalTimingTrusted; document.onDeviceTiming = nil
        if entry.imported != nil { entry.imported = document }
        else {
            if let key = document.resultKey { entry.results?[key] = document }
            if entry.selected == nil || entry.cached?.resultKey == document.resultKey { entry.cached = document }
        }
        entry.syncAttempt = LyricsSyncAttempt(fingerprint: LyricsAlignment.fingerprint(document), date: Date())
        try write(entry, id: id)
    }
    func searchMetadata(_ metadata: LyricsSearchMetadata?, id: String) throws {
        var entry = read(id); entry.searchOverride = metadata; entry.checked = nil; entry.lookupSignature = nil
        try write(entry, id: id)
    }
    func install(_ doc: LyricsDocument?, id: String) throws { var entry = read(id); entry.imported = doc; try write(entry, id: id) }
    func adjust(_ value: Double, id: String, sourceKey: String? = nil) throws { var entry = read(id); let key = sourceKey ?? entry.imported?.resultKey ?? entry.imported.map { _ in "imported" } ?? entry.selected ?? entry.cached?.resultKey ?? "legacy"
        if entry.offsets == nil { entry.offsets = [:] }; entry.offsets?[key] = value
        entry.adjustment = 0; try write(entry, id: id) }
    func select(_ incoming: LyricsDocument?, id: String) throws { var entry = read(id); let doc = retainingTiming(incoming, from: (incoming?.resultKey).flatMap { entry.results?[$0] }); entry.selected = doc?.resultKey; if let doc, let key = doc.resultKey { if entry.results == nil { entry.results = [:] }; entry.results?[key] = doc }; try write(entry, id: id) }
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
    let lineIndices: [Int]
    let offset: Double
    init?(document: LyricsDocument) {
        guard document.synchronized else { return nil }
        let timed = document.lines.enumerated().filter { $0.element.time != nil }
        starts = timed.map { $0.element.time! }; ends = timed.map { $0.element.end }
        lineIndices = timed.map(\.offset); offset = document.offset
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
        return lineIndices[index]
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
