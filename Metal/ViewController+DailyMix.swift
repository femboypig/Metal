//
//  ViewController+DailyMix.swift
//  Metal
//

import UIKit

extension ViewController {
    var dailyMixVibeCacheURL: URL {
        metalRootDirectoryURL.appendingPathComponent("daily-mix-vibes.json")
    }

    func loadDailyMixVibeCache() {
        guard let data = try? Data(contentsOf: dailyMixVibeCacheURL),
              let document = try? JSONDecoder().decode(AudioVibeCacheDocument.self, from: data) else {
            dailyMixVibeCache = [:]
            return
        }
        dailyMixVibeCache = document.tracks
    }

    func prepareDailyMixVibes() {
        let urls = tracks.map(\.url)
        dailyMixVibeAnalyzer.analyze(urls: urls, cached: dailyMixVibeCache) { [weak self] result in
            guard let self else { return }
            let changed = result != self.dailyMixVibeCache
            self.dailyMixVibeCache = result
            self.saveDailyMixVibeCache()
            guard changed else { return }
            self.refreshDailyMixIfNeeded(force: true)
            self.scheduleWidgetRecommendationsPublish()
        }
    }

    private func saveDailyMixVibeCache() {
        let document = AudioVibeCacheDocument(tracks: dailyMixVibeCache)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(document) else { return }
        try? data.write(to: dailyMixVibeCacheURL, options: .atomic)
    }

