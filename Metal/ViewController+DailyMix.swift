//
//  ViewController+DailyMix.swift
//  Metal
//

import UIKit

extension ViewController {
    func refreshDailyMixIfNeeded(force: Bool = false, now: Date = Date()) {
        let bucket = DailyMixEngine.bucket(for: now)
        guard force || dailyMixBucket != bucket else { return }

        let timestamp = now.timeIntervalSince1970
        let candidates = tracks.map { track -> DailyMixCandidate in
            let filename = track.url.lastPathComponent
            let telemetry = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()
            return DailyMixCandidate(
                id: filename,
                artist: track.artist,
                affinity: lovelyScore(for: track, now: timestamp),
                playStarts: telemetry.playStarts,
                skips: telemetry.skips,
                lastPlayedAt: telemetry.lastPlayedAt
            )
        }

        let selectedIDs = DailyMixEngine.select(
            from: candidates,
            bucket: bucket,
            now: timestamp
        )
        let tracksByFilename = Dictionary(
            uniqueKeysWithValues: tracks.map { ($0.url.lastPathComponent, $0) }
        )

        dailyMixBucket = bucket
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

        let now = Date().timeIntervalSince1970
        let nextBoundary = (floor(now / DailyMixEngine.refreshInterval) + 1)
            * DailyMixEngine.refreshInterval
        let timer = Timer(
            fireAt: Date(timeIntervalSince1970: nextBoundary + 0.2),
            interval: DailyMixEngine.refreshInterval,
            target: self,
            selector: #selector(dailyMixRefreshTimerFired),
            userInfo: nil,
            repeats: true
        )
        dailyMixRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc func dailyMixRefreshTimerFired() {
        refreshDailyMixIfNeeded()
        publishWidgetRecommendations()
    }

    @objc func handleDailyMixNotificationTap() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              appDelegate.consumePendingDailyMixPresentation() else { return }
        presentDailyMix()
    }

    func presentDailyMix() {
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
                animated: true
            )
        }
    }
}
