import UIKit

extension ViewController {
    var isContinuousMix: Bool { playbackSource == .dailyMix || playbackSource == .trackVibe }

    /// Starts from the song already playing, including its current position and pause state.
    func continueTrackVibe(from track: Track) {
        guard audioPlayer?.url == track.url else { return }
        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }
        audioPlayer?.delegate = self
        recordManualSelection(for: track)
        telemetrySessionWasManual = true
        playbackSource = .trackVibe
        vibeSeedFilename = track.url.lastPathComponent
        mixSessionRecentIDs = [track.url.lastPathComponent]
        lastMixExtensionAttempt = nil
        dailyMixID = UUID().uuidString
        playbackQueue = [track]
        currentTrackIndex = 0
        isRepeatEnabled = false
        currentPlaybackContext = "VIBE · \(track.title)"
        replaceMixUpcoming()
        playerHeaderLabel?.text = currentPlaybackContext
        updatePlayerOptionsMenu()
        updateNowPlayingInfo()
        updateMiniPlayerUI()
        savePlaybackState()
        UISelectionFeedbackGenerator().selectionChanged()
        UIAccessibility.post(notification: .announcement, argument: "Continuing the vibe of \(track.title). Current song keeps playing.")
    }

    /// Queue indices in actual playback order, including the shuffle history.
    private var mixPlaybackOrder: [Int] {
        let queue = currentQueue
        if isShuffleEnabled, shuffledIndices.count == queue.count,
           Set(shuffledIndices).count == queue.count,
           shuffledIndices.allSatisfy({ queue.indices.contains($0) }) {
            return shuffledIndices
        }
        return Array(queue.indices)
    }

    func playbackQueueSnapshot() -> PlaybackQueueSnapshot {
        let order = mixPlaybackOrder
        let queue = currentQueue
        return PlaybackQueueSnapshot(trackIDs: order.map { queue[$0].url.lastPathComponent },
            source: playbackSource.rawValue, context: currentPlaybackContext,
            seedTrackID: playbackSource == .trackVibe ? vibeSeedFilename : nil,
            currentIndex: mixPosition(in: order))
    }

    private func mixPosition(in order: [Int]) -> Int? {
        guard let index = currentTrackIndex else { return nil }
        return order.firstIndex(of: index)
    }

    private func nextMixTracks(reserving reserved: Set<String>) -> [Track] {
        let candidates = dailyMixCandidates()
        let previousID = currentPlaybackTrack()?.url.lastPathComponent
        let seedID = playbackSource == .trackVibe ? vibeSeedFilename : previousID
        let ids = MixSessionEngine.nextTracks(from: candidates, seedTrackID: seedID,
            previousTrackID: previousID, recentTrackIDs: mixSessionRecentIDs,
            reservedTrackIDs: reserved, randomSeed: UInt64.random(in: .min ... .max),
            mode: playbackSource == .dailyMix ? dailyMixMode : .forYou)
        let byID = Dictionary(tracks.map { ($0.url.lastPathComponent, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// Called before preloading, advancing and crossfading. Append only: current
    /// playback and already scheduled songs stay intact.
    func ensureMixContinuation(minimumUpcoming: Int = 3) {
        guard isContinuousMix, !playbackQueue.isEmpty, !isRepeatEnabled, sleepFadeTimer == nil,
              !aidj.isTransitioning, !isUpdatingMixQueue else { return }
        let order = mixPlaybackOrder
        guard let position = mixPosition(in: order), let current = currentPlaybackTrack() else { return }
        let remaining = order.dropFirst(position + 1)
        guard remaining.count <= minimumUpcoming else { return }
        let reserved = Set(remaining.map { playbackQueue[$0].url.lastPathComponent } + [current.url.lastPathComponent])
        let lastEvent = listeningTelemetry.sessions?.last?.timestamp ?? 0
        let attempt = "\(current.url.lastPathComponent)|\(reserved.sorted())|\(tracks.count)|\(dailyMixVibeCache.count)|\(lastEvent)|\(dailyMixMode.rawValue)"
        guard lastMixExtensionAttempt != attempt else { return }
        lastMixExtensionAttempt = attempt
        isUpdatingMixQueue = true
        defer { isUpdatingMixQueue = false }
        let added = nextMixTracks(reserving: reserved)
        guard !added.isEmpty else { return }
        let oldCount = playbackQueue.count
        playbackQueue.append(contentsOf: added)
        if isShuffleEnabled {
            shuffledIndices = order + Array(oldCount..<playbackQueue.count).shuffled()
            shuffledPosition = position
        }
        trimMixHistoryIfNeeded()
        publishMixQueueChange()
    }

    /// Used after explicit negative feedback or a shake in a track-vibe session.
    /// Preserve a useful Previous history while regenerating only upcoming songs.
    func replaceMixUpcoming() {
        guard isContinuousMix, let current = currentPlaybackTrack(), !isUpdatingMixQueue else { return }
        isUpdatingMixQueue = true
        defer { isUpdatingMixQueue = false }
        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }
        audioPlayer?.delegate = self
        if playbackQueue.isEmpty { playbackQueue = [current]; currentTrackIndex = 0 }
        lastMixExtensionAttempt = nil
        let order = mixPlaybackOrder
        let position = mixPosition(in: order)
        var history = position.map { p in order.prefix(p + 1).map { playbackQueue[$0] } } ?? [current]
        history = Array(history.suffix(21))
        if history.last?.url != current.url { history.append(current) }
        let added = nextMixTracks(reserving: [current.url.lastPathComponent])
        playbackQueue = history + added
        currentTrackIndex = history.count - 1
        if isShuffleEnabled {
            shuffledIndices = Array(history.indices) + Array(history.count..<playbackQueue.count).shuffled()
            shuffledPosition = history.count - 1
        }
        playbackPreparationGeneration += 1
        preparedPlayer = nil
        preparedPlayerURL = nil
        publishMixQueueChange()
        // Suppress recursive extension while preparing the newly chosen next song.
        prepareUpcomingTrack()
        updateCarouselArtworks(animated: true)
    }

    func continuousNextIndex(offset: Int = 1) -> Int? {
        guard isContinuousMix else { return nil }
        let order = mixPlaybackOrder
        guard let position = mixPosition(in: order), order.indices.contains(position + offset) else { return nil }
        return order[position + offset]
    }

    func stopAtMixEnd() {
        audioPlayer?.pause()
        updateTimer?.invalidate()
        playPauseButton?.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
        stopArtworkAnimation()
        updateNowPlayingInfo()
        updateMiniPlayerUI()
        savePlaybackState()
    }

    private func trimMixHistoryIfNeeded() {
        // Keep memory and saved settings bounded during very long sessions.
        guard playbackQueue.count > 96, queueSheetTable?.window == nil else { return }
        let order = mixPlaybackOrder
        guard let position = mixPosition(in: order), position > 20 else { return }
        let retained = Array(order.dropFirst(position - 20))
        playbackQueue = retained.map { playbackQueue[$0] }
        currentTrackIndex = 20
        if isShuffleEnabled {
            shuffledIndices = Array(playbackQueue.indices)
            shuffledPosition = 20
        }
    }

    private func publishMixQueueChange() {
        if playbackSource == .dailyMix {
            let order = mixPlaybackOrder
            if let position = mixPosition(in: order) {
                dailyMixTracks = order.dropFirst(position).map { playbackQueue[$0] }
            }
            if activeFilter == .dailyMix { filterTracks() }
        }
        queueSheetTable?.reloadData()
        queueSheetCountLabel?.text = "\(playbackQueue.count) songs in queue"
        savePlaybackState()
    }
}
