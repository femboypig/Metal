//
//  AIDJEngine.swift
//  Krank
//

import AVFoundation
import QuartzCore

// MARK: - Local beat analysis

final class BeatDetector {
    private let analysisQueue = DispatchQueue(label: "net.femboypig.Krank.beat-analysis", qos: .utility)
    private let cacheQueue = DispatchQueue(label: "net.femboypig.Krank.beat-cache", attributes: .concurrent)
    private var bpmCache: [URL: Double] = [:]

    func prepare(_ url: URL) {
        guard cachedBPM(for: url) == nil else { return }

        analysisQueue.async { [weak self] in
            guard let self else { return }
            let bpm = Self.estimateBPM(for: url)
            self.cacheQueue.async(flags: .barrier) { [weak self] in
                self?.bpmCache[url] = bpm
            }
        }
    }

    func bpm(for url: URL) -> Double {
        cachedBPM(for: url) ?? 120
    }

    private func cachedBPM(for url: URL) -> Double? {
        cacheQueue.sync { bpmCache[url] }
    }

    private static func estimateBPM(for url: URL) -> Double {
        guard let file = try? AVAudioFile(forReading: url) else { return 120 }
        let format = file.processingFormat
        let framesToRead = min(file.length, Int64(format.sampleRate * 45))
        guard framesToRead > 2_048,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(framesToRead)
              ) else { return 120 }

        do {
            try file.read(into: buffer)
        } catch {
            return 120
        }

        guard let channels = buffer.floatChannelData else { return 120 }
        let channelCount = max(1, Int(format.channelCount))
        let sampleCount = Int(buffer.frameLength)
        let hopSize = 512
        guard sampleCount > hopSize * 4 else { return 120 }

        // A positive spectral-energy envelope is much more stable than counting
        // peaks above one fixed threshold (quiet masters otherwise read as 60 BPM).
        var envelope: [Double] = []
        var previousEnergy = 0.0
        var frameStart = 0
        while frameStart + hopSize < sampleCount {
            var energy = 0.0
            for channel in 0..<channelCount {
                let samples = channels[channel]
                for index in frameStart..<(frameStart + hopSize) {
                    let value = Double(samples[index])
                    energy += value * value
                }
            }
            energy = log1p(energy / Double(hopSize * channelCount))
            envelope.append(max(0, energy - previousEnergy))
            previousEnergy = energy
            frameStart += hopSize
        }

        guard envelope.count > 32 else { return 120 }
        let mean = envelope.reduce(0, +) / Double(envelope.count)
        envelope = envelope.map { max(0, $0 - mean * 0.5) }

        let framesPerSecond = format.sampleRate / Double(hopSize)
        let minimumLag = max(1, Int(framesPerSecond * 60 / 180))
        let maximumLag = min(envelope.count / 2, Int(framesPerSecond * 60 / 70))
        guard minimumLag < maximumLag else { return 120 }

        var bestLag = minimumLag
        var bestScore = -Double.infinity
        for lag in minimumLag...maximumLag {
            var score = 0.0
            for index in lag..<envelope.count {
                score += envelope[index] * envelope[index - lag]
            }

            // Prefer a musically plausible centre tempo when octave candidates tie.
            let bpm = 60 * framesPerSecond / Double(lag)
            let centreWeight = 1 - min(abs(bpm - 120) / 240, 0.18)
            score *= centreWeight
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }

        return 60 * framesPerSecond / Double(bestLag)
    }
}

// MARK: - Beat-aligned constant-power crossfade

final class AIDJTransitionCoordinator {
    private(set) var primaryPlayer: AVAudioPlayer?
    private(set) var secondaryPlayer: AVAudioPlayer?
    private(set) var isTransitioning = false

    private let beatDetector = BeatDetector()
    private var startWorkItem: DispatchWorkItem?
    private var fadeTimer: Timer?
    private var transitionVolume: Float = 1

    func prepare(track url: URL) {
        beatDetector.prepare(url)
    }

    @discardableResult
    func startTransition(
        from playerA: AVAudioPlayer,
        toTrack url: URL,
        onPlayStarted: @escaping (AVAudioPlayer) -> Void,
        completion: @escaping (AVAudioPlayer) -> Void
    ) -> Bool {
        guard !isTransitioning,
              playerA.isPlaying,
              let sourceURL = playerA.url,
              let playerB = try? AVAudioPlayer(contentsOf: url) else { return false }

        isTransitioning = true
        primaryPlayer = playerA
        secondaryPlayer = playerB
        transitionVolume = playerA.volume
        playerA.delegate = nil

        playerB.volume = 0
        playerB.prepareToPlay()

        let bpm = beatDetector.bpm(for: sourceURL)
        let beatDuration = 60 / max(70, min(180, bpm))
        let beatPosition = playerA.currentTime.truncatingRemainder(dividingBy: beatDuration)
        let startDelay = beatPosition < 0.035 ? 0 : beatDuration - beatPosition
        let remaining = max(0.5, playerA.duration - playerA.currentTime - startDelay)
        let requestedDuration = min(6, max(3, beatDuration * 8))
        let fadeDuration = min(requestedDuration, remaining)

        let workItem = DispatchWorkItem { [weak self, weak playerA, weak playerB] in
            guard let self, let playerA, let playerB, self.isTransitioning else { return }
            guard playerA.isPlaying else {
                self.cancel(keeping: playerA)
                return
            }

            playerB.play()
            onPlayStarted(playerB)
            self.beginCrossfade(
                from: playerA,
                to: playerB,
                targetVolume: self.transitionVolume,
                duration: fadeDuration,
                completion: completion
            )
        }
        startWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay, execute: workItem)
        return true
    }

    func cancel(keeping activePlayer: AVAudioPlayer?) {
        startWorkItem?.cancel()
        startWorkItem = nil
        fadeTimer?.invalidate()
        fadeTimer = nil

        if activePlayer == nil {
            primaryPlayer?.stop()
            secondaryPlayer?.stop()
        } else if activePlayer === secondaryPlayer {
            primaryPlayer?.stop()
            secondaryPlayer?.volume = transitionVolume
        } else {
            secondaryPlayer?.stop()
            primaryPlayer?.volume = transitionVolume
        }

        primaryPlayer = nil
        secondaryPlayer = nil
        isTransitioning = false
    }

    private func beginCrossfade(
        from playerA: AVAudioPlayer,
        to playerB: AVAudioPlayer,
        targetVolume: Float,
        duration: TimeInterval,
        completion: @escaping (AVAudioPlayer) -> Void
    ) {
        let startedAt = CACurrentMediaTime()
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self, weak playerA, weak playerB] timer in
            guard let self, let playerA, let playerB, self.isTransitioning else {
                timer.invalidate()
                return
            }

            let progress = min(1, (CACurrentMediaTime() - startedAt) / duration)
            let angle = progress * .pi / 2
            playerA.volume = targetVolume * Float(cos(angle))
            playerB.volume = targetVolume * Float(sin(angle))

            if progress >= 1 {
                timer.invalidate()
                self.fadeTimer = nil
                playerA.stop()
                playerB.volume = targetVolume
                self.primaryPlayer = nil
                self.secondaryPlayer = nil
                self.isTransitioning = false
                completion(playerB)
            }
        }
    }
}
