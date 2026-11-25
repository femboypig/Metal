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
    var anchoredLineStarts: [Int]?
}

struct LyricsSyncAttempt: Codable {
    var fingerprint: String
    var date: Date
    var revision: Int?
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
        text.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
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

        // Each row proposes its own local acoustic windows. A chronological chain
        // chooses occurrences across rows, so a bad verse cannot reject good rows.
        let keys = observed.map { normalized($0.text) }
        var candidates: [LineCandidate] = []
        var tree = [Int?](repeating: nil, count: observed.count + 2)
        var scores: [Double] = [], previous: [Int?] = []
        func best(_ lhs: Int?, _ rhs: Int?) -> Int? {
            guard let lhs else { return rhs }; guard let rhs else { return lhs }
            return scores[lhs] >= scores[rhs] ? lhs : rhs
        }
        for (row, indices) in lineTokens.enumerated() {
            try Task.checkCancellation()
            let local = try windows(reference: indices.map { tokens[$0].key }, observed: observed, keys: keys)
            let batchStart = candidates.count
            for window in local {
                var cursor = window.pairs.first!.1, predecessor: Int?
                while cursor > 0 { predecessor = best(predecessor, tree[cursor]); cursor -= cursor & -cursor }
                candidates.append(LineCandidate(row: row, pairs: window.pairs.map { (indices[$0.0], $0.1) }))
                scores.append((predecessor.map { scores[$0] } ?? 0) + window.score)
                previous.append(predecessor)
            }
            // Delay insertion until the row is complete: at most one occurrence per row.
            for candidate in batchStart..<candidates.count {
                var cursor = candidates[candidate].pairs.last!.1 + 1
                while cursor < tree.count { tree[cursor] = best(tree[cursor], candidate); cursor += cursor & -cursor }
            }
        }
        var tail: Int?
        for index in candidates.indices { tail = best(tail, index) }
        var matches: [Int: Int] = [:]
        while let index = tail {
            for pair in candidates[index].pairs { matches[pair.0] = pair.1 }
            tail = previous[index]
        }
        let coverage = Double(matches.count) / Double(tokens.count)
        var result = document
        for index in result.lines.indices {
            result.lines[index].time = nil; result.lines[index].end = nil; result.lines[index].words = nil
        }
        var alignedLines = 0
        var anchoredStarts: [Int] = []
        for (index, indices) in lineTokens.enumerated() {
            let matched = indices.filter { matches[$0] != nil }
            guard let first = matched.first, let last = matched.last,
                  let firstWord = matches[first], let lastWord = matches[last] else { continue }
            let start = observed[firstWord].start, end = observed[lastWord].end
            guard end > start else { continue }
            // If the opening word was missed, use the first actual anchor, never
            // extrapolate an invented onset. Keep this distinction for review.
            if first != indices.first { anchoredStarts.append(index) }
            result.lines[index].time = start; result.lines[index].end = end
            result.lines[index].words = matched.compactMap { token in
                matches[token].map { LyricWord(start: observed[$0].start, end: observed[$0].end, text: tokens[token].text) }
            }
            alignedLines += 1
        }
        let nonemptyLines = lineTokens.filter { !$0.isEmpty }.count
        let lineCoverage = Double(alignedLines) / Double(max(1, nonemptyLines))
        guard alignedLines > 0 else { throw LyricsAlignmentError.insufficientMatches }
        try Task.checkCancellation()
        result.timingTrusted = lineCoverage >= 1 && coverage >= 1 && anchoredStarts.isEmpty
        result.onDeviceTiming = LyricsOnDeviceTiming(language: language, date: Date(), wordCoverage: coverage,
            lineCoverage: lineCoverage, originalLines: document.lines, originalOffset: document.offset,
            originalTimingTrusted: document.timingTrusted, anchoredLineStarts: anchoredStarts)
        return result
    }

    private struct LineCandidate { var row: Int; var pairs: [(Int, Int)] }
    private struct Window { var pairs: [(Int, Int)]; var score: Double }

    /// Smith–Waterman local matching: omissions and ASR substitutions incur small
    /// penalties, while unrelated passages reset. Only exact acoustic word anchors
    /// receive timestamps; no fuzzy match is advertised as a recognized word.
    private static func windows(reference: [String], observed: [LyricsRecognizedWord], keys: [String]) throws -> [Window] {
        guard reference.count >= 2 else { return [] }
        let width = keys.count + 1
        var table = [Int16](repeating: 0, count: (reference.count + 1) * width)
        var ends = [Int](repeating: 0, count: width)
        for i in 1...reference.count {
            if i % 8 == 0 { try Task.checkCancellation() }
            for j in 1...keys.count {
                let p = i * width + j
                table[p] = max(0, table[p - width - 1] + (reference[i - 1] == keys[j - 1] ? 4 : -3),
                    table[p - width] - 1, table[p - 1] - 1)
                if reference[i - 1] == keys[j - 1], table[p] > table[ends[j]] { ends[j] = p }
            }
        }
        var windows: [Window] = []
        for endpoint in ends where table[endpoint] >= 7 {
            var i = endpoint / width, j = endpoint % width
            var pairs: [(Int, Int)] = []
            while i > 0 && j > 0 && table[i * width + j] > 0 {
                let p = i * width + j
                if table[p] == table[p - width - 1] + (reference[i - 1] == keys[j - 1] ? 4 : -3) {
                    if reference[i - 1] == keys[j - 1] { pairs.append((i - 1, j - 1)) }; i -= 1; j -= 1
                } else if table[p] == table[p - width] - 1 { i -= 1 }
                else { j -= 1 }
            }
            pairs.reverse()
            let minimum = reference.count >= 8 ? 3 : 2
            guard pairs.count >= minimum, Double(pairs.count) / Double(reference.count) >= 0.35,
                  Set(pairs.map { reference[$0.0] }).count >= 2,
                  pairs.contains(where: { reference[$0.0].count >= 4 }),
                  let first = pairs.first, let last = pairs.last else { continue }
            let span = last.1 - first.1 + 1
            guard Double(pairs.count) / Double(span) >= 0.45,
                  observed[last.1].end - observed[first.1].start <= max(12, Double(reference.count) * 1.2) else { continue }
            var compact = true
            for index in 1..<pairs.count {
                if observed[pairs[index].1].start - observed[pairs[index - 1].1].end > 5 { compact = false }
            }
            guard compact else { continue }
            windows.append(Window(pairs: pairs, score: Double(pairs.count * 4) - Double(span - pairs.count) * 0.5))
        }
        // Bound candidate-chain work even for pathological repetitions.
        return Array(windows.sorted { $0.score == $1.score ? $0.pairs[0].1 < $1.pairs[0].1 : $0.score > $1.score }.prefix(256))
    }
}
