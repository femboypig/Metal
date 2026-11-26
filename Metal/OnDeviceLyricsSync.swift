import Foundation
import AVFoundation
import AudioToolbox
import Speech
import NaturalLanguage

enum OnDeviceLyricsSyncError: LocalizedError {
    case unavailable, permission, declined, noSpeech
    case unsupported(String)
    var errorDescription: String? {
        switch self {
        case .unavailable: return "On-device speech is unavailable for this language."
        case .unsupported(let detail): return detail
        case .permission: return "Speech recognition permission is needed for on-device sync."
        case .declined: return "Speech model download postponed."
        case .noSpeech: return "Could not match the vocals reliably."
        }
    }
}

actor OnDeviceLyricsSync {
    private var diagnostics: [String] = []
    private func record(_ value: String) {
        diagnostics.append(value)
        UserDefaults.standard.set(diagnostics.joined(separator: "\n"), forKey: "MetalLyricsSync.diagnostics")
    }
    typealias Progress = @Sendable (String) -> Void
    typealias DownloadConsent = @Sendable (String) async -> Bool

    func generate(url: URL, document: LyricsDocument, forceModelPrompt: Bool = false, progress: @escaping Progress,
                  downloadConsent: @escaping DownloadConsent) async throws -> LyricsDocument {
        diagnostics = ["OS: " + ProcessInfo.processInfo.operatingSystemVersionString]
        record("Alignment revision: local-lines-v4-context")
        try Task.checkCancellation()
        let text = document.lines.map(\.text).joined(separator: "\n")
        let referenceWords = document.lines.reduce(0) { $0 + LyricsAlignment.words($1.text).count }
        guard referenceWords >= 4 else { throw LyricsAlignmentError.insufficientMatches }
        guard text.count <= 40_000, referenceWords <= 3_000 else { throw LyricsAlignmentError.tooLong }
        let detector = NLLanguageRecognizer()
        detector.processString(text)
        guard let language = detector.dominantLanguage else { throw OnDeviceLyricsSyncError.unavailable }
        let locale = Locale(identifier: language == .russian ? "ru-RU" : language.rawValue)
        record("Requested locale: " + locale.identifier)
        progress("Preparing on-device sync…")
        let source = try AVAudioFile(forReading: url)
        record("Source format: \(source.fileFormat); processing: \(source.processingFormat); frames: \(source.length)")
        let duration = Double(source.length) / source.processingFormat.sampleRate
        guard duration.isFinite, duration > 0, duration <= 1_800 else { throw LyricsAlignmentError.tooLong }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MetalLyricsSync-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let observed: [LyricsRecognizedWord]
        do {
            if #available(iOS 26.0, macOS 26.0, *) {
                let speechLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
                let dictationLocale = await DictationTranscriber.supportedLocale(equivalentTo: locale)
                record("SpeechTranscriber.isAvailable: \(SpeechTranscriber.isAvailable)")
                record("SpeechTranscriber.supportedLocale: \(speechLocale?.identifier ?? "nil")")
                record("DictationTranscriber.supportedLocale: \(dictationLocale?.identifier ?? "nil")")
                if let supported = dictationLocale, language == .russian || !SpeechTranscriber.isAvailable || speechLocale == nil {
                    record("Selected: DictationTranscriber")
                    observed = try await dictation(source: source, directory: directory, locale: supported,
                        progress: progress, consent: downloadConsent, forceModelPrompt: forceModelPrompt, hints: document.lines.map(\.text))
                } else if SpeechTranscriber.isAvailable, let supported = speechLocale {
                    record("Selected: SpeechTranscriber")
                    observed = try await modern(source: source, directory: directory, locale: supported,
                        progress: progress, consent: downloadConsent, forceModelPrompt: forceModelPrompt, hints: document.lines.map(\.text))
                } else {
                    record("Modern modules unavailable; checking strictly on-device SFSpeechRecognizer")
                    observed = try await legacy(source: source, directory: directory, locale: locale,
                        hints: document.lines.map(\.text), progress: progress)
                }
            } else {
                record("SpeechAnalyzer and DictationTranscriber require iOS 26")
                observed = try await legacy(source: source, directory: directory, locale: locale,
                    hints: document.lines.map(\.text), progress: progress)
            }
        } catch {
            record("Recognition failure: \(error.localizedDescription)")
            throw error
        }
        record("Observed timing units: \(observed.count); word windows: \(observed.filter { LyricsAlignment.words($0.text).count == 1 }.count)")
        try Task.checkCancellation()
        progress("Matching existing lyrics…")
        do {
            let aligned = try LyricsAlignment.align(document: document, recognized: observed, duration: duration, language: language.rawValue)
            record("Aligned lines: \(aligned.lines.filter { $0.time != nil }.count)/\(aligned.lines.count); \(aligned.synchronizationLevel)")
            return aligned
        } catch {
            record("No sufficiently confirmed line windows: \(error)")
            throw error
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func modern(source: AVAudioFile, directory: URL, locale: Locale, progress: @escaping Progress,
                        consent: @escaping DownloadConsent, forceModelPrompt: Bool, hints: [String]) async throws -> [LyricsRecognizedWord] {
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [],
            attributeOptions: [.audioTimeRange])
        let modules: [any SpeechModule] = [transcriber]
        try await ensureModel(modules, locale: locale, name: "SpeechTranscriber", progress: progress,
            consent: consent, forceModelPrompt: forceModelPrompt)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules, considering: source.processingFormat) else {
            throw OnDeviceLyricsSyncError.unavailable
        }
        progress("Preparing audio…")
        record("Preparing PCM for analyzer: \(format)")
        let file: AVAudioFile
        do { file = try Self.prepareAudio(source, directory: directory, format: format) }
        catch { record("PCM preparation failed: \(Self.errorDetails(error))"); throw error }
        record("Prepared PCM frames: \(file.length); format: \(file.processingFormat); duration: \(Double(file.length) / file.processingFormat.sampleRate)")
        let analyzer = SpeechAnalyzer(modules: modules, options: nil)
        let context = AnalysisContext()
        context.contextualStrings[.general] = Self.recognitionHints(hints)
        do { try await analyzer.setContext(context); record("Existing-text context applied") }
        catch is CancellationError { throw CancellationError() }
        catch { record("Optional text context unavailable: \(Self.errorDetails(error))") }
        return try await withTaskCancellationHandler(operation: {
            progress("Matching vocals on device…")
            async let feeding: Void = feed(analyzer, file: file)
            var words: [LyricsRecognizedWord] = []
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    guard result.isFinal else { continue }
                    for run in result.text.runs {
                        guard let range = run.audioTimeRange else { continue }
                        let text = String(result.text[run.range].characters)
                        words.append(LyricsRecognizedWord(text: text, start: CMTimeGetSeconds(range.start),
                            end: CMTimeGetSeconds(CMTimeRangeGetEnd(range))))
                    }
                }
                try await feeding
                return words
            } catch {
                record("Analyzer results failed: \(Self.errorDetails(error))")
                await analyzer.cancelAndFinishNow()
                throw error
            }
        }, onCancel: {
            Task { await analyzer.cancelAndFinishNow() }
        })
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func dictation(source: AVAudioFile, directory: URL, locale: Locale, progress: @escaping Progress,
                        consent: @escaping DownloadConsent, forceModelPrompt: Bool, hints: [String]) async throws -> [LyricsRecognizedWord] {
        let transcriber = DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [], reportingOptions: [],
            attributeOptions: [.audioTimeRange])
        let modules: [any SpeechModule] = [transcriber]
        try await ensureModel(modules, locale: locale, name: "DictationTranscriber", progress: progress,
            consent: consent, forceModelPrompt: forceModelPrompt)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules, considering: source.processingFormat) else {
            throw OnDeviceLyricsSyncError.unavailable
        }
        progress("Preparing audio…")
        record("Preparing PCM for analyzer: \(format)")
        let file: AVAudioFile
        do { file = try Self.prepareAudio(source, directory: directory, format: format) }
        catch { record("PCM preparation failed: \(Self.errorDetails(error))"); throw error }
        record("Prepared PCM frames: \(file.length); format: \(file.processingFormat); duration: \(Double(file.length) / file.processingFormat.sampleRate)")
        let analyzer = SpeechAnalyzer(modules: modules, options: nil)
        let context = AnalysisContext()
        context.contextualStrings[.general] = Self.recognitionHints(hints)
        do { try await analyzer.setContext(context); record("Existing-text context applied") }
        catch is CancellationError { throw CancellationError() }
        catch { record("Optional text context unavailable: \(Self.errorDetails(error))") }
        return try await withTaskCancellationHandler(operation: {
            progress("Matching vocals on device…")
            async let feeding: Void = feed(analyzer, file: file)
            var words: [LyricsRecognizedWord] = []
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    guard result.isFinal else { continue }
                    for run in result.text.runs {
                        guard let range = run.audioTimeRange else { continue }
                        let text = String(result.text[run.range].characters)
                        words.append(LyricsRecognizedWord(text: text, start: CMTimeGetSeconds(range.start),
                            end: CMTimeGetSeconds(CMTimeRangeGetEnd(range))))
                    }
                }
                try await feeding
                return words
            } catch {
                record("Analyzer results failed: \(Self.errorDetails(error))")
                await analyzer.cancelAndFinishNow()
                throw error
            }
        }, onCancel: {
            Task { await analyzer.cancelAndFinishNow() }
        })
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func feed(_ analyzer: SpeechAnalyzer, file: AVAudioFile) async throws {
        do {
            record("Starting analyzer PCM stream")
            let input = LyricsAudioInput(url: file.url, commonFormat: file.processingFormat.commonFormat,
                interleaved: file.processingFormat.isInterleaved)
            _ = try await analyzer.analyzeSequence(input)
            record("Analyzer PCM stream fully consumed")
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            record("Analyzer results finalized")
        } catch {
            record("Analyzer PCM stream failed: \(Self.errorDetails(error))")
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func ensureModel(_ modules: [any SpeechModule], locale: Locale, name: String,
                             progress: @escaping Progress, consent: @escaping DownloadConsent,
                             forceModelPrompt: Bool) async throws {
        let status = await AssetInventory.status(forModules: modules)
        record("\(name) AssetInventory.status: \(status)")
        guard status != .unsupported else {
            throw OnDeviceLyricsSyncError.unsupported("\(name): AssetInventory returned unsupported for \(locale.identifier) on this device.")
        }
        if status != .installed {
            let preference = "MetalLyricsSync.modelDeclined." + locale.identifier
            if !forceModelPrompt, let date = UserDefaults.standard.object(forKey: preference) as? Date,
               Date().timeIntervalSince(date) < 604_800 { throw OnDeviceLyricsSyncError.declined }
            let language = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            let accepted = await consent(language)
            try Task.checkCancellation()
            guard accepted else { UserDefaults.standard.set(Date(), forKey: preference); throw OnDeviceLyricsSyncError.declined }
            UserDefaults.standard.removeObject(forKey: preference)
            progress("Installing speech model…")
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await withTaskCancellationHandler(operation: { try await request.downloadAndInstall() },
                    onCancel: { request.progress.cancel() })
            }
        }
        let installed = await AssetInventory.status(forModules: modules)
        record("\(name) AssetInventory.status after installation: \(installed)")
        guard installed == .installed else {
            throw OnDeviceLyricsSyncError.unsupported("\(name): local model for \(locale.identifier) is not installed (\(installed)).")
        }
    }

    private func legacy(source: AVAudioFile, directory: URL, locale: Locale, hints: [String],
                        progress: @escaping Progress) async throws -> [LyricsRecognizedWord] {
        let preferred = Locale.preferredLanguages.map(Locale.init(identifier:)).first { $0.languageCode == locale.languageCode }
        let locales = SFSpeechRecognizer.supportedLocales().filter { $0.languageCode == locale.languageCode }.sorted { $0.identifier < $1.identifier }
        let supported = locales.first { $0.regionCode == preferred?.regionCode } ??
            locales.first { $0.regionCode == Locale.current.regionCode } ??
            locales.first { $0.regionCode == (locale.languageCode == "en" ? "US" : "RU") } ?? locales.first
        record("SFSpeechRecognizer.supportedLocale: \(supported?.identifier ?? "nil")")
        guard let supported, let recognizer = SFSpeechRecognizer(locale: supported) else {
            throw OnDeviceLyricsSyncError.unsupported("SFSpeechRecognizer: no recognizer for \(locale.identifier). See Copy On-device Sync Details for module checks.")
        }
        record("SFSpeechRecognizer.supportsOnDeviceRecognition: \(recognizer.supportsOnDeviceRecognition)")
        guard recognizer.supportsOnDeviceRecognition else {
            throw OnDeviceLyricsSyncError.unsupported("SFSpeechRecognizer: supportsOnDeviceRecognition is false for \(supported.identifier). See Copy On-device Sync Details. No server fallback was used.")
        }
        let authorization: SFSpeechRecognizerAuthorizationStatus
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else { authorization = SFSpeechRecognizer.authorizationStatus() }
        guard authorization == .authorized else { throw OnDeviceLyricsSyncError.permission }
        try Task.checkCancellation()
        record("SFSpeechRecognizer.isAvailable: \(recognizer.isAvailable)")
        guard recognizer.isAvailable else {
            throw OnDeviceLyricsSyncError.unsupported("SFSpeechRecognizer: isAvailable is false for \(supported.identifier) on this device.")
        }
        progress("Preparing audio…")
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let file = try Self.prepareAudio(source, directory: directory, format: format)
        let chunkFrames = AVAudioFramePosition(format.sampleRate * 45)
        let overlap = AVAudioFramePosition(format.sampleRate * 0.75)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4_096)!
        var start: AVAudioFramePosition = 0
        var observed: [LyricsRecognizedWord] = []
        var completedChunks = 0
        while start < file.length {
            try Task.checkCancellation()
            let end = min(file.length, start + chunkFrames)
            let chunk = directory.appendingPathComponent("chunk.caf")
            do {
                let output = try AVAudioFile(forWriting: chunk, settings: file.processingFormat.settings)
                file.framePosition = start
                while file.framePosition < end {
                    try Task.checkCancellation()
                    try file.read(into: buffer, frameCount: AVAudioFrameCount(min(4_096, end - file.framePosition)))
                    guard buffer.frameLength > 0 else { break }
                    try output.write(from: buffer)
                }
            }
            progress("Matching vocals on device…")
            do {
                let words = try await Self.recognize(recognizer, url: chunk, hints: hints)
                let low = Double(start + (start > 0 ? overlap / 2 : 0)) / format.sampleRate
                let high = Double(end - (end < file.length ? overlap / 2 : 0)) / format.sampleRate
                let offset = Double(start) / format.sampleRate
                observed += words.map { LyricsRecognizedWord(text: $0.text, start: $0.start + offset, end: $0.end + offset) }
                    .filter { ($0.start + $0.end) * 0.5 >= low && ($0.start + $0.end) * 0.5 <= high }
                completedChunks += 1
            } catch is CancellationError { throw CancellationError() }
            catch {
                // Instrumental passages can produce no-speech errors. Later chunks
                // remain independent; a failed chunk never receives guessed timings.
            }
            try? FileManager.default.removeItem(at: chunk)
            if end == file.length { break }
            start = end - overlap
        }
        guard completedChunks > 0, !observed.isEmpty else { throw OnDeviceLyricsSyncError.noSpeech }
        return observed
    }

    private static func recognize(_ recognizer: SFSpeechRecognizer, url: URL, hints: [String]) async throws -> [LyricsRecognizedWord] {
        let gate = LyricsRecognitionGate()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                guard gate.prepare(continuation) else { return }
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.requiresOnDeviceRecognition = true
                request.shouldReportPartialResults = false
                request.taskHint = .dictation
                request.contextualStrings = Array(hints.filter { $0.count <= 160 }.prefix(64))
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        gate.finish(.success(result.bestTranscription.segments.map {
                            LyricsRecognizedWord(text: $0.substring, start: $0.timestamp, end: $0.timestamp + $0.duration)
                        }))
                    } else if let error { gate.finish(.failure(error)) }
                }
                gate.install(task)
            }
        }, onCancel: { gate.cancel() })
    }

    static func prepareAudio(_ source: AVAudioFile, directory: URL, format: AVAudioFormat) throws -> AVAudioFile {
        let url = directory.appendingPathComponent("analysis.caf")
        try convert(source, to: url, format: format)
        // AVAudioFile's default reader converts to Float32. SpeechAnalyzer requires
        // the exact format selected by the module, which may instead be Int16.
        return try AVAudioFile(forReading: url, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
    }

    /// Supply vocabulary and short phrases without replacing the source lyrics.
    static func recognitionHints(_ lines: [String]) -> [String] {
        var seen = Set<String>(), values: [String] = []
        for line in lines {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, text.count <= 120, seen.insert(text.lowercased()).inserted { values.append(text) }
            if values.count >= 100 { break }
        }
        return values
    }

    private static func errorDetails(_ error: Error) -> String {
        let value = error as NSError
        let underlying = (value.userInfo[NSUnderlyingErrorKey] as? NSError).map { "; underlying: \($0.domain) \($0.code)" } ?? ""
        return "\(value.domain) \(value.code): \(value.localizedDescription)" + underlying
    }

    /// EOF is a normal decoder termination, including reads returning a final
    /// partial buffer with eofErr. Other read errors must still fail the job.
    static func readAudioFrames(into buffer: AVAudioPCMBuffer, read: () throws -> Void) throws -> Bool {
        buffer.frameLength = 0
        do {
            try read()
            return buffer.frameLength == 0
        } catch {
            let value = error as NSError
            guard value.domain == NSOSStatusErrorDomain && value.code == Int(kAudioFileEndOfFileError) else { throw error }
            return true
        }
    }

    /// Stream conversion keeps memory bounded and preserves the file's time origin.
    private static func convert(_ source: AVAudioFile, to url: URL, format: AVAudioFormat) throws {
        source.framePosition = 0
        guard let converter = AVAudioConverter(from: source.processingFormat, to: format),
              let input = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 4_096),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096) else { throw OnDeviceLyricsSyncError.unavailable }
        converter.downmix = true
        let destination = try AVAudioFile(forWriting: url, settings: format.settings,
            commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        var readError: Error?
        var sourceEnded = false
        var decodedFrames: AVAudioFramePosition = 0
        while true {
            try Task.checkCancellation()
            var error: NSError?
            output.frameLength = 0
            let status = converter.convert(to: output, error: &error) { requested, state in
                guard !sourceEnded else { state.pointee = .endOfStream; return nil }
                do {
                    sourceEnded = try Self.readAudioFrames(into: input) {
                        try source.read(into: input, frameCount: min(4_096, requested))
                    }
                    decodedFrames += AVAudioFramePosition(input.frameLength)
                    state.pointee = input.frameLength > 0 ? .haveData : .endOfStream
                    return input.frameLength > 0 ? input : nil
                } catch { readError = error; state.pointee = .endOfStream; return nil }
            }
            if let readError { throw readError }
            if let error { throw error }
            if output.frameLength > 0 { try destination.write(from: output) }
            if status == .endOfStream { break }
            if status == .error { throw OnDeviceLyricsSyncError.unavailable }
        }
        guard decodedFrames > 0, destination.length > 0 else { throw OnDeviceLyricsSyncError.noSpeech }

    }
}

