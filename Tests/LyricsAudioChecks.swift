import Foundation
import AVFoundation
import AudioToolbox
import Speech

@main struct LyricsAudioChecks {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("source.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        do {
            let file = try AVAudioFile(forWriting: original, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
            buffer.frameLength = 44_100
            for channel in 0..<2 {
                for frame in 0..<44_100 {
                    let time = Double(frame) / 44_100
                    buffer.floatChannelData![channel][frame] = time < 0.25 ? 0 : Float(sin(time * 440 * 2 * .pi) * 0.3)
                }
            }
            try file.write(from: buffer)
        }
        let source = try AVAudioFile(forReading: original)
        let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: false)!
        let converted = try OnDeviceLyricsSync.prepareAudio(source, directory: directory, format: target)
        precondition(converted.processingFormat.commonFormat == .pcmFormatInt16)
        precondition(converted.processingFormat.sampleRate == 16_000 && converted.processingFormat.channelCount == 1)
        precondition(abs(Double(converted.length) / 16_000 - 1) < 0.005)
        let samples = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(converted.length))!
        try converted.read(into: samples)
        let signal = samples.int16ChannelData![0]
        let onset = (0..<Int(samples.frameLength)).first { abs(Int(signal[$0])) > 100 }!
        precondition(abs(Double(onset) / 16_000 - 0.25) < 0.005, "Resampling must preserve the audio time origin")
        // Both successful short reads and eofErr may carry the final samples.
        let eofBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 16)!
        let partialEOF = try OnDeviceLyricsSync.readAudioFrames(into: eofBuffer) {
            eofBuffer.frameLength = 7
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioFileEndOfFileError))
        }
        precondition(partialEOF && eofBuffer.frameLength == 7, "EOF must preserve final partial samples")
        let emptyEOF = try OnDeviceLyricsSync.readAudioFrames(into: eofBuffer) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioFileEndOfFileError))
        }
        precondition(emptyEOF && eofBuffer.frameLength == 0, "EOF must not replay an earlier buffer")
        do {
            _ = try OnDeviceLyricsSync.readAudioFrames(into: eofBuffer) {
                throw NSError(domain: NSOSStatusErrorDomain, code: -50)
            }
            preconditionFailure("Non-EOF decoder errors must not be swallowed")
        } catch { precondition((error as NSError).code == -50) }

        if #available(iOS 26.0, macOS 26.0, *) {
            var frameCount = 0, bufferCount = 0
            for try await input in LyricsAudioInput(url: converted.url, commonFormat: target.commonFormat, interleaved: false) {
                precondition(input.buffer.frameLength > 0 && input.buffer.frameLength <= 4096)
                precondition(abs(CMTimeGetSeconds(input.bufferStartTime!) - Double(frameCount) / 16000) < 0.000001)
                frameCount += Int(input.buffer.frameLength); bufferCount += 1
            }
            precondition(frameCount == Int(converted.length) && bufferCount == 4, "Streaming must deliver the final short buffer exactly once")
            var iterator = LyricsAudioInput(url: converted.url, commonFormat: target.commonFormat, interleaved: false).makeAsyncIterator()
            while try await iterator.next() != nil { }
            let afterEOF = try await iterator.next()
            precondition(afterEOF == nil, "An exhausted sequence must stay exhausted")
        }

        for filename in ["lyrics-tone-vbr.mp3", "lyrics-tone-aac.m4a"] {
            let compressed = try AVAudioFile(forReading: URL(fileURLWithPath: "Tests/Fixtures/Audio/" + filename))
            let prepared = try OnDeviceLyricsSync.prepareAudio(compressed, directory: directory, format: target)
            precondition(abs(Double(prepared.length) / 16000 - 2.73) < 0.12, "Compressed audio must decode through EOF: " + filename)
            let decoded = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(prepared.length))!
            try prepared.read(into: decoded)
            let pcm = decoded.int16ChannelData![0]
            let signalStart = (0..<Int(decoded.frameLength)).first { abs(Int(pcm[$0])) > 100 }!
            precondition(abs(Double(signalStart) / 16000 - 0.25) < 0.06, "Compressed audio time origin must survive decoding")
            print("Compressed native decode passed: " + filename)
        }
        let hints = OnDeviceLyricsSync.recognitionHints(["Тихий ветер", "Тихий ветер", "", String(repeating: "я", count: 200)])
        precondition(hints == ["Тихий ветер"], "Context must use bounded, deduplicated existing lyrics")
        let cancelled = LyricsRecognitionGate()
        do {
            let _: [LyricsRecognizedWord] = try await withCheckedThrowingContinuation { continuation in
                precondition(cancelled.prepare(continuation))
                cancelled.cancel(); cancelled.finish(.success([]))
            }
            preconditionFailure("Late recognition callbacks must not override cancellation")
        } catch is CancellationError { }
        let completed = LyricsRecognitionGate()
        let result: [LyricsRecognizedWord] = try await withCheckedThrowingContinuation { continuation in
            precondition(completed.prepare(continuation))
            completed.finish(.success([])); completed.cancel()
        }
        precondition(result.isEmpty)
        print("Native audio resampling, stereo downmix, exact Speech input format and preserved time origin, EOF recovery and bounded Speech input passed")
    }
}
