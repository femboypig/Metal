//
//  ViewController+Library.swift
//  Metal
//

import UIKit
import CoreImage
import WidgetKit

private struct MetalWidgetRecommendation: Codable {
    let id: String
    let title: String
    let artist: String
    let artworkData: Data?
}

private let originalMetalAppGroup = "group.ru.femboypig.Metal"
private let widgetRecommendationsFilename = "widget-recommendations.json"

private var resolvedMetalAppGroup: String {
    let resignedGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String]
    return resignedGroups?.first(where: { $0.contains(originalMetalAppGroup) })
        ?? resignedGroups?.first
        ?? originalMetalAppGroup
}

struct MetalSettingsDocument: Codable {
    var version: Int = 1
    var favoriteTracks: [String] = []
    var aidjEnabled: Bool = true
    var shuffleEnabled: Bool = false
    var repeatEnabled: Bool = false
    var lastTrackFile: String?
    var playbackPosition: TimeInterval = 0
}

extension ViewController {

    // MARK: - Local Persistence Loading

    func loadLocalUserData() {
        _ = songsDirectoryURL
        migrateNestedMetalLayoutIfNeeded()
        loadTrackMetadataCache()

        if let data = try? Data(contentsOf: settingsFileURL),
           let savedSettings = try? JSONDecoder().decode(MetalSettingsDocument.self, from: data) {
            persistedSettings = savedSettings
        } else {
            let defaults = UserDefaults.standard
            persistedSettings = MetalSettingsDocument(
                favoriteTracks: defaults.stringArray(forKey: "Metal_Favorites") ?? [],
                aidjEnabled: defaults.object(forKey: "Metal_AIDJEnabled") == nil
                    ? true
                    : defaults.bool(forKey: "Metal_AIDJEnabled"),
                shuffleEnabled: defaults.bool(forKey: "Metal_Shuffle"),
                repeatEnabled: defaults.bool(forKey: "Metal_Repeat"),
                lastTrackFile: defaults.string(forKey: "Metal_LastTrackFile"),
                playbackPosition: 0
            )
            writeSettingsDocument()
        }

        favoriteTracks = Set(persistedSettings.favoriteTracks)
        UserDefaults.standard.set(persistedSettings.aidjEnabled, forKey: "Metal_AIDJEnabled")

        if let data = try? Data(contentsOf: playlistsFileURL),
           let savedPlaylists = try? JSONDecoder().decode([String: [String]].self, from: data) {
            playlists = savedPlaylists
        } else {
            playlists = UserDefaults.standard.dictionary(forKey: "Metal_Playlists") as? [String: [String]] ?? [:]
            savePlaylists()
        }
    }

    func savePlaylists() {
        UserDefaults.standard.set(playlists, forKey: "Metal_Playlists")
        writeJSON(playlists, to: playlistsFileURL)
        publishWidgetRecommendations()
    }

    func saveSettings() {
        guard !isRestoringPersistentState else { return }

        persistedSettings.favoriteTracks = favoriteTracks.sorted()
        persistedSettings.aidjEnabled = UserDefaults.standard.bool(forKey: "Metal_AIDJEnabled")
        persistedSettings.shuffleEnabled = isShuffleEnabled
        persistedSettings.repeatEnabled = isRepeatEnabled

        if let index = currentTrackIndex, index < filteredTracks.count {
            let filename = filteredTracks[index].url.lastPathComponent
            let isCurrentPlayer = audioPlayer?.url?.lastPathComponent == filename

            if persistedSettings.lastTrackFile != filename {
                persistedSettings.playbackPosition = 0
            } else if isCurrentPlayer, let player = audioPlayer {
                persistedSettings.playbackPosition = player.currentTime
            }
            persistedSettings.lastTrackFile = filename
        }

        writeSettingsDocument()
    }

