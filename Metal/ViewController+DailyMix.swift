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
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
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

    func refreshDailyMixIfNeeded(force: Bool = false, now: Date = Date()) {
        let dayKey = DailyMixEngine.dayKey(for: now)
        guard force || dailyMixBucket != dayKey else { return }
        // Background analysis must not replace a queue that is being played.
        if activeFilter == .dailyMix, audioPlayer?.isPlaying == true,
           dailyMixBucket == dayKey { return }

        let timestamp = now.timeIntervalSince1970
        let calendar = Calendar.autoupdatingCurrent
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let events = Dictionary(grouping: listeningTelemetry.sessions ?? [], by: \.filename)
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
                let positive = min(1, event.listenedSeconds / 90) * event.progress
                affinity += positive * recency * (0.25 + 0.75 * timeFit * dayFit)
                if event.skipped && event.progress < 0.35 {
                    rejection += exp(-ageDays / 3) * (1 - event.progress)
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
            return DailyMixCandidate(
                id: filename,
                artist: track.artist,
                duration: track.duration,
                taste: dailyMixTaste(for: track, telemetry: telemetry),
                isUnheard: telemetry.playStarts == 0,
                lastPlayedAt: telemetry.lastPlayedAt,
                vibe: vibe,
                contextAffinity: 1 - exp(-affinity / 2),
                hasAnalyzedVibe: dailyMixVibeCache[filename] != nil,
                recentRejection: min(1, rejection)
            )
        }

        let selectedIDs = DailyMixEngine.select(
            from: candidates,
            dayKey: dayKey,
            now: timestamp
        )
        let tracksByFilename = Dictionary(
            uniqueKeysWithValues: tracks.map { ($0.url.lastPathComponent, $0) }
        )

        dailyMixBucket = dayKey
        dailyMixTracks = selectedIDs.compactMap { tracksByFilename[$0] }

        if activeFilter == .dailyMix, isViewLoaded {
            let playingFilename = audioPlayer?.url?.lastPathComponent
            filterTracks()
            if let playingFilename,
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
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return
        }
        let timer = Timer(
            fireAt: startOfTomorrow.addingTimeInterval(0.25),
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

        recordManualSelection(for: filteredTracks[0])
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
