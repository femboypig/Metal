//
//  ListeningTelemetry.swift
//  Metal
//

import Foundation
import AVFoundation

struct TrackListeningTelemetry: Codable {
    var playStarts = 0
    var manualSelections = 0
    var completedPlays = 0
    var skips = 0
    var earlySkips = 0
    var resumeCount = 0
    var totalListeningSeconds: TimeInterval = 0
    var totalDurationAtStarts: TimeInterval = 0
    var longestListeningSession: TimeInterval = 0
    var firstPlayedAt: TimeInterval?
    var lastPlayedAt: TimeInterval?
    var lastCompletedAt: TimeInterval?
    var recentPlayTimestamps: [TimeInterval] = []
}

struct ListeningTelemetryDocument: Codable {
    var version = 1
    var tracks: [String: TrackListeningTelemetry] = [:]
    var sessions: [ListeningSessionEvent]?
}

struct ListeningSessionEvent: Codable {
    let filename: String
    let timestamp: TimeInterval
    let hour: Int
    let weekday: Int
    let listenedSeconds: TimeInterval
    let progress: Double
    let skipped: Bool
}

extension ViewController {
    var telemetryFileURL: URL {
        metalRootDirectoryURL.appendingPathComponent("telemetry.json")
    }

    func loadListeningTelemetry() {
        guard let data = try? Data(contentsOf: telemetryFileURL),
              let document = try? JSONDecoder().decode(ListeningTelemetryDocument.self, from: data) else {
            listeningTelemetry = ListeningTelemetryDocument()
            saveListeningTelemetry()
            return
        }
        listeningTelemetry = document
    }