    private func writeSettingsDocument() {
        writeJSON(persistedSettings, to: settingsFileURL)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Playlists Pill Selector Generator

    func rebuildFiltersRow() {
        filtersStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 1. "All" Pill
        let allPill = createPillButton(title: "All", category: .all)
        filtersStackView.addArrangedSubview(allPill)

        // 2. Personalized, vibe-matched mix rebuilt once per local calendar day
        let dailyMixPill = createPillButton(title: "Daily Mix", category: .dailyMix)
        filtersStackView.addArrangedSubview(dailyMixPill)

        // 3. "Favorites" Pill
        let favPill = createPillButton(title: "Favorites", category: .favorites)
        filtersStackView.addArrangedSubview(favPill)

        // 4. Local smart playlist based on listening behavior
        let lovelyPill = createPillButton(title: "Lovely", category: .lovely)
        filtersStackView.addArrangedSubview(lovelyPill)

        // 5. Custom Playlist Pills
        for name in playlists.keys.sorted() {
            let pill = createPillButton(title: name, category: .playlist(name))

            // Long press to delete custom playlist
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(playlistPillLongPressed(_:)))
            pill.addGestureRecognizer(longPress)

            filtersStackView.addArrangedSubview(pill)
        }

        // 6. "+ Playlist" Pill
        let newPill = UIButton(type: .system)
        newPill.translatesAutoresizingMaskIntoConstraints = false
        newPill.backgroundColor = cardBackgroundColor()
        newPill.layer.cornerRadius = 15
        newPill.layer.borderWidth = 0

        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            let plusConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            config.image = UIImage(systemName: "plus", withConfiguration: plusConfiguration)
            config.imagePadding = 3
            config.title = "Playlist"
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.baseForegroundColor = secondaryTextColor()
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                return outgoing
            }
            newPill.configuration = config
        } else if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = "＋ Playlist"
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.baseForegroundColor = secondaryTextColor()
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                return outgoing
            }
            newPill.configuration = config
        } else {
            newPill.setTitle("＋ Playlist", for: .normal)
            newPill.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            newPill.setTitleColor(secondaryTextColor(), for: .normal)
            newPill.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        }

        newPill.titleLabel?.numberOfLines = 1
        newPill.titleLabel?.lineBreakMode = .byClipping
        newPill.setContentHuggingPriority(.required, for: .horizontal)
        newPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        newPill.addTarget(self, action: #selector(createNewPlaylistTapped), for: .touchUpInside)
        filtersStackView.addArrangedSubview(newPill)
    }

    func createPillButton(title: String, category: FilterCategory) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.layer.cornerRadius = 15

        let isActive = (activeFilter == category)

        if #available(iOS 26.0, *) {
            var config = isActive
                ? UIButton.Configuration.prominentGlass()
                : UIButton.Configuration.glass()
            config.title = title
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.baseForegroundColor = isActive ? .white : secondaryTextColor()
            if isActive {
                config.baseBackgroundColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
            }
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                return outgoing
            }
            button.configuration = config
        } else if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.baseForegroundColor = isActive ? UIColor(red: 0.93, green: 0.47, blue: 0.31, alpha: 1.0) : secondaryTextColor()
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                return outgoing
            }
            button.configuration = config
        } else {
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            button.setTitleColor(isActive ? UIColor(red: 0.93, green: 0.47, blue: 0.31, alpha: 1.0) : secondaryTextColor(), for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        }

        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byClipping
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        if #available(iOS 26.0, *) {
            button.backgroundColor = .clear
            button.layer.borderWidth = 0
        } else if isActive {
            button.backgroundColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 0.13)
            button.layer.borderWidth = 0
        } else {
            button.backgroundColor = .clear
            button.layer.borderWidth = 0
        }

        button.addTarget(self, action: #selector(filterPillTapped(_:)), for: .touchUpInside)

        objc_setAssociatedObject(button, &ViewController.categoryAssociationKey, category, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return button
    }

    @objc func filterPillTapped(_ sender: UIButton) {
        guard let category = objc_getAssociatedObject(sender, &ViewController.categoryAssociationKey) as? FilterCategory else { return }

        let categories: [FilterCategory] = [.all, .dailyMix, .favorites, .lovely]
            + playlists.keys.sorted().map { .playlist($0) }
        guard let oldIdx = categories.firstIndex(of: activeFilter),
              let newIdx = categories.firstIndex(of: category) else { return }

        activeFilter = category
        filterTracks()
        rebuildFiltersRow()

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Slide animation based on direction
        let direction: UISwipeGestureRecognizer.Direction = (newIdx > oldIdx) ? .left : .right
        animateTableFilter(direction: direction)
    }

    @objc func createNewPlaylistTapped() {
        presentCustomInputSheet(title: "New Playlist", placeholder: "Playlist Name", submitTitle: "Create") { [weak self] name in
            self?.playlists[name] = []
            self?.savePlaylists()
            self?.rebuildFiltersRow()
            self?.showToast(message: "Created playlist \(name)", success: true)
        }
    }

    @objc func playlistPillLongPressed(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began, let button = sender.view as? UIButton else { return }
        guard let title = button.title(for: .normal) else { return }

        let items = [
            BottomSheetItem(title: "Delete Playlist", iconName: "trash", isDestructive: true, action: { [weak self] in
                self?.playlists.removeValue(forKey: title)
                self?.savePlaylists()

                if case .playlist(let name) = self?.activeFilter, name == title {
                    self?.activeFilter = .all
                }

                self?.filterTracks()
                self?.rebuildFiltersRow()
                self?.showToast(message: "Deleted playlist \(title)", success: true)
            })
        ]

        presentCustomBottomSheet(title: "Delete Playlist", subtitle: "Are you sure you want to delete '\(title)'?", items: items)
    }

    func filterTracks() {
        let searchText = searchBar.text ?? ""

        // 1. Filter by category
        let categoryTracks: [Track]
        let headerText: String
        switch activeFilter {
        case .all:
            categoryTracks = tracks
            headerText = "ALL SONGS"
        case .dailyMix:
            refreshDailyMixIfNeeded()
            categoryTracks = dailyMixTracks
            headerText = "DAILY MIX"
        case .favorites:
            categoryTracks = tracks.filter { favoriteTracks.contains($0.url.lastPathComponent) }
            headerText = "FAVORITES"
        case .lovely:
            categoryTracks = lovelyTracks(from: tracks)
            headerText = "LOVELY"
        case .playlist(let name):
            let filenames = playlists[name] ?? []
            categoryTracks = tracks.filter { filenames.contains($0.url.lastPathComponent) }
            headerText = name.uppercased()
        }

        playerHeaderLabel?.text = headerText

        // 2. Filter by search text
        if searchText.isEmpty {
            filteredTracks = categoryTracks
        } else {
            filteredTracks = categoryTracks.filter { track in
                track.title.localizedCaseInsensitiveContains(searchText) || track.artist.localizedCaseInsensitiveContains(searchText)
            }
        }

        tableView.reloadData()
        updateMiniPlayerUI()

        if isShuffleEnabled {
            rebuildShuffleQueue()
        }
    }

    // MARK: - Favorites Toggling Action

    func toggleFavorite(track: Track) {
        let filename = track.url.lastPathComponent
        if favoriteTracks.contains(filename) {
            favoriteTracks.remove(filename)
        } else {
            favoriteTracks.insert(filename)
        }
        UserDefaults.standard.set(Array(favoriteTracks), forKey: "Metal_Favorites")
        saveSettings()
        publishWidgetRecommendations()
        tableView.reloadData()

        if activeFilter == .favorites {
            filterTracks()
        }
        updatePlayerFavoriteButton()
        updateRemoteFavoriteCommand()
    }

    @objc func playerFavoriteTapped() {
        guard let index = currentTrackIndex, index < filteredTracks.count else { return }
        let track = filteredTracks[index]
        toggleFavorite(track: track)

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Pop scaling animation on player action icon
        playerFavoriteButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: [], animations: {
            self.playerFavoriteButton.transform = .identity
        }, completion: nil)
    }

    func updatePlayerFavoriteButton() {
        guard let index = currentTrackIndex, index < filteredTracks.count else {
            playerFavoriteButton?.setImage(UIImage(systemName: "heart", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
            playerFavoriteButton?.tintColor = UIColor.white.withAlphaComponent(0.8)
            return
        }
        let track = filteredTracks[index]
        let isFav = favoriteTracks.contains(track.url.lastPathComponent)
        let icon = isFav ? "heart.fill" : "heart"
        playerFavoriteButton?.setImage(UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        playerFavoriteButton?.tintColor = isFav ? UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0) : UIColor.white.withAlphaComponent(0.8)
    }

    // MARK: - Library Logic & Secure Import

    var songsDirectoryURL: URL {
        let fileManager = FileManager.default
        let allFolder = metalRootDirectoryURL.appendingPathComponent("All", isDirectory: true)
        if !fileManager.fileExists(atPath: allFolder.path) {
            try? fileManager.createDirectory(at: allFolder, withIntermediateDirectories: true, attributes: nil)
        }
        return allFolder
    }

    var metalRootDirectoryURL: URL {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory not available")
        }
        return documentsURL
    }

    var settingsFileURL: URL {
        metalRootDirectoryURL.appendingPathComponent("settings.json")
    }

    var playlistsFileURL: URL {
        metalRootDirectoryURL.appendingPathComponent("playlists.json")
    }

    var trackMetadataCacheFileURL: URL {
        metalRootDirectoryURL.appendingPathComponent("track-metadata.json")
    }

    func loadTrackMetadataCache() {
        guard let data = try? Data(contentsOf: trackMetadataCacheFileURL),
              let cache = try? JSONDecoder().decode([String: TrackMetadataSnapshot].self, from: data) else {
            trackMetadataCache = [:]
            return
        }
        trackMetadataCache = cache
    }

    func saveTrackMetadataCache() {
        writeJSON(trackMetadataCache, to: trackMetadataCacheFileURL)
    }

    private func migrateNestedMetalLayoutIfNeeded() {
        let fileManager = FileManager.default
        let nestedRoot = metalRootDirectoryURL.appendingPathComponent("Metal", isDirectory: true)
        let nestedAll = nestedRoot.appendingPathComponent("All", isDirectory: true)
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "wma", "aiff", "alac"]

        migrateAudioFiles(from: nestedAll, to: songsDirectoryURL, extensions: audioExtensions)

        for filename in ["settings.json", "playlists.json", "telemetry.json", "daily-mix-vibes.json", "track-metadata.json"] {
            let sourceURL = nestedRoot.appendingPathComponent(filename)
            let destinationURL = metalRootDirectoryURL.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: sourceURL.path),
               !fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.moveItem(at: sourceURL, to: destinationURL)
            }
        }
    }

    func loadLocalTracks() {
        let fileManager = FileManager.default
        let songsDir = songsDirectoryURL
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "wma", "aiff", "alac"]

        // Documents is shown as the Metal app folder in Files, so this becomes Metal/All.
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let legacyDirectories = [
                documentsURL.appendingPathComponent("Songs", isDirectory: true),
                documentsURL.appendingPathComponent("MetalSongs", isDirectory: true),
                documentsURL.appendingPathComponent("Metal/All", isDirectory: true)
            ]

            for directory in legacyDirectories {
                migrateAudioFiles(from: directory, to: songsDir, extensions: audioExtensions)
            }

            if let rootFiles = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) {
                for fileURL in rootFiles {
                    if audioExtensions.contains(fileURL.pathExtension.lowercased()) {
                        let targetURL = songsDir.appendingPathComponent(fileURL.lastPathComponent)
                        if !fileManager.fileExists(atPath: targetURL.path) {
                            try? fileManager.moveItem(at: fileURL, to: targetURL)
                        } else {
                            try? fileManager.removeItem(at: fileURL)
                        }
                    }
                }
            }
        }

        do {
            let files = try fileManager.contentsOfDirectory(at: songsDir, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { audioExtensions.contains($0.pathExtension.lowercased()) }

            libraryLoadGeneration += 1
            let generation = libraryLoadGeneration
            var uncachedURLs: [URL] = []
            tracks = audioFiles.map { url in
                let filename = url.lastPathComponent
                let signature = Track.fileSignature(for: url)
                if let cached = trackMetadataCache[filename], cached.matches(signature) {
                    return Track(url: url, metadata: cached)
                }
                uncachedURLs.append(url)
                return Track(url: url)
            }
            tracks.sort { $0.title.localizedCompare($1.title) == .orderedAscending }

            refreshDailyMixIfNeeded(force: true)
            filterTracks()
            if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                prepareDailyMixVibes()
            }
            Track.preheatArtwork(for: Array(tracks.prefix(8).map(\.url)))

            if !uncachedURLs.isEmpty {
                Task.detached(priority: .utility) { [weak self] in
                    var loaded: [String: TrackMetadataSnapshot] = [:]
                    for url in uncachedURLs {
                        loaded[url.lastPathComponent] = await Track.loadMetadata(for: url)
                    }
                    await MainActor.run {
                        guard let self, generation == self.libraryLoadGeneration else { return }
                        self.applyLoadedTrackMetadata(loaded)
                    }
                }
            }
        } catch {
            print("Failed to scan songs directory: \(error)")
        }

        scheduleWidgetRecommendationsPublish()
    }

    func applyLoadedTrackMetadata(_ loaded: [String: TrackMetadataSnapshot]) {
        guard !loaded.isEmpty else { return }
        let playingFilename = audioPlayer?.url?.lastPathComponent
        let selectedFilename = currentTrackIndex.flatMap { index in
            filteredTracks.indices.contains(index) ? filteredTracks[index].url.lastPathComponent : nil
        }

        trackMetadataCache.merge(loaded) { _, new in new }
        let liveFilenames = Set(tracks.map { $0.url.lastPathComponent })
        trackMetadataCache = trackMetadataCache.filter { liveFilenames.contains($0.key) }
        saveTrackMetadataCache()

        tracks = tracks.map { track in
            Track(url: track.url, metadata: trackMetadataCache[track.url.lastPathComponent])
        }
        tracks.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        refreshDailyMixIfNeeded(force: true)
        filterTracks()

        if let currentFilename = playingFilename ?? selectedFilename,
           let newIndex = filteredTracks.firstIndex(where: { $0.url.lastPathComponent == currentFilename }) {
            currentTrackIndex = newIndex
        }
        if playingFilename != nil {
            updateMiniPlayerUI()
            updateNowPlayingInfo()
        }
        tableView.reloadData()
        scheduleWidgetRecommendationsPublish()
    }

    func scheduleWidgetRecommendationsPublish(delay: TimeInterval = 1.0) {
        widgetPublishWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.publishWidgetRecommendations()
        }
        widgetPublishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func publishWidgetRecommendations() {
        guard !tracks.isEmpty else { return }

        refreshDailyMixIfNeeded()
        let lovely = lovelyTracks(from: tracks)
        let favorites = tracks.filter { favoriteTracks.contains($0.url.lastPathComponent) }
        let source = !dailyMixTracks.isEmpty
            ? dailyMixTracks
            : (!lovely.isEmpty ? lovely : (!favorites.isEmpty ? favorites : tracks))
        let selection = Array(source.prefix(6))

        let recommendations = selection.map { track in
            MetalWidgetRecommendation(
                id: track.url.lastPathComponent,
                title: track.title,
                artist: track.artist == "Unknown Artist" ? "" : track.artist,
                artworkData: widgetArtworkData(for: track.artwork)
            )
        }

        guard let encoded = try? JSONEncoder().encode(recommendations),
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: resolvedMetalAppGroup
              ) else {
            print("Widget recommendations: App Group container is unavailable for \(resolvedMetalAppGroup)")
            return
        }

        let fileURL = containerURL.appendingPathComponent(widgetRecommendationsFilename)
        do {
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Widget recommendations: failed to write shared payload: \(error)")
            return
        }

        // Keep a preferences copy for compatibility with earlier widget builds.
        UserDefaults(suiteName: resolvedMetalAppGroup)?.set(encoded, forKey: "widget.recommendations.v1")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func widgetArtworkData(for artwork: UIImage?) -> Data? {
        guard let artwork else { return nil }

        let targetSize = CGSize(width: 360, height: 360)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumbnail = renderer.image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: targetSize))

            let scale = max(targetSize.width / artwork.size.width, targetSize.height / artwork.size.height)
            let drawSize = CGSize(width: artwork.size.width * scale, height: artwork.size.height * scale)
            let drawOrigin = CGPoint(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2
            )
            artwork.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        return thumbnail.jpegData(compressionQuality: 0.68)
    }

    private func migrateAudioFiles(from sourceDirectory: URL, to destinationDirectory: URL, extensions: [String]) {
        let fileManager = FileManager.default
        guard sourceDirectory.standardizedFileURL != destinationDirectory.standardizedFileURL,
              let files = try? fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in files where extensions.contains(fileURL.pathExtension.lowercased()) {
            let targetURL = destinationDirectory.appendingPathComponent(fileURL.lastPathComponent)
            guard !fileManager.fileExists(atPath: targetURL.path) else { continue }
            try? fileManager.moveItem(at: fileURL, to: targetURL)
        }
    }

    @objc func importMusicButtonTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .data, .audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true, completion: nil)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let fileManager = FileManager.default
        let songsDir = songsDirectoryURL

        var importCount = 0
        for url in urls {
            let shouldAccess = url.startAccessingSecurityScopedResource()
            let destinationURL = songsDir.appendingPathComponent(url.lastPathComponent)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }

            do {
                let data = try Data(contentsOf: url)
                try data.write(to: destinationURL, options: .atomic)
                importCount += 1
            } catch {
                print("Failed to write data directly: \(error). Using copy fallback...")
                do {
                    try fileManager.copyItem(at: url, to: destinationURL)
                    importCount += 1
                } catch {
                    print("Failed copyItem fallback: \(error)")
                }
            }

            if shouldAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        loadLocalTracks()
        showToast(message: "Imported \(importCount) song(s)", success: true)
    }

    func removeFromPlaylist(track: Track, name: String) {
        var list = playlists[name] ?? []
        let filename = track.url.lastPathComponent
        if let idx = list.firstIndex(of: filename) {
            list.remove(at: idx)
            playlists[name] = list
            savePlaylists()
            filterTracks()
            showToast(message: "Removed from \(name)", success: true)
        }
    }

    func deleteTrack(at index: Int) {
        let track = filteredTracks[index]

        // Stop active playing if deleted
        if currentTrackIndex == index {
            audioPlayer?.stop()
            audioPlayer = nil
            updateTimer?.invalidate()
            currentTrackIndex = nil
        }

        try? FileManager.default.removeItem(at: track.url)
        loadLocalTracks()
        showToast(message: "Removed song from shelf", success: true)
    }

    // MARK: - Mini Player Interaction

    @objc func miniPlayerTapped(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: miniPlayerView)
        let previousFrame = miniPreviousButton.convert(miniPreviousButton.bounds, to: miniPlayerView)
        let playFrame = miniPlayPauseButton.convert(miniPlayPauseButton.bounds, to: miniPlayerView)
        let nextFrame = miniNextButton.convert(miniNextButton.bounds, to: miniPlayerView)
        if previousFrame.contains(location) || playFrame.contains(location) || nextFrame.contains(location) {
            return
        }

        // Scroll to Page 2
        let width = scrollView.frame.size.width
        scrollView.setContentOffset(CGPoint(x: width * 2, y: 0), animated: true)
    }

    func updateMiniPlayerUI() {
        guard !filteredTracks.isEmpty else {
            miniTitleLabel?.text = "No Tracks Loaded"
            miniArtistLabel?.text = "Import music files to begin"
            miniPlayPauseButton?.isEnabled = false
            miniPreviousButton?.isEnabled = false
            miniNextButton?.isEnabled = false
            applyMiniPlayerColors(useArtworkBackground: false)
            miniPlayerView?.backgroundColor = miniPlayerBackgroundColor()
            miniCoverView?.image = UIImage(named: "PlaceholderArtwork")
            return
        }

        miniPlayPauseButton?.isEnabled = true
        miniPreviousButton?.isEnabled = true
        miniNextButton?.isEnabled = true

        guard let index = currentTrackIndex, index < filteredTracks.count else {
            miniTitleLabel?.text = "No Track Selected"
            miniArtistLabel?.text = "Select a song below"
            miniPlayPauseButton?.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
            applyMiniPlayerColors(useArtworkBackground: false)
            miniPlayerView?.backgroundColor = miniPlayerBackgroundColor()
            miniCoverView?.image = UIImage(named: "PlaceholderArtwork")
            return
        }

        let track = filteredTracks[index]
        miniTitleLabel?.text = track.title
        if track.artist != "Unknown Artist" && !track.artist.isEmpty {
            miniArtistLabel?.text = track.artist
            miniArtistLabel?.isHidden = false
        } else {
            miniArtistLabel?.text = ""
            miniArtistLabel?.isHidden = true
        }

        let isPlaying = audioPlayer?.isPlaying == true
        let playIcon = isPlaying ? "pause.fill" : "play.fill"
        miniPlayPauseButton?.setImage(UIImage(systemName: playIcon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)

        if let artwork = track.artwork {
            miniCoverView?.image = artwork
            if #available(iOS 26.0, *) {
                applyMiniPlayerColors(useArtworkBackground: false)
                miniPlayerView?.backgroundColor = .clear
            } else {
                applyMiniPlayerColors(useArtworkBackground: true)
                miniPlayerView?.backgroundColor = artwork.spotifyPanelColor
            }
        } else {
            applyMiniPlayerColors(useArtworkBackground: false)
            miniCoverView?.image = UIImage(named: "PlaceholderArtwork")
            if #available(iOS 26.0, *) {
                miniPlayerView?.backgroundColor = .clear
            } else {
                miniPlayerView?.backgroundColor = miniPlayerBackgroundColor()
            }
        }

    }

    private func applyMiniPlayerColors(useArtworkBackground: Bool) {
        miniTitleLabel?.textColor = useArtworkBackground ? .white : primaryTextColor()
        miniArtistLabel?.textColor = useArtworkBackground
            ? UIColor.white.withAlphaComponent(0.68)
            : secondaryTextColor()
        let controlsColor = useArtworkBackground ? UIColor.white : primaryTextColor()
        miniPreviousButton?.tintColor = controlsColor
        miniPlayPauseButton?.tintColor = controlsColor
        miniNextButton?.tintColor = controlsColor
    }

    @objc func updateFilterPillBorders() {
        let borderCol = cardBorderColor().resolvedColor(with: self.view.traitCollection).cgColor
        for subview in filtersStackView?.arrangedSubviews ?? [] {
            if let button = subview as? UIButton {
                if button.layer.borderWidth > 0 {
                    button.layer.borderColor = borderCol
                }
            }
        }
    }
}

private extension UIImage {
    var spotifyPanelColor: UIColor {
        guard let input = CIImage(image: self) else {
            return UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
        }

        let extent = input.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else {
            return UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let red = max(0.08, CGFloat(bitmap[0]) / 255.0 * 0.48)
        let green = max(0.08, CGFloat(bitmap[1]) / 255.0 * 0.48)
        let blue = max(0.08, CGFloat(bitmap[2]) / 255.0 * 0.48)
        return UIColor(red: red, green: green, blue: blue, alpha: 0.98)
    }
}

// MARK: - UISearchBarDelegate
extension ViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterTracks()
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
