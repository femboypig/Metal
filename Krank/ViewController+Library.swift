//
//  ViewController+Library.swift
//  Krank
//

import UIKit
import CoreImage

extension ViewController {

    // MARK: - Local Persistence Loading

    func loadLocalUserData() {
        favoriteTracks = Set(UserDefaults.standard.stringArray(forKey: "Krank_Favorites") ?? [])
        playlists = UserDefaults.standard.dictionary(forKey: "Krank_Playlists") as? [String: [String]] ?? [:]
    }

    func savePlaylists() {
        UserDefaults.standard.set(playlists, forKey: "Krank_Playlists")
    }

    // MARK: - Playlists Pill Selector Generator

    func rebuildFiltersRow() {
        filtersStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 1. "All" Pill
        let allPill = createPillButton(title: "All", category: .all)
        filtersStackView.addArrangedSubview(allPill)

        // 2. "Favorites" Pill
        let favPill = createPillButton(title: "Favorites", category: .favorites)
        filtersStackView.addArrangedSubview(favPill)

        // 3. Custom Playlist Pills
        for name in playlists.keys.sorted() {
            let pill = createPillButton(title: name, category: .playlist(name))

            // Long press to delete custom playlist
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(playlistPillLongPressed(_:)))
            pill.addGestureRecognizer(longPress)

            filtersStackView.addArrangedSubview(pill)
        }

        // 4. "+ Playlist" Pill
        let newPill = UIButton(type: .system)
        newPill.translatesAutoresizingMaskIntoConstraints = false
        newPill.setTitle("＋ Playlist", for: .normal)
        newPill.backgroundColor = cardBackgroundColor()
        newPill.layer.cornerRadius = 15
        newPill.layer.borderWidth = 0

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.baseForegroundColor = secondaryTextColor()
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                return outgoing
            }
            newPill.configuration = config
        } else {
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

        if #available(iOS 15.0, *) {
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

        if isActive {
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

        let categories: [FilterCategory] = [.all, .favorites] + playlists.keys.sorted().map { .playlist($0) }
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
        case .favorites:
            categoryTracks = tracks.filter { favoriteTracks.contains($0.url.lastPathComponent) }
            headerText = "FAVORITES"
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
        UserDefaults.standard.set(Array(favoriteTracks), forKey: "Krank_Favorites")
        tableView.reloadData()

        if activeFilter == .favorites {
            filterTracks()
        }
        updatePlayerFavoriteButton()
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
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory not available")
        }
        let songsFolder = documentsURL.appendingPathComponent("Songs", isDirectory: true)
        if !fileManager.fileExists(atPath: songsFolder.path) {
            try? fileManager.createDirectory(at: songsFolder, withIntermediateDirectories: true, attributes: nil)
        }
        return songsFolder
    }

    func loadLocalTracks() {
        let fileManager = FileManager.default
        let songsDir = songsDirectoryURL
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "wma", "aiff", "alac"]

        // Migrate legacy loose audio files from root Documents directory to Songs directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
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

            tracks = audioFiles.map { Track(url: $0) }
            tracks.sort { $0.title.localizedCompare($1.title) == .orderedAscending }

            filterTracks()
        } catch {
            print("Failed to scan songs directory: \(error)")
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
            miniPlayerView?.backgroundColor = UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
            miniCoverView?.image = UIImage(named: "logo")
            return
        }

        miniPlayPauseButton?.isEnabled = true
        miniPreviousButton?.isEnabled = true
        miniNextButton?.isEnabled = true

        guard let index = currentTrackIndex, index < filteredTracks.count else {
            miniTitleLabel?.text = "No Track Selected"
            miniArtistLabel?.text = "Select a song below"
            miniPlayPauseButton?.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
            miniPlayerView?.backgroundColor = UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
            miniCoverView?.image = UIImage(named: "logo")
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
            miniPlayerView?.backgroundColor = artwork.spotifyPanelColor
        } else {
            miniCoverView?.image = UIImage(named: "logo")
            miniPlayerView?.backgroundColor = UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
        }

    }

    @objc func updateFilterPillBorders() {
        let borderCol = cardBorderColor().resolvedColor(with: self.view.traitCollection).cgColor
        for subview in filtersStackView.arrangedSubviews {
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