    func refreshDailyMixIfNeeded(force: Bool = false, now: Date = Date(), allowPlaying: Bool = false, remix: Bool = false) {
        let dayKey = DailyMixEngine.dayKey(for: now)
        guard force || dailyMixBucket != dayKey else { return }
        // Background analysis must not replace a queue that is being played.
        if !allowPlaying, playbackSource == .dailyMix, audioPlayer?.isPlaying == true,
           dailyMixBucket == dayKey { return }

        let timestamp = now.timeIntervalSince1970
        let calendar = Calendar.autoupdatingCurrent
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let events = Dictionary(grouping: listeningTelemetry.sessions ?? [], by: \.filename)
        let recentSession = (listeningTelemetry.sessions ?? []).suffix(24).filter {
            timestamp - $0.timestamp < 30 * 60 && $0.reward != 0
        }
        let previousIDs = Set(dailyMixTracks.map { $0.url.lastPathComponent })
        let candidates = tracks.map { track -> DailyMixCandidate in
            let filename = track.url.lastPathComponent
            let telemetry = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()
            var affinity = 0.0
            var rejection = 0.0
            for event in events[filename] ?? [] {
                let ageDays = max(0, timestamp - event.timestamp) / 86_400
                let recency = exp(-ageDays / 14)
                let hourDelta = abs(hour - event.hour)
                let distance = min(hourDelta, 24 - hourDelta)
                let timeFit = exp(-Double(distance * distance) / 18)
                let dayFit = (weekday == event.weekday) ? 1.0 : 0.65
                let positive = max(0, event.reward)
                affinity += positive * recency * (0.25 + 0.75 * timeFit * dayFit)
                if event.isRejection {
                    rejection += exp(-ageDays / 3) * (event.reason == .dislike ? 1 : 0.55) * (1 - event.engagement)
                }
            }
            // Existing installations can learn time-of-day preferences before
            // the richer session journal has accumulated enough observations.
            if events[filename] == nil {
                for playedAt in telemetry.recentPlayTimestamps {
                    let pastHour = calendar.component(.hour, from: Date(timeIntervalSince1970: playedAt))
                    let delta = abs(hour - pastHour)
                    let distance = min(delta, 24 - delta)
                    affinity += exp(-max(0, timestamp - playedAt) / (14 * 86_400))
                        * exp(-Double(distance * distance) / 18)
                        * dailyMixTaste(for: track, telemetry: telemetry) * 0.4
                }
            }
            let vibe = dailyMixVibeCache[filename]?.profile
                ?? DailyMixEngine.fallbackVibe(
                    id: filename,
                    artist: track.artist,
                    duration: track.duration
                )
            var sessionEvidence = 0.0
            var sessionWeight = 1.5
            for event in recentSession {
                let similarity: Double
                if event.filename == filename {
                    similarity = 1
                } else if let other = dailyMixVibeCache[event.filename]?.profile,
                          dailyMixVibeCache[filename] != nil {
                    similarity = max(0, 1 - DailyMixEngine.vibeDistance(vibe, other, duration: track.duration) / 0.3) * 0.65
                } else { continue }
                let recency = exp(-max(0, timestamp - event.timestamp) / 600)
                sessionEvidence += event.reward * similarity * recency
                sessionWeight += similarity * recency
            }
            let learned = ListeningTaste.learnedAdjustment(events: events[filename] ?? [], now: timestamp)
            let fatigue = trackFatiguePenalty(for: filename, now: timestamp)
            return DailyMixCandidate(
                id: filename,
                artist: track.artist,
                duration: track.duration,
                taste: min(1, max(0, dailyMixTaste(for: track, telemetry: telemetry) + learned * 0.4)),
                isUnheard: telemetry.playStarts == 0,
                lastPlayedAt: telemetry.lastPlayedAt,
                vibe: vibe,
                contextAffinity: 1 - exp(-affinity / 2),
                hasAnalyzedVibe: dailyMixVibeCache[filename] != nil,
                recentRejection: min(1, rejection),
                fatiguePenalty: fatigue,
                sessionAffinity: sessionEvidence / sessionWeight,
                remixPenalty: remix && previousIDs.contains(filename) ? 1 : 0
            )
        }

        var selectedIDs = DailyMixEngine.select(
            from: candidates,
            dayKey: dayKey &+ dailyMixRevision,
            now: timestamp
        )
        if remix, selectedIDs.count > 1, selectedIDs == dailyMixTracks.map({ $0.url.lastPathComponent }) {
            selectedIDs = Array(selectedIDs.dropFirst()) + [selectedIDs[0]]
        }
        let tracksByFilename = Dictionary(
            uniqueKeysWithValues: tracks.map { ($0.url.lastPathComponent, $0) }
        )

        dailyMixBucket = dayKey
        dailyMixTracks = selectedIDs.compactMap { tracksByFilename[$0] }

        if activeFilter == .dailyMix, isViewLoaded {
            let playingFilename = audioPlayer?.url?.lastPathComponent
            filterTracks()
            if playbackQueue.isEmpty, let playingFilename,
               let updatedIndex = filteredTracks.firstIndex(where: {
                   $0.url.lastPathComponent == playingFilename
               }) {
                currentTrackIndex = updatedIndex
                tableView.reloadData()
                updateMiniPlayerUI()
            }
        }
    }

    func startDailyMixRefreshTimer() {
        dailyMixRefreshTimer?.invalidate()
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let hour = calendar.component(.hour, from: now)
        let nextHour: Int
        switch hour {
        case 0..<6: nextHour = 6
        case 6..<12: nextHour = 12
        case 12..<18: nextHour = 18
        case 18..<23: nextHour = 23
        default: nextHour = 24
        }
        let startOfToday = calendar.startOfDay(for: now)
        let fireDate: Date
        if nextHour == 24 {
            fireDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)?.addingTimeInterval(0.25) ?? now.addingTimeInterval(3600)
        } else {
            fireDate = calendar.date(byAdding: .hour, value: nextHour, to: startOfToday)?.addingTimeInterval(0.25) ?? now.addingTimeInterval(3600)
        }
        let timer = Timer(
            fireAt: fireDate,
            interval: 0,
            target: self,
            selector: #selector(dailyMixRefreshTimerFired),
            userInfo: nil,
            repeats: false
        )
        timer.tolerance = 1
        dailyMixRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc func dailyMixRefreshTimerFired() {
        refreshDailyMixIfNeeded()
        publishWidgetRecommendations()
        startDailyMixRefreshTimer()
    }

