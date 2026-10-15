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
        return nil
    }
    
    // MARK: - Cell Long Press Gesture Handler
    
    @objc func handleCellLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point),
              indexPath.row < filteredTracks.count else { return }
        
        let track = filteredTracks[indexPath.row]
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        presentTrackContextMenu(for: track, at: indexPath.row, isPlayer: false)
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
