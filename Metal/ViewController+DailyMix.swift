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
            self.publishWidgetRecommendations()
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

        let timestamp = now.timeIntervalSince1970
        let candidates = tracks.map { track -> DailyMixCandidate in
            let filename = track.url.lastPathComponent
            let telemetry = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()
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
                vibe: vibe
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
        refreshDailyMixIfNeeded()
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
