import UIKit
import UniformTypeIdentifiers

extension ViewController {
    func lyricsQuery(for track: Track) -> LyricsQuery {
        let engineDuration = audioPlayer?.url == track.url ? audioPlayer?.duration : nil
        let duration = engineDuration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? track.duration
        return LyricsQuery(title: track.title, artist: track.artist, album: "", duration: duration)
    }
    func setupLyrics() {
        lyricsView = LyricsView()
        lyricsView.translatesAutoresizingMaskIntoConstraints = false
        lyricsView.isHidden = true
        coverCarouselContainer.superview!.addSubview(lyricsView)
        NSLayoutConstraint.activate([
            lyricsView.topAnchor.constraint(equalTo: coverCarouselContainer.topAnchor),
            lyricsView.bottomAnchor.constraint(equalTo: coverCarouselContainer.bottomAnchor),
            lyricsView.leadingAnchor.constraint(equalTo: coverCarouselContainer.leadingAnchor),
            lyricsView.trailingAnchor.constraint(equalTo: coverCarouselContainer.trailingAnchor)
        ])
        lyricsView.seek = { [weak self] time in self?.seek(to: time); self?.updateLyrics() }
        lyricsView.search = { [weak self] in self?.loadLyrics(force: true) }
        lyricsView.imported = { [weak self] in self?.importLyrics() }
        lyricsView.paste = { [weak self] in self?.pasteLyrics() }
    }
    func setLyricsVisible(_ visible: Bool) {
        lyricsVisible = visible
        let changes = {
            self.coverCarouselContainer.isHidden = visible
            self.coverCarouselContainer.accessibilityElementsHidden = visible
            self.lyricsView.isHidden = !visible
        }
        if UIAccessibility.isReduceMotionEnabled { changes() }
        else { UIView.transition(with: coverCarouselContainer.superview!, duration: 0.18,
            options: [.transitionCrossDissolve, .allowAnimatedContent], animations: changes) }
        if visible { loadLyrics() }
        else { applyCarouselLayout(isPlaying: audioPlayer?.isPlaying == true, animated: false) }
        updatePlayerOptionsMenu()
    }
    func updateLyrics() {
        guard lyricsVisible else { return }
        if lyricsTrackURL != audioPlayer?.url { loadLyrics() }
        lyricsView.update(time: audioPlayer?.currentTime ?? 0)
    }
    func loadLyrics(force: Bool = false, track requestedTrack: Track? = nil) {
        guard let track = requestedTrack ?? currentPlaybackTrack(), lyricsVisible else { return }
        if !force && lyricsTrackURL == track.url && lyricsTask != nil { return }
        lyricsTask?.cancel()
        lyricsGeneration += 1
        let generation = lyricsGeneration
        lyricsTrackURL = track.url; lyricsIdentity = ""
        lyricsView.display(nil, loading: true)
        lyricsTask = Task { [weak self] in
            let query = self?.lyricsQuery(for: track) ?? LyricsQuery(title: track.title, artist: track.artist, album: "", duration: track.duration)
            let result = await LyricsService.shared.load(url: track.url, query: query, force: force)
            guard !Task.isCancelled, let self, self.lyricsGeneration == generation else { return }
            self.lyricsIdentity = result.0
            self.lyricsView.display(result.1, state: result.2)
            self.lyricsView.update(time: self.audioPlayer?.currentTime ?? 0)
        }
    }
    func lyricsMenu() -> UIMenu {
        let toggle = UIAction(title: lyricsVisible ? "View Artwork" : "Lyrics", image: UIImage(systemName: "text.alignleft")) { [weak self] _ in
            guard let self else { return }; self.setLyricsVisible(!self.lyricsVisible)
        }
        let manage = UIMenu(title: "Lyrics Options", children: [
            UIAction(title: "Lyrics Source", image: UIImage(systemName: "list.bullet")) { [weak self] _ in self?.chooseLyricsVersion() },
            UIAction(title: "Search Again", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in self?.setLyricsVisible(true); self?.loadLyrics(force: true) },
            UIAction(title: "Import Lyrics", image: UIImage(systemName: "doc")) { [weak self] _ in self?.importLyrics() },
            UIAction(title: "Paste Lyrics", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in self?.pasteLyrics() },
            UIAction(title: "Adjust Sync", image: UIImage(systemName: "clock")) { [weak self] _ in self?.adjustLyrics() },
            UIAction(title: "Remove Imported Lyrics", attributes: .destructive) { [weak self] _ in
                guard let self, !self.lyricsIdentity.isEmpty else { return }
                let id = self.lyricsIdentity
                Task { await LyricsService.shared.imported(nil, id: id); self.lyricsTrackURL = nil; self.loadLyrics() }
            }
        ])
        return UIMenu(title: "", options: .displayInline, children: [toggle, manage])
    }
    func importLyrics() {
        guard let track = currentPlaybackTrack() else { return }
        lyricsImportTrack = track
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: ["lrc", "ttml", "yrc", "krc", "qrc", "txt"].map { UTType(filenameExtension: $0) ?? .plainText }, asCopy: false)
        picker.delegate = self; picker.view.tag = 9321
        present(picker, animated: true)
    }
    func acceptLyrics(_ text: String, track: Track, format: String = "lrc") {
        Task {
            let id = await LyricsService.shared.identifier(url: track.url)
            guard !id.isEmpty else { return }
            let doc = LyricsFormats.parse(text, format: format, source: "Imported")
            guard !doc.lines.isEmpty else { showToast(message: "This file contains no lyrics", success: false); return }
            await LyricsService.shared.imported(doc, id: id)
            if currentPlaybackTrack()?.url == track.url { setLyricsVisible(true); loadLyrics(force: true) }
        }
    }
    func pasteLyrics() {
        guard let track = currentPlaybackTrack() else { return }
        let alert = UIAlertController(title: "Paste Lyrics", message: "Paste plain text or LRC timestamps.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Lyrics" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import Clipboard", style: .default) { [weak self] _ in
            if let text = UIPasteboard.general.string { self?.acceptLyrics(text, track: track) }
        })
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self, weak alert] _ in self?.acceptLyrics(alert?.textFields?.first?.text ?? "", track: track) })
        present(alert, animated: true)
    }
    func chooseLyricsVersion() {
        guard let track = currentPlaybackTrack() else { return }
        if !lyricsVisible { setLyricsVisible(true) }
        Task {
            let catalog = await LyricsService.shared.sourceCatalog(url: track.url, query: lyricsQuery(for: track))
            guard currentPlaybackTrack()?.url == track.url else { return }
            let (id, query, results, attempts, failure) = catalog
            let entry = await LyricsService.shared.store.read(id)
            var details = ["\(query.searchTitle) — \(query.searchArtist)"]
            details += attempts.map { "\($0.name): \($0.summary)" }
            if results.isEmpty {
                let incomplete = failure != nil || attempts.isEmpty || attempts.allSatisfy(\.failed)
                details.append(incomplete ? "Search could not be completed. Retry or copy search details below." : "No matching versions. Retry or edit the search below.")
            }
            let alert = UIAlertController(title: "Lyrics Source", message: details.joined(separator: "\n"), preferredStyle: .actionSheet)
            if !results.isEmpty || entry.selected != nil {
                alert.addAction(UIAlertAction(title: "Automatic", style: .default) { [weak self] _ in
                    Task {
                        await LyricsService.shared.automatic(id: id)
                        guard self?.currentPlaybackTrack()?.url == track.url else { return }
                        self?.lyricsTrackURL = nil; self?.loadLyrics(force: true)
                    }
                })
            }
            for candidate in results.prefix(20) {
                let document = candidate.document(query)
                let title = "\(candidate.providerID ?? "LRCLIB") · \(document.synchronizationLevel) — \(candidate.trackName), \(candidate.artistName)"
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    Task {
                        await LyricsService.shared.choose(candidate, query: query, id: id)
                        if self?.currentPlaybackTrack()?.url == track.url { self?.lyricsTrackURL = nil; self?.loadLyrics() }
                    }
                })
            }
            alert.addAction(UIAlertAction(title: "Search Again", style: .default) { [weak self] _ in
                guard self?.currentPlaybackTrack()?.url == track.url else { return }
                self?.loadLyrics(force: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.chooseLyricsVersion() }
            })
            alert.addAction(UIAlertAction(title: "Edit Search", style: .default) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.editLyricsSearch(track: track, id: id, query: query) }
            })
            if results.isEmpty {
                alert.addAction(UIAlertAction(title: "Copy Search Details", style: .default) { _ in
                    let fields: [String: Any] = [
                        "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                        "title": query.title, "artist": query.artist, "searchTitle": query.searchTitle,
                        "searchArtist": query.searchArtist, "album": query.album, "duration": query.duration,
                        "failure": failure ?? "none", "providers": attempts.map {
                            ["name": $0.name, "status": $0.summary, "results": $0.resultCount, "matches": $0.matchCount, "failed": $0.failed, "http": $0.statusCode.map { $0 as Any } ?? NSNull()] as [String: Any]
                        }
                    ]
                    if let data = try? JSONSerialization.data(withJSONObject: fields, options: [.prettyPrinted, .sortedKeys]) {
                        UIPasteboard.general.string = String(data: data, encoding: .utf8)
                    }
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.sourceView = playerOptionsButton
            present(alert, animated: true)
        }
    }
    func editLyricsSearch(track: Track, id: String, query: LyricsQuery) {
        guard currentPlaybackTrack()?.url == track.url else { return }
        let alert = UIAlertController(title: "Search Lyrics", message: "Song title and artist. Your audio file stays unchanged.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Song title"; $0.text = query.searchTitle; $0.autocorrectionType = .no }
        alert.addTextField { $0.placeholder = "Artist"; $0.text = query.hasArtist ? query.artist : ""; $0.autocorrectionType = .no }
        let apply: (LyricsSearchMetadata?) -> Void = { [weak self] metadata in
            Task {
                await LyricsService.shared.updateSearch(metadata, id: id)
                await LyricsService.shared.automatic(id: id)
                guard self?.currentPlaybackTrack()?.url == track.url else { return }
                self?.lyricsTrackURL = nil; self?.loadLyrics(force: true)
            }
        }
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak alert] _ in
            let title = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !artist.isEmpty else { return }
            apply(LyricsSearchMetadata(title: title, artist: artist))
        })
        alert.addAction(UIAlertAction(title: "Use File Metadata", style: .default) { _ in apply(nil) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    func adjustLyrics() {
        guard !lyricsIdentity.isEmpty else { return }
        let id = lyricsIdentity
        let key = lyricsView.document?.source == "Imported" ? "imported" : lyricsView.document?.resultKey ?? "legacy"
        Task {
            let current = await LyricsService.shared.adjustment(id: id, key: key)
            guard lyricsIdentity == id else { return }
            let alert = UIAlertController(title: "Lyrics Sync", message: String(format: "Current offset: %+.2fs\nPositive delays lyrics; negative advances them.", current), preferredStyle: .alert)
            alert.addTextField { $0.text = String(format: "%.2f", current); $0.keyboardType = .numbersAndPunctuation }
            let apply: (Double) -> Void = { [weak self] value in
                Task { await LyricsService.shared.adjust(value, id: id, key: key)
                    if self?.lyricsIdentity == id { self?.lyricsTrackURL = nil; self?.loadLyrics() }
                }
            }
            alert.addAction(UIAlertAction(title: "−0.5s", style: .default) { _ in apply(current - 0.5) })
            alert.addAction(UIAlertAction(title: "+0.5s", style: .default) { _ in apply(current + 0.5) })
            alert.addAction(UIAlertAction(title: "Reset", style: .default) { _ in apply(0) })
            alert.addAction(UIAlertAction(title: "Save Precise Offset", style: .default) { [weak alert] _ in
                guard let value = Double(alert?.textFields?.first?.text ?? ""), value.isFinite, abs(value) <= 600 else { return }; apply(value)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
}
