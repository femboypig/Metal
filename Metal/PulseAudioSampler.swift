import AVFoundation

struct PulseAudioSource {
    let url: URL
    let time: TimeInterval
    let weight: Float
    let bpm: Float
}

/// Decode bounded, overlapping four-second windows off the UI thread. Neither
/// AVAudioPlayer's audio path nor the device's microphone is changed or tapped.
final class PulseAudioSampler {
    private struct Window {
        let start: Double
        let step: Double
        let frames: [PulseAudioFrame]
        func frame(at time: Double) -> PulseAudioFrame? {
            let position = (time - start) / step
            guard position >= 0, position < Double(frames.count), !frames.isEmpty else { return nil }
            let index = Int(position)
            let next = min(index + 1, frames.count - 1)
            let fraction = Float(position - Double(index))
            return PulseAudioFrame.blend([(frames[index], 1 - fraction), (frames[next], fraction)])
        }
    }
    private let queue = DispatchQueue(label: "metal.pulse-audio", qos: .utility)
    private var windows: [URL: Window] = [:]
    private var files: [URL: AVAudioFile] = [:]

    func sample(_ sources: [PulseAudioSource], completion: @escaping (PulseAudioFrame) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let active = Set(sources.map(\.url))
            self.windows = self.windows.filter { active.contains($0.key) }
            self.files = self.files.filter { active.contains($0.key) }
            let frames = sources.map { source -> (PulseAudioFrame, Float) in
                if self.windows[source.url]?.frame(at: source.time) == nil {
                    self.windows[source.url] = self.read(source.url, at: source.time)
                }
                var frame = self.windows[source.url]?.frame(at: source.time) ?? PulseAudioFrame()
                frame.bpm = source.bpm.isFinite ? min(200, max(50, source.bpm)) : 120
                return (frame, source.weight)
            }
            let result = PulseAudioFrame.blend(frames)
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func read(_ url: URL, at time: Double) -> Window? {
        do {
            let file: AVAudioFile
            if let existing = files[url] { file = existing }
            else {
                file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
                files[url] = file
            }
            let rate = file.processingFormat.sampleRate
            guard rate > 0, time.isFinite else { return nil }
            let start = max(0, floor(time / 2) * 2 - 0.1)
            let position = min(file.length, AVAudioFramePosition(start * rate))
            let length = min(Int64(rate * 4.2), file.length - position)
            guard length > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(length)) else { return nil }
            file.framePosition = position
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else { return nil }
            let channelCount = min(2, Int(buffer.format.channelCount))
            guard channelCount > 0 else { return nil }
            var analyzers = (0..<channelCount).map { _ in PulseBandAnalyzer(sampleRate: rate) }
            var frames: [PulseAudioFrame] = []
            frames.reserveCapacity(Int(buffer.frameLength) / 1024)
            for index in 0..<Int(buffer.frameLength) {
                var bands: [(PulseAudioFrame, Float)] = []
                for channel in 0..<channelCount {
                    if let frame = analyzers[channel].consume(Double(channels[channel][index])) {
                        bands.append((frame, 1))
                    }
                }
                if !bands.isEmpty { frames.append(PulseAudioFrame.blend(bands)) }
            }
            return Window(start: Double(position) / rate, step: 1024 / rate, frames: frames)
        } catch { return nil }
    }
}
