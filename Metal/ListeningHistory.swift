import Foundation

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
    var consecutiveEarlySkips: Int = 0
    var lastEarlySkipAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case playStarts
        case manualSelections
        case completedPlays
        case skips
        case earlySkips
        case resumeCount
        case totalListeningSeconds
        case totalDurationAtStarts
        case longestListeningSession
        case firstPlayedAt
        case lastPlayedAt
        case lastCompletedAt
        case recentPlayTimestamps
        case consecutiveEarlySkips
        case lastEarlySkipAt
    }

    init(
        playStarts: Int = 0,
        manualSelections: Int = 0,
        completedPlays: Int = 0,
        skips: Int = 0,
        earlySkips: Int = 0,
        resumeCount: Int = 0,
        totalListeningSeconds: TimeInterval = 0,
        totalDurationAtStarts: TimeInterval = 0,
        longestListeningSession: TimeInterval = 0,
        firstPlayedAt: TimeInterval? = nil,
        lastPlayedAt: TimeInterval? = nil,
        lastCompletedAt: TimeInterval? = nil,
        recentPlayTimestamps: [TimeInterval] = [],
        consecutiveEarlySkips: Int = 0,
        lastEarlySkipAt: TimeInterval? = nil
    ) {
        self.playStarts = playStarts
        self.manualSelections = manualSelections
        self.completedPlays = completedPlays
        self.skips = skips
        self.earlySkips = earlySkips
        self.resumeCount = resumeCount
        self.totalListeningSeconds = totalListeningSeconds
        self.totalDurationAtStarts = totalDurationAtStarts
        self.longestListeningSession = longestListeningSession
        self.firstPlayedAt = firstPlayedAt
        self.lastPlayedAt = lastPlayedAt
        self.lastCompletedAt = lastCompletedAt
        self.recentPlayTimestamps = recentPlayTimestamps
        self.consecutiveEarlySkips = consecutiveEarlySkips
        self.lastEarlySkipAt = lastEarlySkipAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playStarts = try container.decodeIfPresent(Int.self, forKey: .playStarts) ?? 0
        manualSelections = try container.decodeIfPresent(Int.self, forKey: .manualSelections) ?? 0
        completedPlays = try container.decodeIfPresent(Int.self, forKey: .completedPlays) ?? 0
        skips = try container.decodeIfPresent(Int.self, forKey: .skips) ?? 0
        earlySkips = try container.decodeIfPresent(Int.self, forKey: .earlySkips) ?? 0
        resumeCount = try container.decodeIfPresent(Int.self, forKey: .resumeCount) ?? 0
        totalListeningSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .totalListeningSeconds) ?? 0
        totalDurationAtStarts = try container.decodeIfPresent(TimeInterval.self, forKey: .totalDurationAtStarts) ?? 0
        longestListeningSession = try container.decodeIfPresent(TimeInterval.self, forKey: .longestListeningSession) ?? 0
        firstPlayedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .firstPlayedAt)
        lastPlayedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .lastPlayedAt)
        lastCompletedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .lastCompletedAt)
        recentPlayTimestamps = try container.decodeIfPresent([TimeInterval].self, forKey: .recentPlayTimestamps) ?? []
        consecutiveEarlySkips = try container.decodeIfPresent(Int.self, forKey: .consecutiveEarlySkips) ?? 0
        lastEarlySkipAt = try container.decodeIfPresent(TimeInterval.self, forKey: .lastEarlySkipAt)
    }
}

struct ListeningTelemetryDocument: Codable {
    var version = 2
    var tracks: [String: TrackListeningTelemetry] = [:]
    var sessions: [ListeningSessionEvent]?
    var dailyMixQuality: ListeningQuality?
}

struct ListeningSessionEvent: Codable {
    let filename: String
    let timestamp: TimeInterval
    let hour: Int
    let weekday: Int
    let listenedSeconds: TimeInterval
    let progress: Double
    let skipped: Bool
    var source: ListeningSource?
    var reason: ListeningEndReason?
    var duration: TimeInterval?
    var startedAt: TimeInterval?
    var mixID: String?
    var manuallySelected: Bool?
    var favorited: Bool?

    // Media position alone is misleading after seeking or resuming.
    var engagement: Double {
        guard let duration, duration > 0 else { return min(1, max(0, progress)) }
        return min(1, max(0, listenedSeconds / duration))
    }
    var isRejection: Bool {
        if reason == .dislike { return true }
        return (reason == .next || (reason == nil && skipped)) && engagement < 0.35
    }
    var reward: Double {
        if reason == .dislike { return -1 }
        if isRejection { return -0.7 * (1 - engagement) }
        if reason == .sleepTimer || reason == .failure { return 0 }
        return engagement >= 0.65 ? engagement : 0
    }
}

enum ListeningSource: String, Codable {
    case library, dailyMix, favorites, playlist, widget
}

enum ListeningEndReason: String, Codable {
    case completed, next, previous, selection, dislike, sleepTimer, failure
}

struct ListeningQuality: Codable {
    let impressions: Int
    let earlySkipRate: Double
    let completionRate: Double
    let favoriteRate: Double

    static func dailyMix(in events: [ListeningSessionEvent]) -> ListeningQuality {
        let mix = events.filter { $0.source == .dailyMix && $0.reason != .failure && $0.reason != .sleepTimer }
        let count = Double(max(1, mix.count))
        return ListeningQuality(impressions: mix.count,
            earlySkipRate: Double(mix.filter(\.isRejection).count) / count,
            completionRate: Double(mix.filter { $0.engagement >= 0.85 }.count) / count,
            favoriteRate: Double(mix.filter { $0.favorited == true }.count) / count)
    }
}

// A prior prevents one accidental action from defining a permanent preference.
// Evidence decays so a user's recent listening can outweigh old habits.
enum ListeningTaste {
    static func learnedAdjustment(events: [ListeningSessionEvent], now: TimeInterval) -> Double {
        var evidence = 0.0
        var weight = 4.0
        for event in events {
            let decay = exp(-max(0, now - event.timestamp) / (30 * 86_400))
            guard event.reward != 0 else { continue }
            let intent = event.manuallySelected == true && event.reward > 0 ? 1.4 : 1.0
            evidence += event.reward * decay * intent
            weight += decay * intent
        }
        return evidence / weight
    }
}