/// Pull-based input bounds memory to the buffers SpeechAnalyzer is consuming.
/// Own the decoder EOF handling instead of using its opaque file-input adapter.
@available(iOS 26.0, macOS 26.0, *)
struct LyricsAudioInput: AsyncSequence, Sendable {
    typealias Element = AnalyzerInput
    let url: URL
    let commonFormat: AVAudioCommonFormat
    let interleaved: Bool
    func makeAsyncIterator() -> Iterator { Iterator(url: url, commonFormat: commonFormat, interleaved: interleaved) }
    struct Iterator: AsyncIteratorProtocol {
        let url: URL
        let commonFormat: AVAudioCommonFormat
        let interleaved: Bool
        private var file: AVAudioFile?
        private var finished = false
        private var frames: Int64 = 0
        init(url: URL, commonFormat: AVAudioCommonFormat, interleaved: Bool) {
            self.url = url; self.commonFormat = commonFormat; self.interleaved = interleaved
        }
        mutating func next() async throws -> AnalyzerInput? {
            try Task.checkCancellation()
            guard !finished else { return nil }
            if file == nil { file = try AVAudioFile(forReading: url, commonFormat: commonFormat, interleaved: interleaved) }
            guard let file, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else {
                throw OnDeviceLyricsSyncError.unavailable
            }
            finished = try OnDeviceLyricsSync.readAudioFrames(into: buffer) { try file.read(into: buffer, frameCount: 4096) }
            guard buffer.frameLength > 0 else { self.file = nil; return nil }
            let start = CMTime(seconds: Double(frames) / file.processingFormat.sampleRate, preferredTimescale: 1_000_000_000)
            frames += Int64(buffer.frameLength)
            return AnalyzerInput(buffer: buffer, bufferStartTime: start)
        }
    }
}

/// Callback cancellation can race final recognition results; resume exactly once.
final class LyricsRecognitionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[LyricsRecognizedWord], Error>?
    private var task: SFSpeechRecognitionTask?
    private var cancelled = false
    private var completed = false
    func prepare(_ value: CheckedContinuation<[LyricsRecognizedWord], Error>) -> Bool {
        lock.lock()
        if cancelled { lock.unlock(); value.resume(throwing: CancellationError()); return false }
        continuation = value; lock.unlock(); return true
    }
    func install(_ value: SFSpeechRecognitionTask) {
        lock.lock()
        if cancelled || completed { lock.unlock(); value.cancel(); return }
        task = value; lock.unlock()
    }
    func finish(_ result: Result<[LyricsRecognizedWord], Error>) {
        lock.lock(); completed = true; let value = continuation; continuation = nil; task = nil; lock.unlock()
        value?.resume(with: result)
    }
    func cancel() {
        lock.lock(); cancelled = true; let current = task; task = nil
        let value = continuation; continuation = nil; lock.unlock()
        current?.cancel(); value?.resume(throwing: CancellationError())
    }
}
