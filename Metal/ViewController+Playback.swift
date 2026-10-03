//
//  ViewController+Playback.swift
//  Metal
//

import UIKit
import AVFoundation
import MediaPlayer

extension ViewController {

    // MARK: - Core Audio Setup

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to configure Audio Session: \(error)")
        }
    }

    @discardableResult
    func activateAudioSessionIfNeeded() -> Bool {
        guard !isAudioSessionActive else { return true }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            isAudioSessionActive = true
            return true
        } catch {
            print("Failed to activate Audio Session: \(error)")
            return false
        }
    }

    func deactivateAudioSessionIfIdle() {
        guard isAudioSessionActive, audioPlayer?.isPlaying != true else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
        } catch {
            print("Failed to deactivate Audio Session: \(error)")
        }
    }

    func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.likeCommand.removeTarget(nil)

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.audioPlayer?.isPlaying != true { self.playOrPause() }
            }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.audioPlayer != nil else { return .noSuchContent }
            DispatchQueue.main.async {
                if self.audioPlayer?.isPlaying == true { self.playOrPause() }
            }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            DispatchQueue.main.async { self.playOrPause() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self, !self.currentQueue.isEmpty else { return .noSuchContent }
            DispatchQueue.main.async { self.playNextTrack() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self, !self.currentQueue.isEmpty else { return .noSuchContent }
            DispatchQueue.main.async { self.playPreviousTrack() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent,
                  self.audioPlayer != nil else { return .noSuchContent }
            DispatchQueue.main.async {
                self.seek(to: positionEvent.positionTime)
            }
            return .success
        }

        commandCenter.likeCommand.isEnabled = false
        commandCenter.likeCommand.localizedTitle = "Favorite"
        commandCenter.likeCommand.localizedShortTitle = "Favorite"
        commandCenter.likeCommand.addTarget { [weak self] _ in
            guard let self, self.currentPlaybackTrack() != nil else { return .noSuchContent }
            DispatchQueue.main.async {
                guard let track = self.currentPlaybackTrack() else { return }
                self.toggleFavorite(track: track)
            }
            return .success
        }
    }

    var currentQueue: [Track] {
        if !playbackQueue.isEmpty {
            return playbackQueue
        }
        return !filteredTracks.isEmpty ? filteredTracks : tracks
    }

    func currentPlaybackTrack() -> Track? {
        guard let url = audioPlayer?.url else { return nil }
        return tracks.first { $0.url == url }
    }

    func updateRemoteFavoriteCommand() {
        let command = MPRemoteCommandCenter.shared().likeCommand
        guard let track = currentPlaybackTrack() else {
            command.isActive = false
            command.isEnabled = false
            return
        }
        command.isEnabled = true
        command.isActive = favoriteTracks.contains(track.url.lastPathComponent)
    }

    // MARK: - Playback Core Engine

    func playTrackFromWidget(filename: String) {
        activeFilter = .all
        searchBar.text = ""
        filterTracks()

        guard let index = filteredTracks.firstIndex(where: { $0.url.lastPathComponent == filename }) else {
            showToast(message: "This song is no longer in your library", success: false)
            return
        }

        playbackQueue = filteredTracks
        currentPlaybackContext = "ALL SONGS"
        recordManualSelection(for: filteredTracks[index])
        currentTrackIndex = index
        if isShuffleEnabled {
            rebuildShuffleQueue()
        }
        playCurrentTrack()
        rebuildFiltersRow()
        tableView.reloadData()

        DispatchQueue.main.async { [weak self] in
            guard let self, self.scrollView.bounds.width > 0 else { return }
            self.scrollView.setContentOffset(
                CGPoint(x: self.scrollView.bounds.width * 2, y: 0),
                animated: true
            )
        }
    }

    func playCurrentTrack() {
        let queue = currentQueue
        guard !queue.isEmpty, let index = currentTrackIndex, index < queue.count else { return }

        let track = queue[index]
        playerHeaderLabel?.text = currentPlaybackContext
        let savedPosition = persistedSettings.lastTrackFile == track.url.lastPathComponent
            ? persistedSettings.playbackPosition
            : 0

        if aidj.isTransitioning { aidj.cancel(keeping: nil) }
        if let previousPlayer = audioPlayer, telemetrySessionFilename != nil {
            updateListeningTelemetry(with: previousPlayer)
            let progress = previousPlayer.duration > 0
                ? previousPlayer.currentTime / previousPlayer.duration
                : 0
            finishListeningTelemetry(
                completed: progress >= 0.85,
                skipped: progress < 0.85 && previousPlayer.currentTime > 1,
                progress: progress
            )
        }
        audioPlayer?.stop()
        audioPlayer = nil

        guard activateAudioSessionIfNeeded() else { return }

        do {
            if preparedPlayerURL == track.url, let readyPlayer = preparedPlayer {
                audioPlayer = readyPlayer
                preparedPlayer = nil
                preparedPlayerURL = nil
            } else {
                playbackPreparationGeneration += 1
                preparedPlayer = nil
                preparedPlayerURL = nil
                audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            }
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            if let player = audioPlayer {
                player.currentTime = savedPosition < player.duration - 1
                    ? min(max(0, savedPosition), player.duration)
                    : 0
                lastSavedPlaybackBucket = Int(player.currentTime) / 30
            }
            audioPlayer?.play()
            startListeningTelemetry(for: track, resumed: (audioPlayer?.currentTime ?? 0) > 1)
            aidj.prepare(track: track.url, knownBPM: dailyMixVibeCache[track.url.lastPathComponent]?.profile.bpm)
            prepareUpcomingTrack()

            let playbackImpact = UIImpactFeedbackGenerator(style: .medium)
            playbackImpact.prepare()
            playbackImpact.impactOccurred()

            startTimer()

            // Full UI updating
            playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
            trackTitleLabel.text = track.title

            // Artist label handling (hiding if empty or unknown)
            if track.artist != "Unknown Artist" && !track.artist.isEmpty {
                artistLabel.text = track.artist
                artistLabel.isHidden = false
            } else {
                artistLabel.text = ""
                artistLabel.isHidden = true
            }

            updateCarouselArtworks(animated: false)

            progressSlider.maximumValue = Float(track.duration)
            progressSlider.value = Float(audioPlayer?.currentTime ?? 0)
            elapsedLabel.text = formatTime(audioPlayer?.currentTime ?? 0)
            remainingLabel.text = "-" + formatTime(max(0, track.duration - (audioPlayer?.currentTime ?? 0)))

            startArtworkAnimation()
            updateNowPlayingInfo()
            tableView.reloadData()

            updateMiniPlayerUI()
            updatePlayerFavoriteButton()
            updateRemoteFavoriteCommand()
            updatePlayerTheme(with: track.artwork)

            // Scroll to full player page ONLY if we are not already on the player page
            let width = scrollView.bounds.width
            if width > 0 {
                let currentPage = Int(round(scrollView.contentOffset.x / width))
                if currentPage != 2 {
                    scrollView.setContentOffset(CGPoint(x: width * 2, y: 0), animated: true)
                }
            }

        } catch {
            print("Audio Player playback error: \(error)")
            showToast(message: "Playback failed", success: false)
        }
    }

    func playOrPause() {
        guard let player = audioPlayer else {
            let queue = currentQueue
            if !queue.isEmpty {
                if currentTrackIndex == nil {
                    currentTrackIndex = 0
                }
                playCurrentTrack()
            }
            return
        }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()

        if aidj.isTransitioning { aidj.cancel(keeping: player) }

        if player.isPlaying {
            updateListeningTelemetry(with: player)
            player.pause()
            updateTimer?.invalidate()
            savePlaybackState()
            stopArtworkAnimation()
            playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
            deactivateAudioSessionIfIdle()
        } else {
            guard activateAudioSessionIfNeeded() else { return }
            player.play()
            startTimer()
            startArtworkAnimation()
            playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
        }

        updateNowPlayingInfo()
        updateMiniPlayerUI()
    }

    // MARK: - Playback Queue Navigation

    func rebuildShuffleQueue() {
        let count = currentQueue.count
        guard count > 0 else { return }

        var indices = Array(0..<count)
        if let currentIdx = currentTrackIndex, currentIdx < count {
            indices.remove(at: currentIdx)
            indices.shuffle()
            shuffledIndices = [currentIdx] + indices
            shuffledPosition = 0
        } else {
            indices.shuffle()
            shuffledIndices = indices
            shuffledPosition = 0
        }
    }

    @objc func playNextTrack() {
        let queue = currentQueue
        guard !queue.isEmpty else { return }
        guard !isCarouselAnimating else { return }

        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }

        if isPlayerPageVisible && queue.count > 1 {
            let nextTrack = getNextTrack()
            let trackAfterNext = getTrackAfterNext()
            if nextTrack != nil {
                animateCarouselSlide(direction: .forward, incomingTrack: trackAfterNext)
            }
        }

        forcePlayNextTrack()
    }

    func forcePlayNextTrack() {
        let queue = currentQueue
        guard !queue.isEmpty else { return }
        if isShuffleEnabled {
            if shuffledIndices.isEmpty {
                rebuildShuffleQueue()
            }

            if shuffledPosition >= shuffledIndices.count - 1 {
                if isRepeatEnabled {
                    rebuildShuffleQueue()
                } else {
                    shuffledPosition = 0
                }
            } else {
                shuffledPosition += 1
            }

            if shuffledPosition < shuffledIndices.count {
                currentTrackIndex = shuffledIndices[shuffledPosition]
                playCurrentTrack()
            }
        } else {
            if let index = currentTrackIndex {
                currentTrackIndex = (index + 1) % queue.count
            } else {
                currentTrackIndex = 0
            }
            playCurrentTrack()
        }
    }

    func transitionToNextTrack() {
        let queue = currentQueue
        guard !queue.isEmpty, let currentPlayer = audioPlayer else {
            forcePlayNextTrack()
            return
        }

        currentPlayer.delegate = nil // Stop delegating so old player stops quietly

        // Find next track index
        let nextIndex: Int
        if isShuffleEnabled {
            if shuffledIndices.isEmpty {
                rebuildShuffleQueue()
            }
            var nextPos = shuffledPosition
            if nextPos >= shuffledIndices.count - 1 {
                nextPos = 0
            } else {
                nextPos += 1
            }
            nextIndex = shuffledIndices[nextPos]
        } else {
            if let index = currentTrackIndex {
                nextIndex = (index + 1) % queue.count
            } else {
                nextIndex = 0
            }
        }

        guard nextIndex < queue.count else {
            forcePlayNextTrack()
            return
        }

        let nextTrack = queue[nextIndex]

        let didStart = aidj.startTransition(from: currentPlayer, toTrack: nextTrack.url, onPlayStarted: { [weak self] playerB in
            guard let self else { return }
            self.updateListeningTelemetry(with: currentPlayer)
            let completedProgress = currentPlayer.duration > 0
                ? currentPlayer.currentTime / currentPlayer.duration
                : 1
            self.finishListeningTelemetry(completed: true, skipped: false, progress: completedProgress)
            self.audioPlayer = playerB
            self.audioPlayer?.delegate = self
            self.currentTrackIndex = nextIndex
            self.playerHeaderLabel?.text = self.currentPlaybackContext
            self.startListeningTelemetry(for: nextTrack, resumed: false)

            if self.isShuffleEnabled {
                if self.shuffledPosition >= self.shuffledIndices.count - 1 {
                    self.shuffledPosition = 0
                } else {
                    self.shuffledPosition += 1
                }
            }

            // Full UI updating
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
            self.trackTitleLabel.text = nextTrack.title

            if nextTrack.artist != "Unknown Artist" && !nextTrack.artist.isEmpty {
                self.artistLabel.text = nextTrack.artist
                self.artistLabel.isHidden = false
            } else {
                self.artistLabel.text = ""
                self.artistLabel.isHidden = true
            }

            self.updateCarouselArtworks(animated: true)

            self.progressSlider.maximumValue = Float(nextTrack.duration)
            self.progressSlider.value = 0

            self.startArtworkAnimation()
            self.updateNowPlayingInfo()
            self.tableView.reloadData()

            self.updateMiniPlayerUI()
            self.updatePlayerFavoriteButton()
            self.updateRemoteFavoriteCommand()
            self.updatePlayerTheme(with: nextTrack.artwork)
            self.aidj.prepare(track: nextTrack.url, knownBPM: self.dailyMixVibeCache[nextTrack.url.lastPathComponent]?.profile.bpm)
            self.prepareUpcomingTrack()
        }, completion: { [weak self] playerB in
            guard let self, self.audioPlayer === playerB else { return }
            self.updateNowPlayingInfo()
        })

        if !didStart {
            forcePlayNextTrack()
        }
    }

    @objc func playPreviousTrack() {
        let queue = currentQueue
        guard !queue.isEmpty else { return }
        guard !isCarouselAnimating else { return }

        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }

        if isPlayerPageVisible && queue.count > 1 {
            let prevTrack = getPreviousTrack()
            let trackBeforePrev = getTrackBeforePrevious()
            if prevTrack != nil {
                animateCarouselSlide(direction: .backward, incomingTrack: trackBeforePrev)
            }
        }

        if isShuffleEnabled {
            if shuffledIndices.isEmpty {
                rebuildShuffleQueue()
            }

            if shuffledPosition > 0 {
                shuffledPosition -= 1
            } else {
                shuffledPosition = shuffledIndices.count - 1
            }

            if shuffledPosition < shuffledIndices.count {
                currentTrackIndex = shuffledIndices[shuffledPosition]
                playCurrentTrack()
            }
        } else {
            if let index = currentTrackIndex {
                currentTrackIndex = (index - 1 + queue.count) % queue.count
            } else {
                currentTrackIndex = 0
            }
            playCurrentTrack()
        }
    }

    // MARK: - Playback Timer & Actions

    func startTimer() {
        updateTimer?.invalidate()
        let interval: TimeInterval = UIApplication.shared.applicationState == .active ? 0.1 : 1.0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePlaybackProgress()
        }
        timer.tolerance = interval * 0.12
        updateTimer = timer
    }

    func updatePlaybackProgress() {
        guard let player = audioPlayer, player.duration > 0 else { return }

        updateListeningTelemetry(with: player)

        if UIApplication.shared.applicationState == .active {
            if !progressSlider.isTracking {
                progressSlider.value = Float(player.currentTime)
            }
            elapsedLabel.text = formatTime(player.currentTime)
            remainingLabel.text = "-" + formatTime(player.duration - player.currentTime)
        }

        let playbackBucket = Int(player.currentTime) / 30
        if playbackBucket != lastSavedPlaybackBucket {
            lastSavedPlaybackBucket = playbackBucket
            saveListeningTelemetry()
            savePlaybackState()
        }

        let aidjEnabled = UserDefaults.standard.bool(forKey: "Metal_AIDJEnabled")
        if aidjEnabled && !isRepeatEnabled && player.duration - player.currentTime <= 7.0 && player.duration > 14.0 && !aidj.isTransitioning {
            transitionToNextTrack()
        }
    }

    @objc func sliderValueChanging(_ sender: UISlider) {
        elapsedLabel.text = formatTime(TimeInterval(sender.value))
        if let player = audioPlayer {
            remainingLabel.text = "-" + formatTime(player.duration - TimeInterval(sender.value))
        }
    }

    @objc func sliderFinishedChanging(_ sender: UISlider) {
        seek(to: TimeInterval(sender.value))
    }

    func seek(to requestedTime: TimeInterval) {
        guard let player = audioPlayer, player.duration > 0 else { return }
        if aidj.isTransitioning { aidj.cancel(keeping: player) }

        updateListeningTelemetry(with: player)

        let position = min(max(0, requestedTime), player.duration)
        player.currentTime = position
        progressSlider.value = Float(position)
        elapsedLabel.text = formatTime(position)
        remainingLabel.text = "-" + formatTime(max(0, player.duration - position))
        savePlaybackState()
        updateNowPlayingInfo()
    }

    @objc func playPauseTapped() {
        playOrPause()
    }

    @objc func shuffleTapped() {
        isShuffleEnabled.toggle()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    @objc func repeatTapped() {
        isRepeatEnabled.toggle()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    @objc func dismissPlayerTapped() {
        let width = scrollView.frame.size.width
        scrollView.setContentOffset(CGPoint(x: width, y: 0), animated: true)
    }

    @objc func dislikeTapped() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        playNextTrack()
        showToast(message: "Skipped song", success: true)
    }

    @objc func deviceButtonTapped() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        showToast(message: "Output: iPhone Speaker / AirPlay", success: true)
    }

    @objc func shareButtonTapped() {
        let queue = currentQueue
        guard let track = currentPlaybackTrack() ?? (currentTrackIndex.flatMap { queue.indices.contains($0) ? queue[$0] : nil }) else { return }
        let shareVC = UIActivityViewController(activityItems: [track.url], applicationActivities: nil)
        present(shareVC, animated: true)
    }

    @objc func queueButtonTapped() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        let queue = currentQueue
        let items = queue.prefix(15).map { tr in
            BottomSheetItem(title: tr.title, iconName: "music.note", isDestructive: false, action: { [weak self] in
                if let idx = self?.currentQueue.firstIndex(where: { $0.url == tr.url }) {
                    self?.recordManualSelection(for: tr)
                    self?.currentTrackIndex = idx
                    self?.playCurrentTrack()
                }
            })
        }
        presentCustomBottomSheet(title: "Up Next Queue", subtitle: "\(queue.count) songs in queue", items: Array(items))
    }

    @objc func volumeSliderChanged(_ sender: UISlider) {
        audioPlayer?.volume = sender.value
    }

    func updatePlaybackButtons() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let activeColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
        let inactiveColor = isDark ? UIColor.white.withAlphaComponent(0.4) : UIColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.6)
        shuffleButton?.tintColor = isShuffleEnabled ? activeColor : inactiveColor
        repeatButton?.tintColor = isRepeatEnabled ? activeColor : inactiveColor
        updateWavePlayingState()
    }

    struct PlayerArtworkPalette {
        let topColor: UIColor
        let bottomColor: UIColor
        let waveColor: UIColor
    }

    func fallbackPalette(for trackTitle: String?, isDark: Bool) -> PlayerArtworkPalette {
        guard let title = trackTitle, !title.isEmpty else {
            let base = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
            if isDark {
                return PlayerArtworkPalette(
                    topColor: UIColor(hue: 0.04, saturation: 0.65, brightness: 0.35, alpha: 1.0),
                    bottomColor: UIColor(hue: 0.04, saturation: 0.25, brightness: 0.06, alpha: 1.0),
                    waveColor: base
                )
            } else {
                return PlayerArtworkPalette(
                    topColor: UIColor(hue: 0.04, saturation: 0.18, brightness: 0.96, alpha: 1.0),
                    bottomColor: UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0),
                    waveColor: base
                )
            }
        }
        let hash = abs(title.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        if isDark {
            return PlayerArtworkPalette(
                topColor: UIColor(hue: hue, saturation: 0.65, brightness: 0.38, alpha: 1.0),
                bottomColor: UIColor(hue: hue, saturation: 0.30, brightness: 0.06, alpha: 1.0),
                waveColor: UIColor(hue: hue, saturation: 0.80, brightness: 0.75, alpha: 1.0)
            )
        } else {
            return PlayerArtworkPalette(
                topColor: UIColor(hue: hue, saturation: 0.18, brightness: 0.96, alpha: 1.0),
                bottomColor: UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0),
                waveColor: UIColor(hue: hue, saturation: 0.75, brightness: 0.65, alpha: 1.0)
            )
        }
    }

    func fallbackTrackColor(for trackTitle: String?) -> UIColor {
        fallbackPalette(for: trackTitle, isDark: traitCollection.userInterfaceStyle == .dark).waveColor
    }

    func updatePlayerTheme(with artwork: UIImage?) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let queue = currentQueue
        let trackTitle: String? = {
            if let current = currentPlaybackTrack() {
                return current.title
            }
            if let index = currentTrackIndex, index < queue.count {
                return queue[index].title
            }
            return nil
        }()

        let palette: PlayerArtworkPalette
        if let art = artwork {
            palette = art.extractPlayerPalette(isDark: isDark)
        } else {
            palette = fallbackPalette(for: trackTitle, isDark: isDark)
        }

        currentDominantColor = palette.topColor
        myWaveView?.setThemeColor(palette.waveColor)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        playerGradientLayer?.colors = [palette.topColor.cgColor, palette.bottomColor.cgColor]
        CATransaction.commit()

        updatePlayerControlsTheme(isDark: isDark)

        if let sv = scrollView, sv.bounds.width > 0, sv.contentOffset.x >= sv.bounds.width * 1.5 {
            view.backgroundColor = palette.topColor
            scrollView.backgroundColor = palette.topColor
            setNeedsStatusBarAppearanceUpdate()
        }
    }


    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        updateListeningTelemetry(with: player)
        finishListeningTelemetry(completed: true, skipped: false, progress: 1)
        if isRepeatEnabled {
            player.currentTime = 0
            savePlaybackState()
            playCurrentTrack()
        } else {
            playNextTrack()
        }
    }

    func prepareUpcomingTrack() {
        let queue = currentQueue
        guard let index = currentTrackIndex,
              !queue.isEmpty else { return }

        let nextIndex: Int
        if isShuffleEnabled, !shuffledIndices.isEmpty, shuffledPosition + 1 < shuffledIndices.count {
            nextIndex = shuffledIndices[shuffledPosition + 1]
        } else {
            nextIndex = (index + 1) % queue.count
        }
        guard nextIndex < queue.count else { return }
        let url = queue[nextIndex].url
        Track.preheatArtwork(for: [url])
        guard preparedPlayerURL != url else { return }

        playbackPreparationGeneration += 1
        let generation = playbackPreparationGeneration
        playbackPreparationQueue.async { [weak self] in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.prepareToPlay()
            DispatchQueue.main.async {
                guard let self,
                      generation == self.playbackPreparationGeneration,
                      self.audioPlayer?.url != url else { return }
                self.preparedPlayer = player
                self.preparedPlayerURL = url
            }
        }
    }

    @objc func trackArtworkDidLoad(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        tableView.reloadData()
        guard audioPlayer?.url == url, let track = currentPlaybackTrack(), let artwork = track.artwork else {
            scheduleWidgetRecommendationsPublish()
            return
        }
        coverImageView.image = artwork
        miniCoverView.image = artwork
        updatePlayerTheme(with: artwork)
        updateNowPlayingInfo()
        scheduleWidgetRecommendationsPublish()
    }

    // MARK: - Cover Art Carousel

    func getPreviousTrack() -> Track? {
        let queue = currentQueue
        guard !queue.isEmpty else { return nil }
        if isShuffleEnabled {
            guard !shuffledIndices.isEmpty else { return nil }
            if shuffledPosition > 0 {
                let idx = shuffledIndices[shuffledPosition - 1]
                if idx < queue.count { return queue[idx] }
            } else if isRepeatEnabled && shuffledIndices.count > 1 {
                let idx = shuffledIndices[shuffledIndices.count - 1]
                if idx < queue.count { return queue[idx] }
            }
            return nil
        } else {
            guard let idx = currentTrackIndex else { return nil }
            if idx > 0 && idx - 1 < queue.count {
                return queue[idx - 1]
            } else if isRepeatEnabled && queue.count > 1 {
                return queue[queue.count - 1]
            }
            return nil
        }
    }

    func getNextTrack() -> Track? {
        let queue = currentQueue
        guard !queue.isEmpty else { return nil }
        if isShuffleEnabled {
            guard !shuffledIndices.isEmpty else { return nil }
            if shuffledPosition < shuffledIndices.count - 1 {
                let idx = shuffledIndices[shuffledPosition + 1]
                if idx < queue.count { return queue[idx] }
            } else if isRepeatEnabled && shuffledIndices.count > 1 {
                let idx = shuffledIndices[0]
                if idx < queue.count { return queue[idx] }
            }
            return nil
        } else {
            guard let idx = currentTrackIndex else {
                return queue.first
            }
            if idx < queue.count - 1 {
                return queue[idx + 1]
            } else if isRepeatEnabled && queue.count > 1 {
                return queue[0]
            }
            return nil
        }
    }

    func getTrackAfterNext() -> Track? {
        let queue = currentQueue
        guard !queue.isEmpty else { return nil }
        if isShuffleEnabled {
            guard !shuffledIndices.isEmpty else { return nil }
            if shuffledPosition < shuffledIndices.count - 2 {
                let idx = shuffledIndices[shuffledPosition + 2]
                if idx < queue.count { return queue[idx] }
            } else if isRepeatEnabled && queue.count >= 2 {
                let wrappedPos = (shuffledPosition + 2) % shuffledIndices.count
                let idx = shuffledIndices[wrappedPos]
                if idx < queue.count { return queue[idx] }
            }
            return nil
        } else {
            guard let idx = currentTrackIndex else { return nil }
            if idx < queue.count - 2 {
                return queue[idx + 2]
            } else if isRepeatEnabled && queue.count >= 2 {
                let wrappedIdx = (idx + 2) % queue.count
                return queue[wrappedIdx]
            }
            return nil
        }
    }

    func getTrackBeforePrevious() -> Track? {
        let queue = currentQueue
        guard !queue.isEmpty else { return nil }
        if isShuffleEnabled {
            guard !shuffledIndices.isEmpty else { return nil }
            if shuffledPosition >= 2 {
                let idx = shuffledIndices[shuffledPosition - 2]
                if idx < queue.count { return queue[idx] }
            } else if isRepeatEnabled && queue.count >= 2 {
                let wrappedPos = (shuffledPosition - 2 + shuffledIndices.count) % shuffledIndices.count
                let idx = shuffledIndices[wrappedPos]
                if idx < queue.count { return queue[idx] }
            }
            return nil
        } else {
            guard let idx = currentTrackIndex else { return nil }
            if idx >= 2 && idx - 2 < queue.count {
                return queue[idx - 2]
            } else if isRepeatEnabled && queue.count >= 2 {
                let wrappedIdx = (idx - 2 + queue.count) % queue.count
                return queue[wrappedIdx]
            }
            return nil
        }
    }

    func updateCarouselArtworks(animated: Bool = false) {
        guard isViewLoaded, !isCarouselAnimating else { return }

        let queue = currentQueue
        let currentTrack: Track?
        if let current = currentPlaybackTrack() {
            currentTrack = current
        } else if let idx = currentTrackIndex, idx >= 0, idx < queue.count {
            currentTrack = queue[idx]
        } else {
            currentTrack = nil
        }

        let prevTrack = getPreviousTrack()
        let nextTrack = getNextTrack()

        let defaultPlaceholder = UIImage(named: "PlaceholderArtwork")

        let applyImages = {
            self.coverImageView?.image = currentTrack?.artwork ?? defaultPlaceholder
            if let prev = prevTrack {
                self.leftCoverCard?.isHidden = false
                self.leftCoverImageView?.image = prev.artwork ?? defaultPlaceholder
            } else {
                self.leftCoverCard?.isHidden = true
            }

            if let next = nextTrack {
                self.rightCoverCard?.isHidden = false
                self.rightCoverImageView?.image = next.artwork ?? defaultPlaceholder
            } else {
                self.rightCoverCard?.isHidden = true
            }
        }

        if animated, let container = coverCarouselContainer {
            UIView.transition(with: container, duration: 0.28, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                applyImages()
            }, completion: nil)
        } else {
            applyImages()
        }
    }

    func applyCarouselLayout(isPlaying: Bool, animated: Bool) {
        guard isViewLoaded, !isCarouselAnimating,
              let coverArtCard = coverArtCard,
              let leftCoverCard = leftCoverCard,
              let rightCoverCard = rightCoverCard else { return }

        let baseCardSize: CGFloat = 264
        let playingScale: CGFloat = 1.18
        let gap: CGFloat = 16

        let baseOffset = baseCardSize + gap
        let expansion = (baseCardSize * (playingScale - 1.0)) / 2.0

        let leftTargetTransform: CGAffineTransform
        let rightTargetTransform: CGAffineTransform
        let centerTargetTransform: CGAffineTransform
        let centerShadowRadius: CGFloat
        let centerShadowOpacity: Float

        if isPlaying {
            centerTargetTransform = CGAffineTransform(scaleX: playingScale, y: playingScale)
            leftTargetTransform = CGAffineTransform(translationX: -(baseOffset + expansion), y: 0)
            rightTargetTransform = CGAffineTransform(translationX: (baseOffset + expansion), y: 0)
            centerShadowRadius = 20
            centerShadowOpacity = 0.40
        } else {
            centerTargetTransform = .identity
            leftTargetTransform = CGAffineTransform(translationX: -baseOffset, y: 0)
            rightTargetTransform = CGAffineTransform(translationX: baseOffset, y: 0)
            centerShadowRadius = 12
            centerShadowOpacity = 0.28
        }

        let updates = {
            coverArtCard.transform = centerTargetTransform
            leftCoverCard.transform = leftTargetTransform
            rightCoverCard.transform = rightTargetTransform
            coverArtCard.layer.shadowRadius = centerShadowRadius
            coverArtCard.layer.shadowOpacity = centerShadowOpacity
            coverArtCard.alpha = 1.0
            self.coverDimOverlay?.alpha = 0.0
            leftCoverCard.alpha = 0.55
            self.leftCoverDimOverlay?.alpha = 1.0
            rightCoverCard.alpha = 0.55
            self.rightCoverDimOverlay?.alpha = 1.0
        }

        if animated {
            UIView.animate(
                withDuration: 0.45,
                delay: 0,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.2,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: updates
            )
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updates()
            CATransaction.commit()
        }
    }

    enum CarouselSlideDirection {
        case forward
        case backward
    }

    func animateCarouselSlide(direction: CarouselSlideDirection, incomingTrack: Track?) {
        guard isViewLoaded,
              let container = coverCarouselContainer,
              let coverArtCard = coverArtCard,
              let leftCoverCard = leftCoverCard,
              let rightCoverCard = rightCoverCard else { return }

        isCarouselAnimating = true

        let screenWidth = page2?.bounds.width ?? (view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width)
        let baseCardSize: CGFloat = 264
        let playingScale: CGFloat = 1.18
        let gap: CGFloat = 16

        let baseOffset = baseCardSize + gap
        let expansion = (baseCardSize * (playingScale - 1.0)) / 2.0
        let isPlaying = audioPlayer?.isPlaying == true
        let sideOffset = isPlaying ? (baseOffset + expansion) : baseOffset
        let centerScale: CGFloat = isPlaying ? playingScale : 1.0

        let incomingCard = UIView()
        incomingCard.backgroundColor = .black
        incomingCard.layer.cornerRadius = 18
        incomingCard.layer.cornerCurve = .continuous
        incomingCard.layer.borderWidth = 0.5
        incomingCard.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        incomingCard.layer.shadowColor = UIColor.black.cgColor
        incomingCard.layer.shadowOpacity = 0.25
        incomingCard.layer.shadowRadius = 12
        incomingCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        incomingCard.clipsToBounds = false
        incomingCard.layer.zPosition = 1

        let containerWidth = container.bounds.width > 0 ? container.bounds.width : screenWidth
        let containerHeight = container.bounds.height > 0 ? container.bounds.height : 336
        incomingCard.frame = CGRect(
            x: (containerWidth - baseCardSize) / 2.0,
            y: (containerHeight - baseCardSize) / 2.0,
            width: baseCardSize,
            height: baseCardSize
        )

        let incomingImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: baseCardSize, height: baseCardSize))
        incomingImageView.contentMode = .scaleAspectFill
        incomingImageView.layer.cornerRadius = 18
        incomingImageView.layer.cornerCurve = .continuous
        incomingImageView.clipsToBounds = true
        incomingImageView.image = incomingTrack?.artwork ?? UIImage(named: "PlaceholderArtwork")
        incomingCard.addSubview(incomingImageView)

        let incomingDim = UIView(frame: CGRect(x: 0, y: 0, width: baseCardSize, height: baseCardSize))
        incomingDim.backgroundColor = UIColor.black.withAlphaComponent(0.20)
        incomingDim.layer.cornerRadius = 18
        incomingDim.layer.cornerCurve = .continuous
        incomingDim.clipsToBounds = true
        incomingCard.addSubview(incomingDim)

        container.addSubview(incomingCard)

        switch direction {
        case .forward:
            incomingCard.alpha = 0.0
            incomingCard.transform = CGAffineTransform(translationX: sideOffset + baseCardSize, y: 0)

            rightCoverCard.layer.zPosition = 3
            coverArtCard.layer.zPosition = 2
            leftCoverCard.layer.zPosition = 1

            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.2,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    leftCoverCard.transform = CGAffineTransform(translationX: -(sideOffset + baseCardSize), y: 0)
                    leftCoverCard.alpha = 0.0

                    coverArtCard.transform = CGAffineTransform(translationX: -sideOffset, y: 0)
                    coverArtCard.alpha = 0.55
                    self.coverDimOverlay?.alpha = 1.0
                    coverArtCard.layer.shadowRadius = 12
                    coverArtCard.layer.shadowOpacity = 0.25

                    rightCoverCard.transform = CGAffineTransform(scaleX: centerScale, y: centerScale)
                    rightCoverCard.alpha = 1.0
                    self.rightCoverDimOverlay?.alpha = 0.0
                    rightCoverCard.layer.shadowRadius = isPlaying ? 20 : 12
                    rightCoverCard.layer.shadowOpacity = isPlaying ? 0.40 : 0.28

                    incomingCard.transform = CGAffineTransform(translationX: sideOffset, y: 0)
                    incomingCard.alpha = incomingTrack != nil ? 0.55 : 0.0
                },
                completion: { [weak self] _ in
                    guard let self else { return }
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)

                    incomingCard.removeFromSuperview()
                    self.coverArtCard.layer.zPosition = 2
                    self.leftCoverCard.layer.zPosition = 1
                    self.rightCoverCard.layer.zPosition = 1
                    self.isCarouselAnimating = false
                    self.updateCarouselArtworks(animated: false)
                    self.applyCarouselLayout(isPlaying: self.audioPlayer?.isPlaying == true, animated: false)

                    CATransaction.commit()
                }
            )

        case .backward:
            incomingCard.alpha = 0.0
            incomingCard.transform = CGAffineTransform(translationX: -(sideOffset + baseCardSize), y: 0)

            leftCoverCard.layer.zPosition = 3
            coverArtCard.layer.zPosition = 2
            rightCoverCard.layer.zPosition = 1

            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.2,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    rightCoverCard.transform = CGAffineTransform(translationX: sideOffset + baseCardSize, y: 0)
                    rightCoverCard.alpha = 0.0

                    coverArtCard.transform = CGAffineTransform(translationX: sideOffset, y: 0)
                    coverArtCard.alpha = 0.55
                    self.coverDimOverlay?.alpha = 1.0
                    coverArtCard.layer.shadowRadius = 12
                    coverArtCard.layer.shadowOpacity = 0.25

                    leftCoverCard.transform = CGAffineTransform(scaleX: centerScale, y: centerScale)
                    leftCoverCard.alpha = 1.0
                    self.leftCoverDimOverlay?.alpha = 0.0
                    leftCoverCard.layer.shadowRadius = isPlaying ? 20 : 12
                    leftCoverCard.layer.shadowOpacity = isPlaying ? 0.40 : 0.28

                    incomingCard.transform = CGAffineTransform(translationX: -sideOffset, y: 0)
                    incomingCard.alpha = incomingTrack != nil ? 0.55 : 0.0
                },
                completion: { [weak self] _ in
                    guard let self else { return }
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)

                    incomingCard.removeFromSuperview()
                    self.coverArtCard.layer.zPosition = 2
                    self.leftCoverCard.layer.zPosition = 1
                    self.rightCoverCard.layer.zPosition = 1
                    self.isCarouselAnimating = false
                    self.updateCarouselArtworks(animated: false)
                    self.applyCarouselLayout(isPlaying: self.audioPlayer?.isPlaying == true, animated: false)

                    CATransaction.commit()
                }
            )
        }
    }
}

