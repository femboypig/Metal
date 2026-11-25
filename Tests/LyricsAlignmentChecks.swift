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

        // Missing the opening word keeps the row anchored to a real later word.
        let partial = try LyricsAlignment.align(document: plain, recognized: observation(texts, omit: [4]), duration: 60, language: "en")
        precondition(partial.lines[1].time == observed[5].start && partial.synchronized)
        precondition(partial.onDeviceTiming?.anchoredLineStarts == [1] && partial.timingTrusted == false)
        precondition(partial.synchronizationLevel == "Partial on-device sync")
        let thirdStart = partial.lines[2].time! + partial.offset
        precondition(partial.active(at: thirdStart) == 2, "Partial sync must return the original row index")

        precondition(partial.lines.map(\.text) == texts)

        // A completely missed passage remains untimed; other rows survive.
        let sparse = try LyricsAlignment.align(document: plain,
            recognized: observation(texts, omit: Set(4...7)), duration: 60, language: "en")
        precondition(sparse.lines[1].time == nil && sparse.synchronized && sparse.timingTrusted == false)
        precondition(sparse.active(at: thirdStart - 1) == nil)

        // Less than 20% of a song can still supply a useful, explicitly partial row.
        let longTexts = texts + (0..<12).map { "Unrecognized passage number \($0)" }
        let lowCoverage = try LyricsAlignment.align(document: LyricsParser.parse(longTexts.joined(separator: "\n"), source: "Fixture"),
            recognized: observation([texts[0]]), duration: 120, language: "en")
        precondition(lowCoverage.lines[0].time == 10 && lowCoverage.lines.dropFirst().allSatisfy { $0.time == nil })
        precondition(lowCoverage.timingTrusted == false && lowCoverage.synchronizationLevel == "Partial on-device sync")

        precondition(LyricsAlignment.normalized("мой") != LyricsAlignment.normalized("мои"), "Cyrillic letters must retain phonetic distinctions")
        let russian = ["Ёлки тихо смотрят в небо", "Мы идём туда где свет"]
        let russianDoc = LyricsParser.parse(russian.joined(separator: "\n"), source: "Fixture")
        let russianAligned = try LyricsAlignment.align(document: russianDoc, recognized: observation(russian), duration: 60, language: "ru")
        precondition(russianAligned.synchronized && russianAligned.lines.map(\.text) == russian)
        // Realistic ASR substitutions and omitted boundary words: text stays intact.
        let ruLines = ["Ночью тихий ветер греет наши руки", "Никто не разобрал слова припева", "Снова тихий ветер греет наши руки"]
        let ruDoc = LyricsParser.parse(ruLines.joined(separator: "\n"), source: "Fixture")
        let ruWords = observation(ruLines, omit: [0, 6, 7, 8, 9, 10, 11, 12, 18])
        var noisy = ruWords
        if let index = noisy.firstIndex(where: { $0.text == "греет" }) { noisy[index].text = "реет" }
        let ruPartial = try LyricsAlignment.align(document: ruDoc, recognized: noisy, duration: 90, language: "ru")
        precondition(ruPartial.lines.map(\.text) == ruLines)
        precondition(ruPartial.lines[0].time != nil && ruPartial.lines[1].time == nil && ruPartial.lines[2].time != nil)
        precondition(ruPartial.lines[0].time! < ruPartial.lines[2].time! && ruPartial.timingTrusted == false)
        precondition(ruPartial.lines.flatMap { $0.words ?? [] }.allSatisfy { word in noisy.contains { $0.start == word.start && $0.end == word.end } })
        let phraseSync = try LyricsAlignment.align(document: russianDoc, recognized: [
            LyricsRecognizedWord(text: russian[0], start: 2.125, end: 4.875),
            LyricsRecognizedWord(text: russian[1], start: 6.25, end: 9.125)], duration: 30, language: "ru")
        precondition(phraseSync.lines[0].time == 2.125 && phraseSync.lines[1].time == 6.25)
        precondition(phraseSync.lines.allSatisfy { $0.words == nil }, "Phrase windows must not invent word timings")
        // A few unrelated common words at widely separated times must not form a row.
        do {
            _ = try LyricsAlignment.align(document: ruDoc, recognized: [
                LyricsRecognizedWord(text: "тихий", start: 1, end: 2),
                LyricsRecognizedWord(text: "ветер", start: 30, end: 31)], duration: 90, language: "ru")
            preconditionFailure("Scattered coincidences must not invent a lyric span")
        } catch LyricsAlignmentError.insufficientMatches { }
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
        let ruChorus = ["Тихий ветер унесёт печали", "Свет над городом встречает утро", "Тихий ветер унесёт печали"]
        let chorusRuDoc = LyricsParser.parse(ruChorus.joined(separator: "\n"), source: "Fixture")
        let ruRepeated = try LyricsAlignment.align(document: chorusRuDoc, recognized: observation(ruChorus, omit: [0, 3, 9, 12]), duration: 60, language: "ru")
        let ruStarts = ruRepeated.lines.compactMap(\.time)
        precondition(ruStarts.count == 3 && zip(ruStarts, ruStarts.dropFirst()).allSatisfy { $0 < $1 })

        let onlyLaterChorus = observation(ruChorus, omit: Set(0...3))
        let locatedChorus = try LyricsAlignment.align(document: chorusRuDoc, recognized: onlyLaterChorus, duration: 60, language: "ru")
        precondition(locatedChorus.lines[0].time == nil && locatedChorus.lines[1].time != nil && locatedChorus.lines[2].time != nil,
            "Neighboring verse anchors must place the lone chorus at its later occurrence")
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
        let manualSaved = try await reopened.correctOnDeviceLine(id: "import", sourceKey: "imported",
            fingerprint: LyricsAlignment.fingerprint(plain), row: 1, time: 13)
        precondition(manualSaved)
        let corrected = await LyricsStore(directory: directory).resolved("import")
        precondition(corrected?.lines[1].time == 13 && corrected?.lines[1].text == texts[1])
        let invalidEdit = try await reopened.correctOnDeviceLine(id: "import", sourceKey: "imported",
            fingerprint: LyricsAlignment.fingerprint(plain), row: 1, time: 55)
        precondition(!invalidEdit, "Manual edits must preserve chronological row order")
        try await reopened.removeOnDeviceTiming(id: "import")
        let restored = await reopened.resolved("import")
        precondition(restored?.lines == plain.lines && restored?.offset == 1.75 && restored?.onDeviceTiming == nil)

        let cancelledSave = Task {
            while !Task.isCancelled { await Task.yield() }
            return try await store.saveOnDeviceTiming(aligned, id: "import", sourceKey: "imported", fingerprint: LyricsAlignment.fingerprint(plain))
        }
        cancelledSave.cancel()
        do { _ = try await cancelledSave.value; preconditionFailure("Cancelled alignment must not persist") }
        catch is CancellationError { }
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