    @objc func handleDailyMixNotificationTap() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              appDelegate.consumePendingDailyMixPresentation() else { return }
        presentDailyMix(autoplayFirstTrack: true)
    }

    func presentDailyMix(autoplayFirstTrack: Bool = false) {
        loadViewIfNeeded()
        view.layoutIfNeeded()
        refreshDailyMixIfNeeded(force: true)
        activeFilter = .dailyMix
        searchBar.text = ""
        filterTracks()
        rebuildFiltersRow()

        if scrollView.bounds.width > 0 {
            scrollView.setContentOffset(
                CGPoint(x: scrollView.bounds.width, y: 0),
                animated: !autoplayFirstTrack
            )
        }

        guard autoplayFirstTrack else { return }
        guard !filteredTracks.isEmpty else {
            showToast(message: "Import some music to build your Daily Mix", success: false)
            return
        }

        pendingListeningEndReason = .selection
        playbackSource = .dailyMix
        playbackQueue = filteredTracks
        currentPlaybackContext = "DAILY MIX"
        currentTrackIndex = 0
        persistedSettings.playbackPosition = 0
        if isShuffleEnabled {
            rebuildShuffleQueue()
        }
        playCurrentTrack()
    }

    private func dailyMixTaste(
        for track: Track,
        telemetry: TrackListeningTelemetry
    ) -> Double {
        let starts = Double(max(1, telemetry.playStarts))
        let completionRate = min(1, Double(telemetry.completedPlays) / starts)
        let skipRate = min(1, Double(telemetry.skips) / starts)
        let earlySkipRate = min(1, Double(telemetry.earlySkips) / starts)
        let listenRatio = min(
            1,
            telemetry.totalListeningSeconds
                / max(60, telemetry.totalDurationAtStarts)
        )
        let manualIntent = min(1, log2(Double(telemetry.manualSelections) + 1) / 4)
        let filename = track.url.lastPathComponent

        var taste = telemetry.playStarts == 0 ? 0.12 : 0.20
        taste += favoriteTracks.contains(filename) ? 0.34 : 0
        taste += playlists.values.contains(where: { $0.contains(filename) }) ? 0.10 : 0
        taste += completionRate * 0.20
        taste += listenRatio * 0.13
        taste += manualIntent * 0.11
        taste -= skipRate * 0.20
        taste -= earlySkipRate * 0.16
        return min(1, max(0, taste))
    }
}


extension ViewController {
    var listeningSourceForActiveFilter: ListeningSource {
        switch activeFilter {
        case .all: return .library
        case .dailyMix: return .dailyMix
        case .favorites: return .favorites
        case .playlist: return .playlist
        }
    }

    func adaptDailyMixQueueIfNeeded() {
        guard playbackSource == .dailyMix,
              let event = listeningTelemetry.sessions?.last,
              event.source == .dailyMix, event.isRejection else { return }
        rebuildDailyMixQueue(remix: false)
    }

