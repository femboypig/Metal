//
//  ViewController+Gestures.swift
//  Metal
//

import UIKit
import MediaPlayer

extension ViewController {

    // MARK: - Gestures & Category Swipe Actions
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let categories: [FilterCategory] = [.all, .favorites, .lovely] + playlists.keys.sorted().map { .playlist($0) }
        guard let currentIndex = categories.firstIndex(of: activeFilter) else { return }
        
        if gesture.direction == .left {
            let nextIndex = currentIndex + 1
            if nextIndex < categories.count {
                activeFilter = categories[nextIndex]
                filterTracks()
                rebuildFiltersRow()
                
                let feedback = UIImpactFeedbackGenerator(style: .light)
                feedback.prepare()
                feedback.impactOccurred()
                
                animateTableFilter(direction: .left)
            }
        } else if gesture.direction == .right {
            let prevIndex = currentIndex - 1
            if prevIndex >= 0 {
                activeFilter = categories[prevIndex]
                filterTracks()
                rebuildFiltersRow()
                
                let feedback = UIImpactFeedbackGenerator(style: .light)
                feedback.prepare()
                feedback.impactOccurred()
                
                animateTableFilter(direction: .right)
            }
        }
    }
    
    // MARK: - Transition Animations
    
    func animateTableFilter(direction: UISwipeGestureRecognizer.Direction) {
        let transition = CATransition()
        transition.type = .push
        transition.subtype = (direction == .left) ? .fromRight : .fromLeft
        transition.duration = 0.22
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tableView.layer.add(transition, forKey: kCATransition)
    }
    
    // MARK: - Keyboard Handling
    
    @objc func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        if let bottomConstraint = activeSheetBottomConstraint {
            bottomConstraint.constant = -keyboardHeight - 16
            
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            UIView.animate(withDuration: duration) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        if let bottomConstraint = activeSheetBottomConstraint {
            bottomConstraint.constant = -16
            
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            UIView.animate(withDuration: duration) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func dismissKeyboard() {
        searchBar.resignFirstResponder()
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView === tableView {
            scrollFeedbackGenerator.prepare()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Only apply the cylinder effect when the tableView itself is scrolling,
        // not the outer paging scrollView
        guard scrollView === tableView else { return }
        applyCylinderEffect()
        updateOverlayAlphas()
    }
    
    // MARK: - Cylinder / Drum-Roll Effect
    
    func updateOverlayAlphas() {
        guard let top = page1?.viewWithTag(7701),
              let bot = page1?.viewWithTag(7702) else { return }
        
        let offsetY = tableView.contentOffset.y
        let fadeLimit: CGFloat = 36.0
        
        // 1. Top overlay alpha transitions from 0.0 at rest to 1.0 after scrolling down 36pt
        if offsetY <= 0 {
            top.alpha = 0.0
        } else if offsetY < fadeLimit {
            top.alpha = offsetY / fadeLimit
        } else {
            top.alpha = 1.0
        }
        
        // 2. Bottom overlay alpha transitions from 0.0 at rest to 1.0 after scrolling up 36pt
        let tableHeight = tableView.bounds.height
        let contentHeight = tableView.contentSize.height
        let maxScrollY = contentHeight - tableHeight
        
        if maxScrollY <= 0 {
            bot.alpha = 0.0
        } else {
            let distFromBottom = maxScrollY - offsetY
            if distFromBottom <= 0 {
                bot.alpha = 0.0
            } else if distFromBottom < fadeLimit {
                bot.alpha = distFromBottom / fadeLimit
            } else {
                bot.alpha = 1.0
            }
        }
    }
    
    func applyCylinderEffect() {
        let tableHeight = tableView.bounds.height
        guard tableHeight > 0 else { return }

        let centerY = tableView.contentOffset.y + tableHeight / 2.0
        let radius: CGFloat = tableHeight * 0.48
        let maxAngle: CGFloat = .pi * 0.36

        let rowHeight: CGFloat = 56.0
        let currentOffset = tableView.contentOffset.y
        let roundedRow = Int(round(currentOffset / rowHeight))
        let maxRow = filteredTracks.count - 1
        
        if roundedRow >= 0 && roundedRow <= maxRow {
            if lastCenterRow != roundedRow {
                lastCenterRow = roundedRow
                scrollFeedbackGenerator.impactOccurred()
            }
        }
        
        for cell in tableView.visibleCells {
            let cellMidY = cell.frame.midY
            let deltaY = cellMidY - centerY

            let normY = max(min(deltaY / (tableHeight / 2.0), 1.0), -1.0)
            let theta = normY * maxAngle

            let tz = -radius * (1.0 - cos(theta)) * 0.25
            let projectedY = radius * sin(theta)
            let ty = (projectedY - deltaY) * 0.20
            let angle = -theta * 0.35
            let scale = 1.0 - abs(normY) * 0.04
            let alpha = max(0.42, cos(theta))

            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 1000.0
            transform = CATransform3DTranslate(transform, 0, ty, tz)
            transform = CATransform3DRotate(transform, angle, 1, 0, 0)
            transform = CATransform3DScale(transform, scale, scale, 1)

            cell.contentView.layer.transform = transform
            cell.contentView.alpha = alpha
        }
    }
    
    // MARK: - Artwork Animations
    
    func startArtworkAnimation() {
        coverArtCard?.layer.removeAllAnimations()
    }
    
    func stopArtworkAnimation() {
        coverArtCard?.layer.removeAllAnimations()
    }
    
    // MARK: - Toast Notifications
    
    func showToast(message: String, success: Bool) {
        if let existing = view.viewWithTag(999) {
            existing.removeFromSuperview()
        }
        
        let toast = UIView()
        toast.tag = 999
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.layer.cornerRadius = 20
        
        if success {
            toast.backgroundColor = UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.28, blue: 0.22, alpha: 0.95) : UIColor(red: 0.22, green: 0.35, blue: 0.28, alpha: 0.95)
            }
        } else {
            toast.backgroundColor = UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.18, blue: 0.12, alpha: 0.95) : UIColor(red: 0.65, green: 0.23, blue: 0.17, alpha: 0.95)
            }
        }
        
        view.addSubview(toast)
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont(name: "Georgia-BoldItalic", size: 14)
        label.text = message
        label.textAlignment = .center
        toast.addSubview(label)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: toast.centerYAnchor)
        ])
        
        toast.alpha = 0.0
        toast.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [], animations: {
            toast.alpha = 1.0;
            toast.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 2.0, options: [], animations: {
                toast.alpha = 0.0
                toast.transform = CGAffineTransform(translationX: 0, y: 10)
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        if time.isNaN || time.isInfinite { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Lockscreen Sync
    
    func updateNowPlayingInfo() {
        guard let index = currentTrackIndex, index < filteredTracks.count else { return }
        let track = filteredTracks[index]
        let duration = audioPlayer?.duration ?? track.duration
        let isPlaying = audioPlayer?.isPlaying == true
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        if track.artist != "Unknown Artist" && !track.artist.isEmpty {
            info[MPMediaItemPropertyArtist] = track.artist
        }
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPMediaItemPropertyAssetURL] = track.url
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer?.currentTime ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyExternalContentIdentifier] = track.url.lastPathComponent
        
        if let artwork = track.artwork ?? UIImage(named: "PlaceholderArtwork") {
            let squaredArtwork = artwork.squared()
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: squaredArtwork.size, requestHandler: { _ in squaredArtwork })
        }
        
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()
        nowPlayingCenter.nowPlayingInfo = info
        nowPlayingCenter.playbackState = isPlaying ? .playing : .paused

    }
    
    // MARK: - Persistence state
    
    func savePlaybackState() {
        if let index = currentTrackIndex, index < filteredTracks.count {
            UserDefaults.standard.set(filteredTracks[index].url.lastPathComponent, forKey: "Metal_LastTrackFile")
        }
        saveSettings()
    }
    
    func loadPlaybackState() {
        isRestoringPersistentState = true
        isShuffleEnabled = persistedSettings.shuffleEnabled
        isRepeatEnabled = persistedSettings.repeatEnabled
        
        if let lastFile = persistedSettings.lastTrackFile {
            if let index = filteredTracks.firstIndex(where: { $0.url.lastPathComponent == lastFile }) {
                currentTrackIndex = index
                let track = filteredTracks[index]
                
                trackTitleLabel.text = track.title
                
                if track.artist != "Unknown Artist" && !track.artist.isEmpty {
                    artistLabel.text = track.artist
                    artistLabel.isHidden = false
                } else {
                    artistLabel.text = ""
                    artistLabel.isHidden = true
                }
                
                if let artwork = track.artwork {
                    coverImageView.image = artwork
                } else {
                    coverImageView.image = UIImage(named: "PlaceholderArtwork")
                }
                
                let restoredPosition = min(max(0, persistedSettings.playbackPosition), track.duration)
                progressSlider.maximumValue = Float(track.duration)
                progressSlider.value = Float(restoredPosition)
                elapsedLabel.text = formatTime(restoredPosition)
                remainingLabel.text = "-" + formatTime(max(0, track.duration - restoredPosition))
                updatePlayerTheme(with: track.artwork)
            }
        }
        isRestoringPersistentState = false
        updatePlaybackButtons()
        updateMiniPlayerUI()
        updatePlayerFavoriteButton()
    }
}

// MARK: - UIImage Extension for Now Playing Symmetrical Artwork

fileprivate extension UIImage {
    func squared() -> UIImage {
        let originalWidth = self.size.width * self.scale
        let originalHeight = self.size.height * self.scale
        
        // If already square (or close to it), return directly
        if abs(originalWidth - originalHeight) < 1.0 {
            return self
        }
        
        let edge = min(originalWidth, originalHeight)
        
        let x = (originalWidth - edge) / 2.0
        let y = (originalHeight - edge) / 2.0
        
        let cropRect = CGRect(x: x, y: y, width: edge, height: edge)
        
        guard let cgImg = self.cgImage?.cropping(to: cropRect) else {
            return self
        }
        
        return UIImage(cgImage: cgImg, scale: self.scale, orientation: self.imageOrientation)
    }
}
