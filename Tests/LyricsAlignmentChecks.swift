import Foundation

@main struct LyricsAlignmentChecks {
    static func observation(_ lines: [String], omit: Set<Int> = []) -> [LyricsRecognizedWord] {
        lines.flatMap(LyricsAlignment.words).enumerated().compactMap { index, word in
            guard !omit.contains(index) else { return nil }
            return LyricsRecognizedWord(text: word.replacingOccurrences(of: "ё", with: "е"),
                start: 10 + Double(index) * 0.7, end: 10.4 + Double(index) * 0.7)
        }
    }
    static func main() async throws {
        let texts = ["Silver morning over water", "Carry echoes into daylight", "Hold this moment beside me", "Stay until the quiet evening"]
        var plain = LyricsParser.parse(texts.joined(separator: "\n"), source: "Imported")
        plain.offset = 1.25
        let observed = observation(texts)
        let aligned = try LyricsAlignment.align(document: plain, recognized: observed, duration: 60, language: "en")
        precondition(aligned.lines.map(\.text) == texts && aligned.synchronized)
        precondition(aligned.lines[0].time == observed[0].start)
        precondition(aligned.lines[0].words?.first?.end == observed[0].end)
        precondition(aligned.active(at: observed[0].start + 1.25) == 0)
        precondition(aligned.active(at: 0) == nil)

        // Missing the first word of the second line leaves that line untimed.
        let partial = try LyricsAlignment.align(document: plain, recognized: observation(texts, omit: [4]), duration: 60, language: "en")
        precondition(partial.lines[1].time == nil && partial.synchronized)
        precondition(partial.synchronizationLevel == "Partial on-device sync")
        let thirdStart = partial.lines[2].time! + partial.offset
        precondition(partial.active(at: thirdStart) == 2, "Partial sync must return the original row index")
        precondition(partial.active(at: thirdStart - 1) == nil, "An unrecognized passage must not inherit an earlier highlight")
        precondition(partial.lines.map(\.text) == texts)

        let russian = ["Ёлки тихо смотрят в небо", "Мы идём туда где свет"]
        let russianDoc = LyricsParser.parse(russian.joined(separator: "\n"), source: "Fixture")
        let russianAligned = try LyricsAlignment.align(document: russianDoc, recognized: observation(russian), duration: 60, language: "ru")
        precondition(russianAligned.synchronized && russianAligned.lines.map(\.text) == russian)
        do {
            _ = try LyricsAlignment.align(document: plain, recognized: [LyricsRecognizedWord(text: "unrelated", start: 2, end: 3)], duration: 60, language: "en")
            preconditionFailure("Unrelated recognition must never receive invented synchronization")
        } catch LyricsAlignmentError.insufficientMatches { }
        do {
            _ = try LyricsAlignment.align(document: plain, recognized: [LyricsRecognizedWord(text: "Silver", start: .nan, end: .infinity)], duration: 60, language: "en")
            preconditionFailure("Malformed recognition timestamps must be rejected")
        } catch LyricsAlignmentError.insufficientMatches { }

        let chorus = ["Hold on to me", "Bright day over water", "Hold on to me"]
        let chorusDoc = LyricsParser.parse(chorus.joined(separator: "\n"), source: "Fixture")
        let repeated = try LyricsAlignment.align(document: chorusDoc, recognized: observation(chorus), duration: 60, language: "en")
        precondition(repeated.lines[0].time! < repeated.lines[2].time!, "Repeated lyrics must keep distinct acoustic occurrences")
        let cancelled = Task {
            while !Task.isCancelled { await Task.yield() }
            return try LyricsAlignment.align(document: plain, recognized: observed, duration: 60, language: "en")
        }
        cancelled.cancel()
        do { _ = try await cancelled.value; preconditionFailure("Cancelled matching must stop") }
        catch is CancellationError { }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LyricsStore(directory: directory)
        try await store.install(plain, id: "import")
        try await store.adjust(0.5, id: "import")
        let displayed = await store.resolved("import")!
        let fromDisplayed = try LyricsAlignment.align(document: displayed, recognized: observed, duration: 60, language: "en")
        let saved = try await store.saveOnDeviceTiming(fromDisplayed, id: "import", sourceKey: "imported", fingerprint: LyricsAlignment.fingerprint(plain))
        precondition(saved)
        let reopened = LyricsStore(directory: directory)
        let persisted = await reopened.resolved("import")
        precondition(persisted?.onDeviceTiming?.language == "en" && persisted?.offset == 1.75, "Offsets must be applied once")
        try await reopened.removeOnDeviceTiming(id: "import")
        let restored = await reopened.resolved("import")
        precondition(restored?.lines == plain.lines && restored?.offset == 1.75 && restored?.onDeviceTiming == nil)

        try await store.install(LyricsParser.parse("Replacement text", source: "Imported"), id: "import")
        let rejected = try await store.saveOnDeviceTiming(aligned, id: "import", sourceKey: "imported", fingerprint: LyricsAlignment.fingerprint(plain))
        precondition(!rejected, "A late recognition result must not overwrite an imported replacement")
        var online = plain; online.source = "Fixture"; online.resultKey = "fixture:1:lrc"
        try await store.cache(online, id: "online")
        try await store.select(online, id: "online")
        let onlineAligned = try LyricsAlignment.align(document: online, recognized: observed, duration: 60, language: "en")
        let onlineSaved = try await store.saveOnDeviceTiming(onlineAligned, id: "online", sourceKey: online.resultKey!, fingerprint: LyricsAlignment.fingerprint(online))
        precondition(onlineSaved)
        try await store.cache(online, id: "online")
        try await store.select(online, id: "online")
        let retained = await store.resolved("online")
        precondition(retained?.onDeviceTiming != nil && retained?.resultKey == online.resultKey, "Plain refetches must retain generated timing and source selection")
        var verified = online
        for index in verified.lines.indices { verified.lines[index].time = Double(index) + 1 }
        verified.timingTrusted = true
        try await store.cache(verified, id: "online")
        let replaced = await store.resolved("online")
        precondition(replaced?.onDeviceTiming == nil && replaced?.lines[0].time == 1, "Verified provider timestamps supersede experimental alignment")
        print("On-device alignment, Cyrillic, native timestamps, partial-row lookup, confidence rejection, persistence, offsets and stale-result protection passed")
    }
}
