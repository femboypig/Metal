import Foundation
import AVFoundation

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
        print("Native audio resampling, stereo downmix, exact Speech input format and preserved time origin passed")
    }
}