    func rebuildDailyMixQueue(remix: Bool) {
        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }
        let playing = currentPlaybackTrack()
        refreshDailyMixIfNeeded(force: true, allowPlaying: true, remix: remix)
        guard playbackSource == .dailyMix else { return }
        if let playing {
            playbackQueue = [playing] + dailyMixTracks.filter { $0.url != playing.url }
            currentTrackIndex = 0
        } else {
            playbackQueue = dailyMixTracks
            currentTrackIndex = playbackQueue.isEmpty ? nil : 0
        }
        if isShuffleEnabled { rebuildShuffleQueue() }
        prepareUpcomingTrack()
        updateCarouselArtworks(animated: false)
        tableView.reloadData()
    }

    func shakeDailyMix() {
        let now = ProcessInfo.processInfo.systemUptime
        let width = scrollView.bounds.width
        let libraryVisible = width > 0 && abs(scrollView.contentOffset.x - width) < width * 0.4
        let playerVisible = isPlayerPageVisible && playbackSource == .dailyMix
        guard UIApplication.shared.applicationState == .active,
              presentedViewController == nil, activeSheetView == nil,
              !searchBar.searchTextField.isFirstResponder, !isCarouselAnimating,
              (libraryVisible && activeFilter == .dailyMix) || playerVisible,
              dailyMixTracks.count > 1, now - lastMixShakeTime > 3 else { return }
        lastMixShakeTime = now
        let oldMix = dailyMixTracks
        let oldQueue = playbackQueue
        let oldMixID = dailyMixID
        let playingURL = audioPlayer?.url
        dailyMixRevision &+= 1
        dailyMixID = UUID().uuidString
        rebuildDailyMixQueue(remix: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        myWaveView?.shakeMix()
        showMixShakeAnimation { [weak self] in
            guard let self else { return }
            // Undo can only restore the queue while the same track is current.
            guard self.audioPlayer?.url == playingURL else { return }
            self.dailyMixTracks = oldMix
            self.dailyMixID = oldMixID
            self.playbackQueue = oldQueue
            self.currentTrackIndex = oldQueue.firstIndex { $0.url == playingURL }
            if self.isShuffleEnabled { self.rebuildShuffleQueue() }
            if self.activeFilter == .dailyMix { self.filterTracks() }
            self.prepareUpcomingTrack()
            self.updateCarouselArtworks(animated: false)
        }
    }

    private func showMixShakeAnimation(undo: @escaping () -> Void) {
        let banner = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Mix reshaped · Undo"
        config.image = UIImage(systemName: "waveform.path")
        config.imagePadding = 10
        config.baseBackgroundColor = primaryTextColor()
        config.baseForegroundColor = primaryBackgroundColor()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 22)
        banner.configuration = config
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            banner.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32)
        ])
        banner.addAction(UIAction { _ in
            undo()
            banner.removeFromSuperview()
        }, for: .touchUpInside)
        UIAccessibility.post(notification: .announcement, argument: "Mix reshaped. Current song keeps playing.")
        if !UIAccessibility.isReduceMotionEnabled {
            banner.alpha = 0
            UIView.animate(withDuration: 0.25) { banner.alpha = 1 }
            let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            shake.values = [0, -0.045, 0.04, -0.025, 0.015, 0]
            shake.duration = 0.65
            banner.layer.add(shake, forKey: "mixShake")
            // A short luminous perimeter follows the same palette as the wave.
            let glow = CAGradientLayer()
            glow.frame = view.bounds
            glow.type = .conic
            glow.colors = [UIColor.systemCyan.cgColor, UIColor.systemPink.cgColor,
                           UIColor.systemOrange.cgColor, UIColor.systemPurple.cgColor, UIColor.systemCyan.cgColor]
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 0)
            let outline = CAShapeLayer()
            outline.path = UIBezierPath(roundedRect: view.bounds.insetBy(dx: 3, dy: 3), cornerRadius: 42).cgPath
            outline.fillColor = UIColor.clear.cgColor
            outline.strokeColor = UIColor.white.cgColor
            outline.lineWidth = 5
            glow.mask = outline
            view.layer.addSublayer(glow)
            let pulse = CAKeyframeAnimation(keyPath: "opacity")
            pulse.values = [0, 1, 0.8, 0]
            pulse.keyTimes = [0, 0.2, 0.5, 1]
            pulse.duration = 1.6
            glow.opacity = 0
            glow.add(pulse, forKey: "mixGlow")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { glow.removeFromSuperlayer() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak banner] in
            UIView.animate(withDuration: 0.2, animations: { banner?.alpha = 0 }) { _ in
                banner?.removeFromSuperview()
            }
        }
    }
}
