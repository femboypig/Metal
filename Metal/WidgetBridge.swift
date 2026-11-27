import Foundation

/// Shared by the application and extension. Keep keys, signing resolution and
/// playback destinations together so a widget never guesses another track.
struct MetalWidgetTrack: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let artworkData: Data?
    var fileSize: Int?
    var modificationDate: TimeInterval?

    var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "metal"; components.host = "play"
        components.queryItems = [URLQueryItem(name: "track", value: id)]
        if let fileSize, let modificationDate {
            components.queryItems! += [URLQueryItem(name: "v", value: "2"),
                URLQueryItem(name: "size", value: String(fileSize)),
                URLQueryItem(name: "modified", value: String(modificationDate))]
        }
        return components.url ?? MetalWidgetBridge.libraryURL
    }
}

struct MetalWidgetSnapshot: Codable, Equatable {
    var version = 2
    var updatedAt: Date
    var tracks: [MetalWidgetTrack]
}

struct MetalWidgetPlaybackRequest: Equatable {
    let filename: String
    let fileSize: Int?
    let modificationDate: TimeInterval?
    func matches(fileSize actualSize: Int, modificationDate actualDate: TimeInterval) -> Bool {
        guard actualSize >= 0 else { return false }
        if let fileSize, let modificationDate {
            return actualSize == fileSize && abs(actualDate - modificationDate) < 0.001
        }
        return true // Previously installed widgets used filename-only destinations.
    }
}

enum MetalWidgetBridge {
    static let kind = "MetalSquareWidget" // Preserve existing small-widget instances.
    static let originalGroup = "group.ru.femboypig.Metal"
    static let filename = "widget-now-playing-v2.json"
    static let legacyFilename = "widget-recommendations.json"
    static let legacyKey = "widget.recommendations.v1"
    static let libraryURL = URL(string: "metal://library")!
    static let maximumBytes = 2_000_000

    static func request(from url: URL) -> MetalWidgetPlaybackRequest? {
        guard url.scheme?.lowercased() == "metal", url.host?.lowercased() == "play",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            let found = items.filter { $0.name == name }
            return found.count == 1 ? found[0].value : nil
        }
        guard let id = value("track"), validFilename(id) else { return nil }
        if items.contains(where: { $0.name == "v" || $0.name == "size" || $0.name == "modified" }) {
            guard value("v") == "2", let size = value("size").flatMap(Int.init), size >= 0,
                  let modified = value("modified").flatMap(Double.init), modified.isFinite, modified > 0 else { return nil }
            return MetalWidgetPlaybackRequest(filename: id, fileSize: size, modificationDate: modified)
        }
        return MetalWidgetPlaybackRequest(filename: id, fileSize: nil, modificationDate: nil)
    }

    private static func validFilename(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 1024 && value != "." && value != ".." &&
            !value.contains("/") && !value.contains("\0")
    }

    /// SideStore versions need not inject ALTAppGroups. Apple provisioning
    /// profiles contain an XML plist inside CMS; read its granted group names.
    /// Access is still enforced by containerURL, never by this plist parser.
    static func profileGroups(_ data: Data?) -> [String] {
        guard let data, data.count <= maximumBytes,
              let plistStart = data.range(of: Data("<plist".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: plistStart.lowerBound..<data.endIndex) else { return [] }
        let declaration = data.range(of: Data("<?xml".utf8))?.lowerBound
        let start = declaration.flatMap { $0 < plistStart.lowerBound ? $0 : nil } ?? plistStart.lowerBound
        guard let parsed = try? PropertyListSerialization.propertyList(from: data[start..<end.upperBound], format: nil),
              let plist = parsed as? [String: Any], let entitlements = plist["Entitlements"] as? [String: Any] else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }

    static func groupCandidates(info: [String: Any], profile: Data?, bundleIdentifier: String?) -> [String] {
        func belongs(_ value: String) -> Bool {
            let name = value.lowercased(), original = originalGroup.lowercased()
            return name == original || name.hasPrefix(original + ".")
        }
        var candidates = profileGroups(profile).filter(belongs)
        candidates += (info["ALTAppGroups"] as? [String] ?? []).filter(belongs)
        // Compatible with older SideStore/AltStore builds that append the team
        // identifier to bundle IDs but omit runtime App Group metadata.
        if let suffix = bundleIdentifier?.split(separator: ".").last, suffix.count == 10,
           suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
            candidates.append(originalGroup + "." + suffix)
        }
        candidates.append(originalGroup)
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    static var runtimeGroups: [String] {
        let bundle = Bundle.main
        let profile = bundle.url(forResource: "embedded", withExtension: "mobileprovision").flatMap(readBounded)
        return groupCandidates(info: bundle.infoDictionary ?? [:], profile: profile, bundleIdentifier: bundle.bundleIdentifier)
    }

    static func readBounded(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumBytes + 1), data.count <= maximumBytes else { return nil }
        return data
    }

    static func decode(_ data: Data) -> MetalWidgetSnapshot? {
        guard data.count <= maximumBytes else { return nil }
        let decoder = JSONDecoder()
        if let snapshot = try? decoder.decode(MetalWidgetSnapshot.self, from: data), snapshot.version == 2 {
            return validate(snapshot)
        }
        if let legacy = try? decoder.decode([MetalWidgetTrack].self, from: data) {
            return validate(MetalWidgetSnapshot(updatedAt: .distantPast, tracks: legacy))
        }
        return nil
    }

    private static func validate(_ snapshot: MetalWidgetSnapshot) -> MetalWidgetSnapshot? {
        guard snapshot.tracks.count <= 6 else { return nil }
        for track in snapshot.tracks {
            guard validFilename(track.id), track.title.count <= 1024, track.artist.count <= 1024 else { return nil }
            guard (track.fileSize == nil) == (track.modificationDate == nil),
                  (track.artworkData?.count ?? 0) <= 512_000 else { return nil }
            if let size = track.fileSize, size < 0 { return nil }
            if let date = track.modificationDate, !date.isFinite || date <= 0 { return nil }
        }
        return snapshot
    }

    static func load(in directory: URL) -> MetalWidgetSnapshot? {
        for name in [filename, legacyFilename] {
            if let data = readBounded(directory.appendingPathComponent(name)), let snapshot = decode(data) { return snapshot }
        }
        return nil
    }

    static func load() -> MetalWidgetSnapshot? {
        for group in runtimeGroups {
            if let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
               let snapshot = load(in: root) { return snapshot }
            if let data = UserDefaults(suiteName: group)?.data(forKey: legacyKey), let snapshot = decode(data) { return snapshot }
        }
        return nil
    }

    static func write(_ snapshot: MetalWidgetSnapshot, to root: URL) throws {
        let encoded = try JSONEncoder().encode(snapshot)
        guard decode(encoded) != nil else { throw CocoaError(.fileWriteInvalidFileName) }
        try encoded.write(to: root.appendingPathComponent(filename), options: .atomic)
        if let legacy = try? JSONEncoder().encode(snapshot.tracks) {
            try? legacy.write(to: root.appendingPathComponent(legacyFilename), options: .atomic)
        }
    }

    static func save(_ snapshot: MetalWidgetSnapshot) throws {
        guard let group = runtimeGroups.first(where: { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }),
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try write(snapshot, to: root)
        if let legacy = try? JSONEncoder().encode(snapshot.tracks) {
            UserDefaults(suiteName: group)?.set(legacy, forKey: legacyKey)
        }
    }
}
