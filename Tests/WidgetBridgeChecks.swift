import Foundation

@main struct WidgetBridgeChecks {
    static func verify(_ condition: @autoclosure () -> Bool, _ message: String = "Widget check failed", file: StaticString = #fileID, line: UInt = #line) {
        guard condition() else {
            FileHandle.standardError.write(Data("\(file):\(line): \(message)\n".utf8)); exit(1)
        }
    }
    static func profile(_ groups: [String]) throws -> Data {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["Entitlements": ["com.apple.security.application-groups": groups]], format: .xml, options: 0)
        return Data([0x30, 0x82, 0x00, 0x00]) + plist + Data([0x01, 0x02])
    }
    static func main() throws {
        let original = MetalWidgetBridge.originalGroup
        let resigned = original + ".A1B2C3D4E"
        let signedProfile = try profile([resigned])
        verify(MetalWidgetBridge.profileGroups(signedProfile) == [resigned])
        let appGroups = MetalWidgetBridge.groupCandidates(info: [:], profile: signedProfile, bundleIdentifier: "ru.femboypig.Metal.A1B2C3D4E")
        let widgetGroups = MetalWidgetBridge.groupCandidates(info: [:], profile: signedProfile, bundleIdentifier: "ru.femboypig.Metal.widgets.A1B2C3D4E")
        verify(appGroups == widgetGroups && appGroups.first == resigned, "Both processes must use the same SideStore-signed group even without ALTAppGroups")
        verify(MetalWidgetBridge.groupCandidates(info: ["ALTAppGroups": [original]], profile: signedProfile, bundleIdentifier: nil).first == resigned,
            "Signed profile must take precedence over stale plist metadata")
        verify(MetalWidgetBridge.groupCandidates(info: ["ALTAppGroups": ["group.unrelated", resigned]], profile: nil, bundleIdentifier: nil).first == resigned)
        let unrelatedProfile = try profile(["group.other"])
        verify(MetalWidgetBridge.groupCandidates(info: ["ALTAppGroups": ["group.unrelated"]], profile: unrelatedProfile, bundleIdentifier: nil) == [original])
        verify(MetalWidgetBridge.profileGroups(Data("broken profile".utf8)).isEmpty)
        verify(MetalWidgetBridge.groupCandidates(info: [:], profile: nil, bundleIdentifier: "ru.femboypig.Metal") == [original])
        verify(MetalWidgetBridge.groupCandidates(info: [:], profile: nil, bundleIdentifier: "ru.femboypig.Metal.A1B2C3D4E").first == resigned)

        let track = MetalWidgetTrack(id: "Песня & #1? + live.mp3", title: "Название", artist: "Исполнитель", artworkData: nil,
            fileSize: 10240, modificationDate: 1730000000.123456)
        let request = MetalWidgetBridge.request(from: track.deepLinkURL)!
        verify(request.filename == track.id && request.matches(fileSize: 10240, modificationDate: 1730000000.123456))
        verify(!request.matches(fileSize: 20480, modificationDate: 1730000000.123456), "A replaced file must not silently play under an old card")
        verify(!request.matches(fileSize: 10240, modificationDate: 1730000001))
        verify(!request.matches(fileSize: -1, modificationDate: 0))
        for invalid in ["metal://play?track=../other.mp3", "metal://play?track=one.mp3&track=two.mp3", "metal://play?track=one.mp3&v=2", "metal://play?track=one.mp3&v=2&size=1&modified=nan", "https://play?track=one.mp3"] {
            verify(MetalWidgetBridge.request(from: URL(string: invalid)!) == nil)
        }
        let legacyURL = URL(string: "metal://play?track=legacy.mp3")!
        verify(MetalWidgetBridge.request(from: legacyURL)?.filename == "legacy.mp3")
        verify(MetalWidgetBridge.request(from: MetalWidgetBridge.libraryURL) == nil)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = MetalWidgetSnapshot(updatedAt: Date(), tracks: [track])
        try MetalWidgetBridge.write(snapshot, to: directory)
        let loaded = MetalWidgetBridge.load(in: directory)
        verify(loaded?.tracks == snapshot.tracks && loaded?.version == 2, "Widget must read the exact record exported by the app")
        verify(abs((loaded?.updatedAt.timeIntervalSince1970 ?? 0) - snapshot.updatedAt.timeIntervalSince1970) < 0.001)
        let legacy = try JSONEncoder().encode([track])
        verify(MetalWidgetBridge.decode(legacy)?.tracks == [track])
        let empty = MetalWidgetSnapshot(updatedAt: Date(), tracks: [])
        try MetalWidgetBridge.write(empty, to: directory)
        // Leave old compatibility data behind deliberately: empty v2 wins.
        try legacy.write(to: directory.appendingPathComponent(MetalWidgetBridge.legacyFilename))
        verify(MetalWidgetBridge.load(in: directory)?.tracks.isEmpty == true)
        verify(MetalWidgetBridge.decode(Data("invalid JSON".utf8)) == nil)
        let oversized = directory.appendingPathComponent("oversized")
        try Data(repeating: 0, count: MetalWidgetBridge.maximumBytes + 1).write(to: oversized)
        verify(MetalWidgetBridge.readBounded(oversized) == nil)
        var unsupported = snapshot; unsupported.version = 999
        let unsupportedData = try JSONEncoder().encode(unsupported)
        verify(MetalWidgetBridge.decode(unsupportedData) == nil)
        print("Widget bridge: SideStore profiles, common App Group, legacy migration, exact deep links, stale-file rejection, atomic snapshots and empty library passed")
    }
}
