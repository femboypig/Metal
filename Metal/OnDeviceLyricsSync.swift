import Foundation
import AVFoundation
import Speech
import NaturalLanguage

enum OnDeviceLyricsSyncError: LocalizedError {
    case unavailable, permission, declined, noSpeech
    var errorDescription: String? {
        switch self {
        case .unavailable: return "On-device speech is unavailable for this language."
        case .permission: return "Speech recognition permission is needed for on-device sync."
        case .declined: return "Speech model download postponed."
        case .noSpeech: return "Could not match the vocals reliably."
        }
    }
}

actor OnDeviceLyricsSync {
    typealias Progress = @Sendable (String) -> Void
    typealias DownloadConsent = @Sendable (String) async -> Bool

    func generate(url: URL, document: LyricsDocument, forceModelPrompt: Bool = false, progress: @escaping Progress,
                  downloadConsent: @escaping DownloadConsent) async throws -> LyricsDocument {
        try Task.checkCancellation()
        let text = document.lines.map(\.text).joined(separator: "\n")
        guard text.count <= 40_000, document.lines.reduce(0, { $0 + LyricsAlignment.words($1.text).count }) <= 3_000 else { throw LyricsAlignmentError.tooLong }
        let detector = NLLanguageRecognizer()
        detector.processString(text)
        guard let language = detector.dominantLanguage else { throw OnDeviceLyricsSyncError.unavailable }
        let locale = Locale(identifier: language.rawValue)
        progress("Preparing on-device sync…")
        let source = try AVAudioFile(forReading: url)
        let duration = Double(source.length) / source.processingFormat.sampleRate
        guard duration.isFinite, duration > 0, duration <= 1_800 else { throw LyricsAlignmentError.tooLong }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MetalLyricsSync-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let observed: [LyricsRecognizedWord]
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            observed = try await modern(source: source, directory: directory, locale: supported,
                progress: progress, consent: downloadConsent, forceModelPrompt: forceModelPrompt)
        } else {
            observed = try await legacy(source: source, directory: directory, locale: locale,
                hints: document.lines.map(\.text), progress: progress)
        }
        try Task.checkCancellation()
        progress("Matching existing lyrics…")
        return try LyricsAlignment.align(document: document, recognized: observed, duration: duration, language: language.rawValue)
    }

    @available(iOS 26.0, *)
    private func modern(source: AVAudioFile, directory: URL, locale: Locale, progress: @escaping Progress,
                        consent: @escaping DownloadConsent, forceModelPrompt: Bool) async throws -> [LyricsRecognizedWord] {
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [],
            attributeOptions: [.audioTimeRange])
        let modules: [any SpeechModule] = [transcriber]
        let status = await AssetInventory.status(forModules: modules)
        guard status != .unsupported else { throw OnDeviceLyricsSyncError.unavailable }
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
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules, considering: source.processingFormat) else {
            throw OnDeviceLyricsSyncError.unavailable
        }
        progress("Preparing audio…")
        let converted = directory.appendingPathComponent("analysis.caf")
        try Self.convert(source, to: converted, format: format)
        let file = try AVAudioFile(forReading: converted)
        let analyzer = SpeechAnalyzer(modules: modules)
        return try await withTaskCancellationHandler(operation: {
            progress("Matching vocals on device…")
            try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
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
                return words
            } catch {
                await analyzer.cancelAndFinishNow()
                throw error
            }
        }, onCancel: {
            Task { await analyzer.cancelAndFinishNow() }
        })
    }

    private func legacy(source: AVAudioFile, directory: URL, locale: Locale, hints: [String],
                        progress: @escaping Progress) async throws -> [LyricsRecognizedWord] {
        let preferred = Locale.preferredLanguages.map(Locale.init(identifier:)).first { $0.languageCode == locale.languageCode }
        let locales = SFSpeechRecognizer.supportedLocales().filter { $0.languageCode == locale.languageCode }.sorted { $0.identifier < $1.identifier }
        let supported = locales.first { $0.regionCode == preferred?.regionCode } ??
            locales.first { $0.regionCode == Locale.current.regionCode } ??
            locales.first { $0.regionCode == (locale.languageCode == "en" ? "US" : "RU") } ?? locales.first
        guard let supported, let recognizer = SFSpeechRecognizer(locale: supported),
              recognizer.supportsOnDeviceRecognition else { throw OnDeviceLyricsSyncError.unavailable }
        let authorization: SFSpeechRecognizerAuthorizationStatus
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else { authorization = SFSpeechRecognizer.authorizationStatus() }
        guard authorization == .authorized else { throw OnDeviceLyricsSyncError.permission }
        try Task.checkCancellation()
        guard recognizer.isAvailable else { throw OnDeviceLyricsSyncError.unavailable }
        progress("Preparing audio…")
        let converted = directory.appendingPathComponent("analysis.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        try Self.convert(source, to: converted, format: format)
        let file = try AVAudioFile(forReading: converted)
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
        while true {
            try Task.checkCancellation()
            var error: NSError?
            output.frameLength = 0
            let status = converter.convert(to: output, error: &error) { requested, state in
                guard source.framePosition < source.length else { state.pointee = .endOfStream; return nil }
                do {
                    try source.read(into: input, frameCount: min(4_096, requested))
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
    }
}

/// Callback cancellation can race final recognition results; resume exactly once.
private final class LyricsRecognitionGate: @unchecked Sendable {
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