fileprivate extension UIImage {
    func extractVibrantColor() -> UIColor? {
        extractPlayerPalette(isDark: true).waveColor
    }

    func extractPlayerPalette(isDark: Bool) -> ViewController.PlayerArtworkPalette {
        let width = 36
        let height = 36
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return defaultMonochromePalette(isDark: isDark, avgLuminance: 0.5)
        }

        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        guard let data = context.data else {
            return defaultMonochromePalette(isDark: isDark, avgLuminance: 0.5)
        }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var totalValidPixels = 0
        var sumLuminance: CGFloat = 0
        var sumR: CGFloat = 0
        var sumG: CGFloat = 0
        var sumB: CGFloat = 0
        var sumSat: CGFloat = 0

        var darkPixelsCount = 0
        var lightNeutralCount = 0
        var neutralCount = 0
        var chromaticCount = 0

        let numBins = 16
        var binCounts = [Int](repeating: 0, count: numBins)
        var binSumR = [CGFloat](repeating: 0, count: numBins)
        var binSumG = [CGFloat](repeating: 0, count: numBins)
        var binSumB = [CGFloat](repeating: 0, count: numBins)
        var binSumSat = [CGFloat](repeating: 0, count: numBins)
        var binSumBr = [CGFloat](repeating: 0, count: numBins)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let alpha = CGFloat(ptr[offset + 3]) / 255.0
                if alpha < 0.5 { continue }

                let r = CGFloat(ptr[offset]) / 255.0
                let g = CGFloat(ptr[offset + 1]) / 255.0
                let b = CGFloat(ptr[offset + 2]) / 255.0

                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: &a)

                totalValidPixels += 1
                sumLuminance += luminance
                sumR += r
                sumG += g
                sumB += b
                sumSat += s

                let isDarkPixel = br < 0.18 || luminance < 0.16
                let isLightPixel = br > 0.82 && s < 0.22
                let isNeutralPixel = s < 0.16

                if isDarkPixel { darkPixelsCount += 1 }
                if isLightPixel { lightNeutralCount += 1 }
                if isNeutralPixel || isDarkPixel || isLightPixel { neutralCount += 1 }

                if s >= 0.18 && br >= 0.14 && br <= 0.96 {
                    chromaticCount += 1
                    var bin = Int(h * CGFloat(numBins))
                    if bin >= numBins { bin = numBins - 1 }
                    binCounts[bin] += 1
                    binSumR[bin] += r
                    binSumG[bin] += g
                    binSumB[bin] += b
                    binSumSat[bin] += s
                    binSumBr[bin] += br
                }
            }
        }

        guard totalValidPixels > 0 else {
            return defaultMonochromePalette(isDark: isDark, avgLuminance: 0.5)
        }

        let totalF = CGFloat(totalValidPixels)
        let avgLuminance = sumLuminance / totalF
        let avgR = sumR / totalF
        let avgG = sumG / totalF
        let avgB = sumB / totalF
        let darkFraction = CGFloat(darkPixelsCount) / totalF
        let lightFraction = CGFloat(lightNeutralCount) / totalF
        let neutralFraction = CGFloat(neutralCount) / totalF
        let chromaticFraction = CGFloat(chromaticCount) / totalF

        struct ColorCluster {
            let hue: CGFloat
            let saturation: CGFloat
            let brightness: CGFloat
            let fraction: CGFloat
            let score: CGFloat
        }

        var clusters: [ColorCluster] = []
        for i in 0..<numBins {
            let count = binCounts[i]
            guard count > 0 else { continue }
            let frac = CGFloat(count) / totalF
            let meanS = binSumSat[i] / CGFloat(count)
            let meanBr = binSumBr[i] / CGFloat(count)
            let meanH = (CGFloat(i) + 0.5) / CGFloat(numBins)

            let score = frac * 2.5 + meanS * 1.2 + (1.0 - abs(meanBr - 0.55)) * 0.5
            clusters.append(ColorCluster(
                hue: meanH,
                saturation: meanS,
                brightness: meanBr,
                fraction: frac,
                score: score
            ))
        }

        clusters.sort { $0.score > $1.score }

        // --- CASE 1: Pure or near-monochrome artwork (White cover, Black cover, Grayscale) ---
        let primaryCluster = clusters.first
        let isMonochrome = chromaticFraction < 0.06 || (primaryCluster?.fraction ?? 0) < 0.04 || neutralFraction >= 0.88

        if isMonochrome {
            return makeMonochromePalette(isDark: isDark, avgLuminance: avgLuminance, avgR: avgR, avgG: avgG, avgB: avgB)
        }

        guard let primary = primaryCluster else {
            return makeMonochromePalette(isDark: isDark, avgLuminance: avgLuminance, avgR: avgR, avgG: avgG, avgB: avgB)
        }

        // --- CASE 2: Dark Artwork with Small Accent (e.g. 80% black with a bit of red/blue/yellow) ---
        if darkFraction >= 0.60 && primary.fraction < 0.35 {
            let accentWeight = min(max(primary.fraction / 0.35, 0.15), 0.60)
            let s = min(primary.saturation * accentWeight, 0.38)

            if isDark {
                let b = min(max(primary.brightness * 0.35, 0.11), 0.19)
                let top = UIColor(hue: primary.hue, saturation: s, brightness: b, alpha: 1.0)
                let bottom = UIColor(hue: primary.hue, saturation: s * 0.35, brightness: 0.045, alpha: 1.0)
                let wave = UIColor(hue: primary.hue, saturation: min(primary.saturation, 0.90), brightness: 0.82, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            } else {
                let top = UIColor(hue: primary.hue, saturation: s * 0.22, brightness: 0.95, alpha: 1.0)
                let bottom = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
                let wave = UIColor(hue: primary.hue, saturation: min(primary.saturation, 0.85), brightness: 0.70, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            }
        }

        // --- CASE 3: Light/White Artwork with a Colored Accent (e.g. White cover with colored logo/art) ---
        if lightFraction >= 0.50 && primary.fraction < 0.35 {
            let accentWeight = min(max(primary.fraction / 0.35, 0.20), 0.65)
            let s = min(primary.saturation * accentWeight, 0.42)

            if isDark {
                let b = min(max(primary.brightness * 0.40, 0.15), 0.26)
                let top = UIColor(hue: primary.hue, saturation: s, brightness: b, alpha: 1.0)
                let bottom = UIColor(hue: primary.hue, saturation: s * 0.30, brightness: 0.06, alpha: 1.0)
                let wave = UIColor(hue: primary.hue, saturation: min(primary.saturation, 0.88), brightness: 0.82, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            } else {
                let top = UIColor(hue: primary.hue, saturation: min(primary.saturation * 0.18, 0.15), brightness: 0.96, alpha: 1.0)
                let bottom = UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1.0)
                let wave = UIColor(hue: primary.hue, saturation: min(primary.saturation, 0.80), brightness: 0.70, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            }
        }

        // --- CASE 4: Truly Colorful / Chromatic Artwork ---
        let secondary = clusters.dropFirst().first { other in
            let hueDiff = abs(other.hue - primary.hue)
            let circularDiff = min(hueDiff, 1.0 - hueDiff)
            return circularDiff >= 0.10 && other.fraction >= 0.10
        }

        if isDark {
            let s = min(max(primary.saturation * 0.95, 0.45), 0.82)
            let b = min(max(primary.brightness * 0.72, 0.26), 0.46)
            let top = UIColor(hue: primary.hue, saturation: s, brightness: b, alpha: 1.0)

            let bottom: UIColor
            if let sec = secondary {
                let s2 = min(sec.saturation * 0.50, 0.35)
                let b2 = min(max(sec.brightness * 0.14, 0.045), 0.08)
                bottom = UIColor(hue: sec.hue, saturation: s2, brightness: b2, alpha: 1.0)
            } else {
                bottom = UIColor(hue: primary.hue, saturation: min(s * 0.45, 0.30), brightness: 0.065, alpha: 1.0)
            }

            let wave = UIColor(hue: primary.hue, saturation: min(primary.saturation * 1.05, 0.92), brightness: 0.82, alpha: 1.0)
            return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
        } else {
            let s = min(primary.saturation * 0.28, 0.22)
            let top = UIColor(hue: primary.hue, saturation: s, brightness: 0.95, alpha: 1.0)
            let bottom = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
            let wave = UIColor(hue: primary.hue, saturation: min(primary.saturation, 0.85), brightness: 0.65, alpha: 1.0)
            return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
        }
    }

    private func makeMonochromePalette(isDark: Bool, avgLuminance: CGFloat, avgR: CGFloat, avgG: CGFloat, avgB: CGFloat) -> ViewController.PlayerArtworkPalette {
        let isLightArtwork = avgLuminance > 0.60
        let isWarm = avgR > avgB + 0.03
        let isCool = avgB > avgR + 0.03

        if isDark {
            if isLightArtwork {
                let top: UIColor
                if isWarm {
                    top = UIColor(red: 0.18, green: 0.17, blue: 0.16, alpha: 1.0)
                } else if isCool {
                    top = UIColor(red: 0.15, green: 0.16, blue: 0.19, alpha: 1.0)
                } else {
                    top = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
                }
                let bottom = UIColor(red: 0.055, green: 0.055, blue: 0.065, alpha: 1.0)
                let wave = UIColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            } else {
                let top: UIColor
                if isWarm {
                    top = UIColor(red: 0.12, green: 0.11, blue: 0.11, alpha: 1.0)
                } else if isCool {
                    top = UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
                } else {
                    top = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                }
                let bottom = UIColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1.0)
                let wave = UIColor(red: 0.68, green: 0.70, blue: 0.76, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            }
        } else {
            if isLightArtwork {
                let top: UIColor
                if isWarm {
                    top = UIColor(red: 0.95, green: 0.94, blue: 0.93, alpha: 1.0)
                } else if isCool {
                    top = UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1.0)
                } else {
                    top = UIColor(red: 0.94, green: 0.94, blue: 0.95, alpha: 1.0)
                }
                let bottom = UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1.0)
                let wave = UIColor(red: 0.50, green: 0.52, blue: 0.58, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            } else {
                let top = UIColor(red: 0.88, green: 0.89, blue: 0.91, alpha: 1.0)
                let bottom = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
                let wave = UIColor(red: 0.40, green: 0.42, blue: 0.46, alpha: 1.0)
                return ViewController.PlayerArtworkPalette(topColor: top, bottomColor: bottom, waveColor: wave)
            }
        }
    }

    private func defaultMonochromePalette(isDark: Bool, avgLuminance: CGFloat) -> ViewController.PlayerArtworkPalette {
        makeMonochromePalette(isDark: isDark, avgLuminance: avgLuminance, avgR: 0.5, avgG: 0.5, avgB: 0.5)
    }
}