    func saveListeningTelemetry() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(listeningTelemetry) else { return }
        try? data.write(to: telemetryFileURL, options: .atomic)
    }

    func recordManualSelection(for track: Track) {
        let filename = track.url.lastPathComponent
        var stats = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()
        stats.manualSelections += 1
        listeningTelemetry.tracks[filename] = stats
        saveListeningTelemetry()
    }

    func startListeningTelemetry(for track: Track, resumed: Bool) {
        let filename = track.url.lastPathComponent
        let now = Date().timeIntervalSince1970
        var stats = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()

        stats.playStarts += 1
        stats.totalDurationAtStarts += max(0, track.duration)
        stats.firstPlayedAt = stats.firstPlayedAt ?? now
        stats.lastPlayedAt = now
        stats.recentPlayTimestamps.append(now)
        stats.recentPlayTimestamps = Array(stats.recentPlayTimestamps
            .filter { now - $0 <= 90 * 86_400 }
            .suffix(60))
        if resumed {
            stats.resumeCount += 1
        }

        listeningTelemetry.tracks[filename] = stats
        telemetrySessionFilename = filename
        telemetryLastPlaybackTime = audioPlayer?.currentTime ?? 0
        telemetrySessionListeningSeconds = 0
        saveListeningTelemetry()
    }

    func updateListeningTelemetry(with player: AVAudioPlayer) {
        guard let filename = telemetrySessionFilename,
              player.url?.lastPathComponent == filename else { return }

        let currentTime = player.currentTime
        let delta = currentTime - telemetryLastPlaybackTime
        telemetryLastPlaybackTime = currentTime

        // Ignore seeks and discontinuities; only real playback time should count.
        guard player.isPlaying, delta > 0, delta < 1.5 else { return }

        telemetrySessionListeningSeconds += delta
        var stats = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()
        stats.totalListeningSeconds += delta
        stats.longestListeningSession = max(stats.longestListeningSession, telemetrySessionListeningSeconds)
        listeningTelemetry.tracks[filename] = stats
    }

    func finishListeningTelemetry(completed: Bool, skipped: Bool, progress: Double) {
        guard let filename = telemetrySessionFilename else { return }
        var stats = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()

        if completed {
            stats.completedPlays += 1
            stats.lastCompletedAt = Date().timeIntervalSince1970
        } else if skipped {
            stats.skips += 1
            if progress < 0.35 {
                stats.earlySkips += 1
            }
        }

        stats.longestListeningSession = max(stats.longestListeningSession, telemetrySessionListeningSeconds)
        listeningTelemetry.tracks[filename] = stats
        let date = Date()
        let started = date.addingTimeInterval(-telemetrySessionListeningSeconds)
        let event = ListeningSessionEvent(
            filename: filename, timestamp: date.timeIntervalSince1970,
            hour: Calendar.current.component(.hour, from: started),
            weekday: Calendar.current.component(.weekday, from: started),
            listenedSeconds: telemetrySessionListeningSeconds,
            progress: min(1, max(0, progress)), skipped: skipped
        )
        var sessions = listeningTelemetry.sessions ?? []
        if telemetrySessionListeningSeconds >= 5 { sessions.append(event) }
        listeningTelemetry.sessions = Array(sessions.filter {
            date.timeIntervalSince1970 - $0.timestamp < 90 * 86_400
        }.suffix(1000))
        telemetrySessionFilename = nil
        telemetryLastPlaybackTime = 0
        telemetrySessionListeningSeconds = 0
        saveListeningTelemetry()
        publishWidgetRecommendations()
    }

    func lovelyTracks(from source: [Track]) -> [Track] {
        source
            .map { ($0, lovelyScore(for: $0)) }
            .filter { $0.1 >= 24 }
            .sorted {
                if abs($0.1 - $1.1) > 0.01 { return $0.1 > $1.1 }
                return $0.0.title.localizedCompare($1.0.title) == .orderedAscending
            }
            .prefix(50)
            .map(\.0)
    }

    func lovelyScore(for track: Track, now: TimeInterval = Date().timeIntervalSince1970) -> Double {
        let filename = track.url.lastPathComponent
        let stats = listeningTelemetry.tracks[filename] ?? TrackListeningTelemetry()
        let isFavorite = favoriteTracks.contains(filename)
        let isInPlaylist = playlists.values.contains { $0.contains(filename) }

        guard stats.playStarts > 0 || isFavorite || isInPlaylist else { return 0 }

        let starts = Double(max(1, stats.playStarts))
        let completionRate = min(1, Double(stats.completedPlays) / starts)
        let skipRate = min(1, Double(stats.skips) / starts)
        let earlySkipRate = min(1, Double(stats.earlySkips) / starts)
        let duration = max(60, track.duration)
        let equivalentListens = stats.totalListeningSeconds / duration
        let averageListenRatio = min(1, stats.totalListeningSeconds / max(duration, stats.totalDurationAtStarts))
        let longestSessionRatio = min(1, stats.longestListeningSession / duration)

        let recentWeek = stats.recentPlayTimestamps.filter { now - $0 <= 7 * 86_400 }.count
        let recentMonth = stats.recentPlayTimestamps.filter { now - $0 <= 30 * 86_400 }.count
        let activeWeeks = Set(stats.recentPlayTimestamps.map { Int($0 / (7 * 86_400)) }).count

        var score = 0.0
        score += isFavorite ? 42 : 0
        score += isInPlaylist ? 8 : 0
        score += completionRate * 28
        score += min(25, log2(Double(stats.completedPlays) + 1) * 10)
        score += min(24, equivalentListens * 2.4)
        score += longestSessionRatio * 8
        score += min(21, log2(Double(stats.manualSelections) + 1) * 7)
        score += min(8, Double(stats.resumeCount) * 2)
        score += min(18, Double(recentWeek) * 4)
        score += min(12, Double(recentMonth - recentWeek) * 1.5)
        score += min(10, Double(activeWeeks) * 2)

        if let lastPlayedAt = stats.lastPlayedAt {
            let daysSinceLastPlay = max(0, now - lastPlayedAt) / 86_400
            score += max(0, 12 - daysSinceLastPlay * 0.4)
        }

        if let lastCompletedAt = stats.lastCompletedAt {
            let daysSinceCompletion = max(0, now - lastCompletedAt) / 86_400
            score += max(0, 6 - daysSinceCompletion * 0.2)
        }

        if stats.playStarts >= 2, averageListenRatio < 0.20 {
            score -= 10
        }
        if stats.playStarts >= 3, stats.completedPlays == 0 {
            score -= 6
        }
        score -= skipRate * 30
        score -= earlySkipRate * 18

        return score
    }
}
