//
//  ViewController+Playback.swift
//  Metal
//

import UIKit
import AVFoundation
import MediaPlayer

extension ViewController {

    // MARK: - Core Audio Setup

    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to configure Audio Session: \(error)")
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
            guard let self, !self.filteredTracks.isEmpty else { return .noSuchContent }
            DispatchQueue.main.async { self.playNextTrack() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self, !self.filteredTracks.isEmpty else { return .noSuchContent }
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
    }

    // MARK: - Playback Core Engine

    func playCurrentTrack() {
        guard !filteredTracks.isEmpty, let index = currentTrackIndex, index < filteredTracks.count else { return }

        let track = filteredTracks[index]
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

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            if let player = audioPlayer {
                player.currentTime = savedPosition < player.duration - 1
                    ? min(max(0, savedPosition), player.duration)
                    : 0
                lastSavedPlaybackBucket = Int(player.currentTime) / 5
            }
            audioPlayer?.play()
            startListeningTelemetry(for: track, resumed: (audioPlayer?.currentTime ?? 0) > 1)
            aidj.prepare(track: track.url)

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

            if let artwork = track.artwork {
                coverImageView.image = artwork
            } else {
                coverImageView.image = UIImage(named: "logo")
            }

            progressSlider.maximumValue = Float(track.duration)
            progressSlider.value = Float(audioPlayer?.currentTime ?? 0)
            elapsedLabel.text = formatTime(audioPlayer?.currentTime ?? 0)
            remainingLabel.text = "-" + formatTime(max(0, track.duration - (audioPlayer?.currentTime ?? 0)))

            startArtworkAnimation()
            updateNowPlayingInfo()
            tableView.reloadData()

            updateMiniPlayerUI()
            updatePlayerFavoriteButton()
            updatePlayerTheme(with: track.artwork)

            // Scroll to full player page ONLY if we are not already on the player page
            let width = scrollView.frame.size.width
            let currentPage = Int(round(scrollView.contentOffset.x / width))
            if currentPage != 2 {
                scrollView.setContentOffset(CGPoint(x: width * 2, y: 0), animated: true)
            }

        } catch {
            print("Audio Player playback error: \(error)")
            showToast(message: "Playback failed", success: false)
        }
    }

    func playOrPause() {
        guard let player = audioPlayer else {
            if !filteredTracks.isEmpty {
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
        } else {
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
        let count = filteredTracks.count
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
        guard !filteredTracks.isEmpty else { return }

        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }

        forcePlayNextTrack()
    }

    func forcePlayNextTrack() {
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
                currentTrackIndex = (index + 1) % filteredTracks.count
            } else {
                currentTrackIndex = 0
            }
            playCurrentTrack()
        }
    }

    func transitionToNextTrack() {
        guard !filteredTracks.isEmpty, let currentPlayer = audioPlayer else {
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
                nextIndex = (index + 1) % filteredTracks.count
            } else {
                nextIndex = 0
            }
        }

        let nextTrack = filteredTracks[nextIndex]

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

            if let artwork = nextTrack.artwork {
                self.coverImageView.image = artwork
            } else {
                self.coverImageView.image = UIImage(named: "logo")
            }

            self.progressSlider.maximumValue = Float(nextTrack.duration)
            self.progressSlider.value = 0

            self.startArtworkAnimation()
            self.updateNowPlayingInfo()
            self.tableView.reloadData()

            self.updateMiniPlayerUI()
            self.updatePlayerFavoriteButton()
            self.updatePlayerTheme(with: nextTrack.artwork)
            self.aidj.prepare(track: nextTrack.url)
        }, completion: { [weak self] playerB in
            guard let self, self.audioPlayer === playerB else { return }
            self.updateNowPlayingInfo()
        })

        if !didStart {
            forcePlayNextTrack()
        }
    }

    @objc func playPreviousTrack() {
        guard !filteredTracks.isEmpty else { return }

        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }

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
                currentTrackIndex = (index - 1 + filteredTracks.count) % filteredTracks.count
            } else {
                currentTrackIndex = 0
            }
            playCurrentTrack()
        }
    }

    // MARK: - Playback Timer & Actions

    func startTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackProgress()
        }
    }

    func updatePlaybackProgress() {
        guard let player = audioPlayer, player.duration > 0 else { return }

        updateListeningTelemetry(with: player)

        if !progressSlider.isTracking {
            progressSlider.value = Float(player.currentTime)
        }

        elapsedLabel.text = formatTime(player.currentTime)
        remainingLabel.text = "-" + formatTime(player.duration - player.currentTime)

        let playbackBucket = Int(player.currentTime) / 5
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
        guard let index = currentTrackIndex, index < filteredTracks.count else { return }
        let track = filteredTracks[index]
        let shareVC = UIActivityViewController(activityItems: [track.url], applicationActivities: nil)
        present(shareVC, animated: true)
    }

    @objc func queueButtonTapped() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        let items = filteredTracks.prefix(15).map { tr in
            BottomSheetItem(title: tr.title, iconName: "music.note", isDestructive: false, action: { [weak self] in
                if let idx = self?.filteredTracks.firstIndex(where: { $0.url == tr.url }) {
                    self?.recordManualSelection(for: tr)
                    self?.currentTrackIndex = idx
                    self?.playCurrentTrack()
                }
            })
        }
        presentCustomBottomSheet(title: "Up Next Queue", subtitle: "\(filteredTracks.count) songs in filter", items: Array(items))
    }

    @objc func volumeSliderChanged(_ sender: UISlider) {
        audioPlayer?.volume = sender.value
    }

    func updatePlaybackButtons() {
        let activeColor = UIColor.white
        let inactiveColor = UIColor.white.withAlphaComponent(0.4)
        shuffleButton?.tintColor = isShuffleEnabled ? activeColor : inactiveColor
        repeatButton?.tintColor = isRepeatEnabled ? activeColor : inactiveColor
    }

    func updatePlayerTheme(with artwork: UIImage?) {
        let dominantColor = artwork?.averageColor() ?? UIColor(red: 0.28, green: 0.08, blue: 0.08, alpha: 1.0)
        let bottomColor = UIColor(red: 0.08, green: 0.04, blue: 0.04, alpha: 1.0)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        playerGradientLayer?.colors = [dominantColor.cgColor, bottomColor.cgColor]
        CATransaction.commit()
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
}

fileprivate extension UIImage {
    func averageColor() -> UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                    y: inputImage.extent.origin.y,
                                    z: inputImage.extent.size.width,
                                    w: inputImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        var r = CGFloat(bitmap[0]) / 255.0
        var g = CGFloat(bitmap[1]) / 255.0
        var b = CGFloat(bitmap[2]) / 255.0

        let maxComp = max(r, max(g, b))
        if maxComp > 0.45 {
            let factor = 0.45 / maxComp
            r *= factor
            g *= factor
            b *= factor
        }

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
