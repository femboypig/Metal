//
//  ViewController+TableView.swift
//  Metal
//

import UIKit

extension ViewController {

    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredTracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.identifier, for: indexPath) as! TrackCell
        let track = filteredTracks[indexPath.row]
        let isPlaying = (audioPlayer != nil && audioPlayer?.url == track.url)
        
        cell.configure(with: track, index: indexPath.row, isPlaying: isPlaying, colors: self)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56.0
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        recordManualSelection(for: filteredTracks[indexPath.row])
        playbackQueue = filteredTracks
        currentPlaybackContext = activeFilterHeaderTitle()
        currentTrackIndex = indexPath.row
        if isShuffleEnabled {
            rebuildShuffleQueue()
        }
        playCurrentTrack()
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.row < filteredTracks.count else { return nil }
        let track = filteredTracks[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            return self?.makeTrackContextMenu(for: track, at: indexPath.row, isPlayer: false)
        }
    }
    
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [weak self] in
            guard let indexPath = configuration.identifier as? IndexPath,
                  let self = self,
                  indexPath.row < self.filteredTracks.count else { return }
            self.tableView(self.tableView, didSelectRowAt: indexPath)
        }
    }
    
    // MARK: - Cell Long Press Gesture Handler
    
    @objc func handleCellLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        
        let track = filteredTracks[indexPath.row]
        
        let feedback = UINotificationFeedbackGenerator()
        feedback.prepare()
        feedback.notificationOccurred(.success)
        
        let items = [
            BottomSheetItem(title: "Add to Playlist", iconName: "plus.circle", isDestructive: false, action: { [weak self] in
                self?.showAddToPlaylistSelector(track: track)
            }),
            BottomSheetItem(title: "Share Song", iconName: "square.and.arrow.up", isDestructive: false, action: { [weak self] in
                let shareVC = UIActivityViewController(activityItems: [track.url], applicationActivities: nil)
                self?.present(shareVC, animated: true)
            }),
            BottomSheetItem(title: "Delete Song", iconName: "trash", isDestructive: true, action: { [weak self] in
                self?.deleteTrack(at: indexPath.row)
            })
        ]
        
        presentCustomBottomSheet(title: track.title, subtitle: track.artist, items: items)
    }
}

// MARK: - CylinderTableView Subclass

class CylinderTableView: UITableView {
    var onLayoutSubviews: (() -> Void)?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutSubviews?()
    }
}
