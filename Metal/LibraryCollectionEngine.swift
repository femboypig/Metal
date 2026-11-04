import Foundation

enum LibraryCollection: String, CaseIterable {
    case all, recentlyAdded, unheard, rediscover

    var title: String {
        switch self {
        case .all: return "All Songs"
        case .recentlyAdded: return "Recently Added"
        case .unheard: return "Unplayed"
        case .rediscover: return "Forgotten Favorites"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "music.note.list"
        case .recentlyAdded: return "clock"
        case .unheard: return "sparkles"
        case .rediscover: return "heart.circle"
        }
    }
}

struct LibraryCollectionItem {
    let id: String
    let title: String
    let duration: TimeInterval
    let importedAt: TimeInterval
    let isFavorite: Bool
    let listening: TrackListeningTelemetry
}

enum LibraryCollectionEngine {
    static func hasMeaningfulListen(_ stats: TrackListeningTelemetry, duration: TimeInterval) -> Bool {
        let threshold = duration > 0 ? min(30, duration * 0.5) : 30
        return stats.completedPlays > 0 || stats.totalListeningSeconds >= threshold
    }

    static func isRediscovery(_ stats: TrackListeningTelemetry, duration: TimeInterval,
                              isFavorite: Bool, now: TimeInterval) -> Bool {
        guard hasMeaningfulListen(stats, duration: duration), let lastPlayed = stats.lastPlayedAt,
              now - lastPlayed >= 14 * 86_400 else { return false }
        if stats.consecutiveEarlySkips >= 2, let lastSkip = stats.lastEarlySkipAt,
           now - lastSkip < 14 * 86_400 { return false }
        let completionRate = Double(stats.completedPlays) / Double(max(1, stats.playStarts))
        return isFavorite || (stats.completedPlays >= 2 && completionRate >= 0.5) || stats.manualSelections >= 3
    }

    static func select(from items: [LibraryCollectionItem], collection: LibraryCollection,
                       now: TimeInterval) -> [String] {
        let selected: [LibraryCollectionItem]
        switch collection {
        case .all:
            selected = items
        case .recentlyAdded:
            selected = Array(items.sorted {
                if $0.importedAt != $1.importedAt { return $0.importedAt > $1.importedAt }
                return $0.id < $1.id
            }.prefix(50))
        case .unheard:
            selected = items.filter { !hasMeaningfulListen($0.listening, duration: $0.duration) }
        case .rediscover:
            selected = items.filter {
                isRediscovery($0.listening, duration: $0.duration, isFavorite: $0.isFavorite, now: now)
            }.sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                let lhs = $0.listening.lastPlayedAt ?? 0, rhs = $1.listening.lastPlayedAt ?? 0
                if lhs != rhs { return lhs < rhs }
                return $0.id < $1.id
            }
        }
        return selected.map(\.id)
    }
}
