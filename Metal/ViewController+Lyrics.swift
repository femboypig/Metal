import UIKit
import UniformTypeIdentifiers

extension ViewController {
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
        coverCarouselContainer.isHidden = visible
        coverCarouselContainer.accessibilityElementsHidden = visible
        lyricsView.isHidden = !visible
        if visible { loadLyrics() }
        else { applyCarouselLayout(isPlaying: audioPlayer?.isPlaying == true, animated: false) }
        updatePlayerOptionsMenu()
    }
    func updateLyrics() {
        guard lyricsVisible else { return }
        if lyricsTrackURL != audioPlayer?.url { loadLyrics() }
        lyricsView.update(time: audioPlayer?.currentTime ?? 0)
    }
    func loadLyrics(force: Bool = false) {
        guard let track = currentPlaybackTrack(), lyricsVisible else { return }
        if !force && lyricsTrackURL == track.url && lyricsTask != nil { return }
        lyricsTask?.cancel()
        lyricsGeneration += 1
        let generation = lyricsGeneration
        lyricsTrackURL = track.url; lyricsIdentity = ""
        lyricsView.display(nil, loading: true)
        lyricsTask = Task { [weak self] in
            let query = LyricsQuery(title: track.title, artist: track.artist, album: "", duration: track.duration)
            let result = await LyricsService.shared.load(url: track.url, query: query, force: force)
            guard !Task.isCancelled, let self, self.lyricsGeneration == generation else { return }
            self.lyricsIdentity = result.0
            self.lyricsView.display(result.1)
            self.lyricsView.update(time: self.audioPlayer?.currentTime ?? 0)
        }
    }
    func lyricsMenu() -> UIMenu {
        let toggle = UIAction(title: lyricsVisible ? "View Artwork" : "Lyrics", image: UIImage(systemName: "text.alignleft")) { [weak self] _ in
            guard let self else { return }; self.setLyricsVisible(!self.lyricsVisible)
        }
        let manage = UIMenu(title: "Lyrics Options", children: [
            UIAction(title: "Search Again", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in self?.setLyricsVisible(true); self?.loadLyrics(force: true) },
            UIAction(title: "Import Lyrics", image: UIImage(systemName: "doc")) { [weak self] _ in self?.importLyrics() },
            UIAction(title: "Paste Lyrics", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in self?.pasteLyrics() },
            UIAction(title: "Adjust Sync", image: UIImage(systemName: "clock")) { [weak self] _ in self?.adjustLyrics() },
            UIAction(title: "Remove Imported Lyrics", attributes: .destructive) { [weak self] _ in
                guard let self, !self.lyricsIdentity.isEmpty else { return }
                let id = self.lyricsIdentity
                Task { await LyricsService.shared.imported(nil, id: id); self.loadLyrics(force: true) }
            }
        ])
        return UIMenu(title: "", options: .displayInline, children: [toggle, manage])
    }
    func importLyrics() {
        guard let track = currentPlaybackTrack() else { return }
        lyricsImportTrack = track
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "lrc") ?? .plainText, .plainText], asCopy: false)
        picker.delegate = self; picker.view.tag = 9321
        present(picker, animated: true)
    }
    func acceptLyrics(_ text: String, track: Track) {
        Task {
            let result = await LyricsService.shared.load(url: track.url, query: LyricsQuery(title: track.title, artist: track.artist, album: "", duration: track.duration))
            guard !result.0.isEmpty else { return }
            let doc = LyricsParser.parse(text, source: "Imported")
            guard !doc.lines.isEmpty else { showToast(message: "This file contains no lyrics", success: false); return }
            await LyricsService.shared.imported(doc, id: result.0)
            if currentPlaybackTrack()?.url == track.url { setLyricsVisible(true); loadLyrics(force: true) }
        }
    }
    func pasteLyrics() {
        guard let track = currentPlaybackTrack() else { return }
        let alert = UIAlertController(title: "Paste Lyrics", message: "Paste plain text or LRC timestamps.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Lyrics" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self, weak alert] _ in self?.acceptLyrics(alert?.textFields?.first?.text ?? "", track: track) })
        present(alert, animated: true)
    }
    func adjustLyrics() {
        guard !lyricsIdentity.isEmpty else { return }
        let id = lyricsIdentity
        let alert = UIAlertController(title: "Adjust Sync", message: "Seconds: positive delays lyrics; negative advances them.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "0.0"; $0.keyboardType = .numbersAndPunctuation }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let value = Double(alert?.textFields?.first?.text ?? ""), value.isFinite, abs(value) <= 600 else { return }
            Task { await LyricsService.shared.adjust(value, id: id); self?.loadLyrics(force: true) }
        })
        present(alert, animated: true)
    }
}
