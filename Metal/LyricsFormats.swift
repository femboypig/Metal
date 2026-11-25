import Foundation

struct LyricWord: Codable, Equatable { var start: Double; var end: Double; var text: String }
enum LyricsFormats {
    static func time(_ value: String) -> Double? {
        if value.hasSuffix("ms") { return Double(value.dropLast(2)).flatMap { $0.isFinite && $0 >= 0 ? $0 / 1000 : nil } }
        if value.hasSuffix("s") { return Double(value.dropLast()).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } }
        let parts = value.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty, parts.count <= 3, parts.allSatisfy({ $0.isFinite && $0 >= 0 }),
              parts.count == value.split(separator: ":").count else { return nil }
        if parts.count > 1 && parts.last! >= 60 { return nil }
        if parts.count == 3 && parts[1] >= 60 { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
    static func parse(_ text: String, format: String, source: String) -> LyricsDocument {
        switch format.lowercased() {
        case "ttml":
            let delegate = TTMLLyricsDelegate()
            let parser = XMLParser(data: Data(text.utf8)); parser.shouldResolveExternalEntities = false; parser.delegate = delegate
            guard parser.parse() else { return LyricsDocument(lines: [], source: source) }
            return LyricsDocument(lines: delegate.lines.sorted { ($0.time ?? 0) < ($1.time ?? 0) }, source: source, format: "ttml")
        case "yrc", "krc", "qrc":
            // Textual exports only. Protected/compressed provider envelopes are not decrypted.
            var payload = text
            if let range = text.range(of: #"LyricContent="([\s\S]*?)""#, options: .regularExpression) {
                payload = String(text[range]).dropFirst(14).dropLast().description.replacingOccurrences(of: "&#10;", with: "\n").replacingOccurrences(of: "&amp;", with: "&")
            }
            let lineRE = try! NSRegularExpression(pattern: #"^\[(\d+),(\d+)\](.*)$"#)
            let tupleRE = try! NSRegularExpression(pattern: format == "krc" ? #"<(\d+),(\d+),\d+>([^<]*)"# : (format == "yrc" ? #"\((\d+),(\d+),\d+\)([^()]*)"# : #"([^()]*)\((\d+),(\d+)\)"#))
            var lines: [LyricLine] = []
            for raw in payload.components(separatedBy: .newlines) {
                let ns = raw as NSString
                guard let match = lineRE.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)),
                      let start = Double(ns.substring(with: match.range(at: 1))), let duration = Double(ns.substring(with: match.range(at: 2))) else { continue }
                let body = ns.substring(with: match.range(at: 3)), bodyNS = body as NSString
                var words: [LyricWord] = []
                for m in tupleRE.matches(in: body, range: NSRange(location: 0, length: bodyNS.length)) {
                    let a = format == "qrc" ? 2 : 1, b = format == "qrc" ? 3 : 2, c = format == "qrc" ? 1 : 3
                    guard let tick = Double(bodyNS.substring(with: m.range(at: a))), let length = Double(bodyNS.substring(with: m.range(at: b))), length >= 0 else { continue }
                    let absolute = format == "krc" ? start + tick : tick
                    words.append(LyricWord(start: absolute / 1000, end: (absolute + length) / 1000, text: bodyNS.substring(with: m.range(at: c))))
                }
                lines.append(LyricLine(time: start / 1000, text: words.isEmpty ? body : words.map(\.text).joined(), end: (start + duration) / 1000, words: words.isEmpty ? nil : words))
            }
            return LyricsDocument(lines: lines.sorted { $0.time! < $1.time! }, source: source, format: format)
        default:
            var doc = LyricsParser.parse(text, source: source); doc.format = format
            let re = try! NSRegularExpression(pattern: #"<(\d+:\d+(?:\.\d+)?)>([^<]*)"#)
            for i in doc.lines.indices {
                let raw = doc.lines[i].text, ns = raw as NSString
                let matches = re.matches(in: raw, range: NSRange(location: 0, length: ns.length))
                var words: [LyricWord] = []
                for (j, m) in matches.enumerated() {
                    guard let start = time(ns.substring(with: m.range(at: 1))) else { continue }
                    let end = j + 1 < matches.count ? time(ns.substring(with: matches[j + 1].range(at: 1))) : doc.lines.indices.contains(i + 1) ? doc.lines[i + 1].time : nil
                    if let end, end >= start { words.append(LyricWord(start: start, end: end, text: ns.substring(with: m.range(at: 2)))) }
                }
                if !words.isEmpty { doc.lines[i].words = words; doc.lines[i].text = matches.map { ns.substring(with: $0.range(at: 2)) }.joined() }
            }
            return doc
        }
    }
}
private final class TTMLLyricsDelegate: NSObject, XMLParserDelegate {
    var lines: [LyricLine] = []
    var current: LyricLine?
    var stack: [(role: String, start: Double?, end: Double?, text: String)] = []
    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let name = element.split(separator: ":").last.map(String.init) ?? element
        if name == "p" {
            let start = attributes["begin"].flatMap(LyricsFormats.time)
            let end = attributes["end"].flatMap(LyricsFormats.time) ?? attributes["dur"].flatMap(LyricsFormats.time).flatMap { duration in start.map { $0 + duration } }
            current = LyricLine(time: start, text: "", end: end); stack = []
        }
        if name == "span", current != nil {
            func spanTime(_ raw: String) -> Double? {
                LyricsFormats.time(raw).map { value in raw.contains(":") ? value : value + (stack.last?.start ?? current?.time ?? 0) }
            }
            let start = attributes["begin"].flatMap(spanTime)
            let end = attributes["end"].flatMap(spanTime) ?? attributes["dur"].flatMap(LyricsFormats.time).flatMap { duration in start.map { $0 + duration } }
            stack.append((attributes["ttm:role"] ?? "", start, end, ""))
        }
        if name == "br", current != nil { current?.text += "\n" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard current != nil else { return }
        if !stack.isEmpty { stack[stack.count - 1].text += string }
        if !stack.contains(where: { $0.role == "x-translation" || $0.role == "x-roman" }) { current?.text += string }
    }
    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        let name = element.split(separator: ":").last.map(String.init) ?? element
        if name == "span", let span = stack.popLast() {
            if span.role == "x-translation" { current?.translation = span.text }
            else if span.role == "x-bg" { current?.background = true }
            else if let start = span.start, let end = span.end, start >= 0, end >= start {
                if current?.words == nil { current?.words = [] }
                current?.words?.append(LyricWord(start: start, end: end, text: span.text))
            }
            if !stack.isEmpty && span.role != "x-translation" && span.role != "x-roman" { stack[stack.count - 1].text += span.text }
        }
        if name == "p", var line = current {
            if line.time == nil { line.time = line.words?.first?.start }
            if line.end == nil { line.end = line.words?.last?.end }
            line.text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.text.isEmpty { lines.append(line) }; current = nil
        }
    }
}
