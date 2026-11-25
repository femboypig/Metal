import Foundation

struct LyricsRecognizedWord: Sendable {
    var text: String
    var start: Double
    var end: Double
}

struct LyricsOnDeviceTiming: Codable {
    var language: String
    var date: Date
    var wordCoverage: Double
    var lineCoverage: Double
    var originalLines: [LyricLine]
    var originalOffset: Double
    var originalTimingTrusted: Bool?
}

struct LyricsSyncAttempt: Codable {
    var fingerprint: String
    var date: Date
}

enum LyricsAlignmentError: Error {
    case tooLong, insufficientMatches
}

enum LyricsAlignment {
    struct Token {
        var key: String
        var text: String
        var line: Int
    }

    static func fingerprint(_ document: LyricsDocument) -> String {
        LyricsResultIdentity.digest(document.lines.map(\.text).joined(separator: "\u{001f}"))
    }

    static func words(_ text: String) -> [String] {
        var words: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { value, _, _, _ in
            if let value { words.append(value) }
        }
        return words
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "ё", with: "е")
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    /// Matches existing text to observed acoustic word windows. No timing is interpolated.
    static func align(document: LyricsDocument, recognized: [LyricsRecognizedWord], duration: Double,
                      language: String) throws -> LyricsDocument {
        try Task.checkCancellation()
        var tokens: [Token] = []
        var lineTokens: [[Int]] = Array(repeating: [], count: document.lines.count)
        for (index, line) in document.lines.enumerated() {
            for word in words(line.text) {
                let key = normalized(word)
                guard !key.isEmpty else { continue }
                lineTokens[index].append(tokens.count)
                tokens.append(Token(key: key, text: word, line: index))
            }
        }
        // Phrase-level timestamps must not be advertised as individual word timestamps.
        let observed = recognized.filter {
            $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.start < duration && $0.end > $0.start &&
            $0.end <= duration + 0.25 && words($0.text).count == 1 && !normalized($0.text).isEmpty
        }.sorted { $0.start < $1.start }
        guard tokens.count >= 4, !observed.isEmpty else { throw LyricsAlignmentError.insufficientMatches }
        guard tokens.count <= 3_000, observed.count <= 6_000,
              (tokens.count + 1) * (observed.count + 1) <= 12_000_000 else { throw LyricsAlignmentError.tooLong }

        let keys = observed.map { normalized($0.text) }
        let width = observed.count + 1
        var table = [UInt16](repeating: 0, count: (tokens.count + 1) * width)
        for i in 1...tokens.count {
            if i % 16 == 0 { try Task.checkCancellation() }
            for j in 1...observed.count {
                let position = i * width + j
                table[position] = tokens[i - 1].key == keys[j - 1] ?
                    table[position - width - 1] + 1 : max(table[position - width], table[position - 1])
            }
        }
        var matches: [Int: Int] = [:]
        var i = tokens.count, j = observed.count
        while i > 0 && j > 0 {
            if tokens[i - 1].key == keys[j - 1] {
                matches[i - 1] = j - 1; i -= 1; j -= 1
            } else if table[(i - 1) * width + j] >= table[i * width + j - 1] { i -= 1 }
            else { j -= 1 }
        }
        var longestRun = 0, currentRun = 0, previousReference = -2, previousObserved = -2
        for token in matches.keys.sorted() {
            let observedIndex = matches[token]!
            currentRun = token == previousReference + 1 && observedIndex == previousObserved + 1 ? currentRun + 1 : 1
            longestRun = max(longestRun, currentRun)
            previousReference = token; previousObserved = observedIndex
        }
        guard longestRun >= min(4, tokens.count) else { throw LyricsAlignmentError.insufficientMatches }
        let coverage = Double(matches.count) / Double(tokens.count)
        guard coverage >= 0.72, matches.count >= min(6, tokens.count) else { throw LyricsAlignmentError.insufficientMatches }

        var result = document
        for index in result.lines.indices {
            result.lines[index].time = nil; result.lines[index].end = nil; result.lines[index].words = nil
        }
        var alignedLines = 0
        for (index, indices) in lineTokens.enumerated() {
            guard let first = indices.first, let last = indices.last,
                  let firstWord = matches[first], let lastWord = matches[last] else { continue }
            let matched = indices.filter { matches[$0] != nil }
            guard Double(matched.count) / Double(indices.count) >= 0.8 else { continue }
            let start = observed[firstWord].start, end = observed[lastWord].end
            guard end > start else { continue }
            result.lines[index].time = start; result.lines[index].end = end
            result.lines[index].words = matched.compactMap { token in
                matches[token].map { LyricWord(start: observed[$0].start, end: observed[$0].end, text: tokens[token].text) }
            }
            alignedLines += 1
        }
        let nonemptyLines = lineTokens.filter { !$0.isEmpty }.count
        let lineCoverage = Double(alignedLines) / Double(max(1, nonemptyLines))
        guard alignedLines > 0, lineCoverage >= 0.6 else { throw LyricsAlignmentError.insufficientMatches }
        try Task.checkCancellation()
        result.timingTrusted = true
        result.onDeviceTiming = LyricsOnDeviceTiming(language: language, date: Date(), wordCoverage: coverage,
            lineCoverage: lineCoverage, originalLines: document.lines, originalOffset: document.offset,
            originalTimingTrusted: document.timingTrusted)
        return result
    }
}
