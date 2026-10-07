//
//  AudioVibeAnalyzer.swift
//  Metal
//

import AVFoundation
import Foundation

struct CachedAudioVibe: Codable, Equatable {
    let fileSize: Int
    let modificationDate: TimeInterval
    let profile: AudioVibeProfile
}

struct AudioVibeCacheDocument: Codable {
    var version = 1
    var tracks: [String: CachedAudioVibe] = [:]
}

final class AudioVibeAnalyzer {
    private let queue = DispatchQueue(label: "net.femboypig.Metal.daily-vibe", qos: .utility)

    func analyze(
        urls: [URL],
        cached: [String: CachedAudioVibe],
        completion: @escaping ([String: CachedAudioVibe]) -> Void
    ) {
        queue.async {
            var result: [String: CachedAudioVibe] = [:]
            for url in urls {
                let filename = url.lastPathComponent
                let signature = Self.fileSignature(for: url)
                if let existing = cached[filename],
                   existing.fileSize == signature.fileSize,
                   existing.modificationDate == signature.modificationDate {
                    result[filename] = existing
                    continue
                }

                guard let profile = Self.profile(for: url) else { continue }
                result[filename] = CachedAudioVibe(
                    fileSize: signature.fileSize,
                    modificationDate: signature.modificationDate,
                    profile: profile
                )
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func fileSignature(for url: URL) -> (fileSize: Int, modificationDate: TimeInterval) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return (values?.fileSize ?? -1, values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
    }

    private static func profile(for url: URL) -> AudioVibeProfile? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let framesToRead = min(file.length, Int64(format.sampleRate * 15))
        guard framesToRead > 4_096,
              framesToRead <= Int64(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(framesToRead)
              ) else { return nil }

        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }

        guard let channels = buffer.floatChannelData else { return nil }
        let channelCount = max(1, Int(format.channelCount))
        let sampleCount = Int(buffer.frameLength)
        let hopSize = 1_024
        guard sampleCount > hopSize * 8 else { return nil }

        var onsetEnvelope: [Double] = []
        var windowRMSValues: [Double] = []
        var previousEnergy = 0.0
        var zeroCrossings = 0
        var previousMono = 0.0
        var hasPreviousMono = false
        var frameStart = 0

        while frameStart + hopSize < sampleCount {
            var sumSquares = 0.0
            for index in frameStart..<(frameStart + hopSize) {
                var mono = 0.0
                for channel in 0..<channelCount {
                    let sample = Double(channels[channel][index])
                    mono += sample
                    sumSquares += sample * sample
                }
                mono /= Double(channelCount)
                if hasPreviousMono,
                   abs(mono) > 0.000_5,
                   abs(previousMono) > 0.000_5,
                   (mono >= 0) != (previousMono >= 0) {
                    zeroCrossings += 1
                }
                previousMono = mono
                hasPreviousMono = true
            }

            let meanSquare = sumSquares / Double(hopSize * channelCount)
            let rms = sqrt(max(0, meanSquare))
            windowRMSValues.append(rms)
            let logEnergy = log1p(meanSquare * 1_000)
            onsetEnvelope.append(max(0, logEnergy - previousEnergy))
            previousEnergy = logEnergy
            frameStart += hopSize
        }

        guard !windowRMSValues.isEmpty else { return nil }
        let meanRMS = windowRMSValues.reduce(0, +) / Double(windowRMSValues.count)
        let variance = windowRMSValues.reduce(0) { partial, value in
            partial + (value - meanRMS) * (value - meanRMS)
        } / Double(windowRMSValues.count)
        let decibels = 20 * log10(max(meanRMS, 0.000_1))
        let energy = clamp((decibels + 45) / 40)
        let crossingRate = Double(zeroCrossings) / Double(max(1, sampleCount - 1))
        let brightness = clamp(crossingRate / 0.18)
        let dynamics = clamp(sqrt(variance) / max(meanRMS, 0.000_1) / 0.8)

        return AudioVibeProfile(
            bpm: estimateBPM(envelope: onsetEnvelope, sampleRate: format.sampleRate, hopSize: hopSize),
            energy: energy,
            brightness: brightness,
            dynamics: dynamics,
            musicalKey: estimateMusicalKey(channels: channels, channelCount: channelCount, sampleCount: sampleCount, sampleRate: format.sampleRate)
        )
    }

    private static func estimateMusicalKey(
        channels: UnsafePointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        sampleCount: Int,
        sampleRate: Double
    ) -> Int {
        guard sampleRate > 8_000, sampleCount > 4_096 else { return -1 }
        let step = max(1, sampleCount / 8_192)
        var chromaEnergies = [Double](repeating: 0, count: 12)

        for key in 0..<12 {
            let baseFreq = 220.0 * pow(2.0, Double(key - 9) / 12.0)
            let octaveFreq = baseFreq * 2.0
            var real1 = 0.0
            var imag1 = 0.0
            var real2 = 0.0
            var imag2 = 0.0
            let omega1 = 2.0 * .pi * baseFreq / sampleRate
            let omega2 = 2.0 * .pi * octaveFreq / sampleRate

            var i = 0
            while i < sampleCount {
                var mono = 0.0
                for c in 0..<channelCount {
                    mono += Double(channels[c][i])
                }
                mono /= Double(channelCount)

                let t = Double(i)
                real1 += mono * cos(omega1 * t)
                imag1 += mono * sin(omega1 * t)
                real2 += mono * cos(omega2 * t)
                imag2 += mono * sin(omega2 * t)
                i += step
            }

            chromaEnergies[key] = (real1 * real1 + imag1 * imag1) + (real2 * real2 + imag2 * imag2)
        }

        guard let maxEnergy = chromaEnergies.max(), maxEnergy > 0.000_1 else { return -1 }
        let meanEnergy = chromaEnergies.reduce(0, +) / 12.0
        guard maxEnergy > meanEnergy * 1.25 else { return -1 }
        return chromaEnergies.firstIndex(of: maxEnergy) ?? -1
    }

    private static func estimateBPM(
        envelope: [Double],
        sampleRate: Double,
        hopSize: Int
    ) -> Double {
        guard envelope.count > 32 else { return 120 }
        let mean = envelope.reduce(0, +) / Double(envelope.count)
        let centered = envelope.map { max(0, $0 - mean * 0.5) }
        let framesPerSecond = sampleRate / Double(hopSize)
        let minimumLag = max(1, Int(framesPerSecond * 60 / 180))
        let maximumLag = min(centered.count / 2, Int(framesPerSecond * 60 / 70))
        guard minimumLag < maximumLag else { return 120 }

        var bestLag = minimumLag
        var bestScore = -Double.infinity
        for lag in minimumLag...maximumLag {
            var score = 0.0
            for index in lag..<centered.count {
                score += centered[index] * centered[index - lag]
            }
            let bpm = 60 * framesPerSecond / Double(lag)
            score *= 1 - min(abs(bpm - 120) / 240, 0.18)
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }
        return 60 * framesPerSecond / Double(bestLag)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
