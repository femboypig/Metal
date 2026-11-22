import UIKit

extension ViewController {
    func setupPlayerPresentation() {
        playerDismissPan = UIPanGestureRecognizer(target: self, action: #selector(dragPlayerDown(_:)))
        playerDismissPan.delegate = self
        playerDismissPan.maximumNumberOfTouches = 1
        page2.addGestureRecognizer(playerDismissPan)
        playerSurfaceMask.fillColor = UIColor.black.cgColor
        page2.layer.mask = playerSurfaceMask
        playerTransitionArtwork = GlassArtworkImageView()
        playerTransitionArtwork.contentMode = .scaleAspectFill
        playerTransitionArtwork.clipsToBounds = true
        playerTransitionArtwork.isUserInteractionEnabled = false
        playerTransitionArtwork.layer.cornerCurve = .continuous
        view.addSubview(playerTransitionArtwork)
        page2.accessibilityViewIsModal = true
        page2.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Close player", target: self,
            selector: #selector(closePlayerAccessibility))]
        renderPlayerPresentation()
    }

    @objc func closePlayerAccessibility() -> Bool {
        setPlayerPresented(false)
        return true
    }

    func stopPlayerPresentationMotion() {
        playerPresentationLink?.invalidate()
        playerPresentationLink = nil
        playerPresentationTime = 0
    }

    func setPlayerPresented(_ presented: Bool, animated: Bool = true, velocity: CGFloat = 0) {
        view.endEditing(true)
        // Keep the fullscreen layout in window coordinates before any masking begins.
        // A transformed root changes inherited safe-area insets as it crosses the screen.
        view.layoutIfNeeded()
        if playerPresentation == 0 || playerPresentation == 1 {
            playerTransitionArtwork.setArtwork(coverImageView.image, seed: trackTitleLabel.text)
        }
        stopPlayerPresentationMotion()
        playerPresentationTarget = presented ? 1 : 0
        playerPresentationVelocity = velocity
        page1.accessibilityElementsHidden = presented
        page2.accessibilityElementsHidden = !presented
        if !animated || UIAccessibility.isReduceMotionEnabled {
            playerPresentation = playerPresentationTarget
            renderPlayerPresentation()
            return
        }
        page2.isHidden = false
        let driver = PlayerPresentationDriver(owner: self)
        let link = CADisplayLink(target: driver, selector: #selector(PlayerPresentationDriver.tick(_:)))
        playerPresentationLink = link
        link.add(to: .main, forMode: .common)
    }

    func tickPlayerPresentation(_ link: CADisplayLink) {
        let delta = playerPresentationTime == 0 ? link.targetTimestamp - link.timestamp : link.timestamp - playerPresentationTime
        playerPresentationTime = link.timestamp
        let result = PlayerPresentationMotion.step(position: Double(playerPresentation),
            velocity: Double(playerPresentationVelocity), target: Double(playerPresentationTarget), delta: delta)
        playerPresentation = CGFloat(result.position)
        playerPresentationVelocity = CGFloat(result.velocity)
        renderPlayerPresentation()
        if result.finished {
            stopPlayerPresentationMotion()
            UIAccessibility.post(notification: .screenChanged,
                argument: playerPresentationTarget == 1 ? playerDismissButton : miniPlayerView)
        }
    }

    func renderPlayerPresentation() {
        guard let page2, let miniPlayerView, let miniCoverView, let coverArtCard,
              let coverCarouselContainer, let playerTransitionArtwork else { return }
        let progress = min(1, max(0, playerPresentation))
        let miniFrame = miniPlayerView.convert(miniPlayerView.bounds, to: view)
        let surface = PlayerPresentationMotion.surfaceFrame(mini: miniFrame, full: view.bounds,
            progress: Double(progress))
        let miniCover = miniCoverView.convert(miniCoverView.bounds, to: view)
        let fullCover = coverArtCard.convert(coverArtCard.bounds, to: view)
        let artworkFrame = PlayerPresentationMotion.surfaceFrame(mini: miniCover, full: fullCover,
            progress: Double(progress))
        let contentAlpha = CGFloat(PlayerPresentationMotion.reveal(Double(progress), from: 0.3, to: 0.88))
        let coverAlpha = CGFloat(PlayerPresentationMotion.reveal(Double(progress), from: 0.86, to: 1))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Only the visible surface changes; safe areas and controls retain their final layout.
        page2.layer.mask = progress == 1 ? nil : playerSurfaceMask
        playerSurfaceMask.frame = page2.bounds
        playerSurfaceMask.path = UIBezierPath(roundedRect: surface,
            cornerRadius: miniPlayerView.layer.cornerRadius * (1 - progress)).cgPath
        for content in playerPresentationContent { content.alpha = contentAlpha }
        coverCarouselContainer.alpha = coverAlpha
        playerTransitionArtwork.frame = artworkFrame
        playerTransitionArtwork.layer.cornerRadius = 11 + 7 * progress
        playerTransitionArtwork.alpha = 1 - coverAlpha
        CATransaction.commit()
        playerScrim.alpha = 0.18 * progress
        let atRest = progress == 0 || progress == 1
        playerTransitionArtwork.isHidden = atRest
        miniPlayerView.alpha = progress == 0 ? 1 : 0
        page2.isHidden = progress == 0 && playerPresentationTarget == 0
        playerScrim.isHidden = progress == 0
        page1.isUserInteractionEnabled = progress == 0
        updatePulseVisibility()
    }

    @objc func dragPlayerDown(_ gesture: UIPanGestureRecognizer) {
        let height = max(1, view.bounds.height)
        let velocity = gesture.velocity(in: view).y
        switch gesture.state {
        case .began:
            playerPanStart = playerPresentation
            stopPlayerPresentationMotion()
            playerTransitionArtwork.setArtwork(coverImageView.image, seed: trackTitleLabel.text)
        case .changed:
            playerPresentation = min(1, max(0, playerPanStart - max(0, gesture.translation(in: view).y - 24) * 0.85 / height))
            renderPlayerPresentation()
        case .ended:
            let dismiss = PlayerPresentationMotion.shouldDismiss(progress: Double(playerPresentation),
                translation: Double(gesture.translation(in: view).y), velocity: Double(velocity), height: Double(height))
            setPlayerPresented(!dismiss, velocity: dismiss ? -velocity / height : 0)
        case .cancelled, .failed:
            setPlayerPresented(true)
        default: break
        }
    }

    @objc func dragPlayerCovers(_ gesture: UIPanGestureRecognizer) {
        let cards = [leftCoverCard!, coverArtCard!, rightCoverCard!]
        switch gesture.state {
        case .began:
            isCoverDragging = true
            coverDragTransforms = cards.map { $0.layer.presentation()?.affineTransform() ?? $0.transform }
            for (card, transform) in zip(cards, coverDragTransforms) {
                card.layer.removeAllAnimations()
                card.transform = transform
            }
            Track.preheatArtwork(for: [getTrackAfterNext()?.url, getTrackBeforePrevious()?.url].compactMap { $0 })
        case .changed:
            let distance = gesture.translation(in: page2).x
            let available = distance < 0 ? getNextTrack() != nil : getPreviousTrack() != nil
            let offset = available ? distance : distance * 0.18
            let sideOffset = max(1, abs(coverDragTransforms[distance < 0 ? 2 : 0].tx))
            let fraction = min(1, abs(offset) / sideOffset)
            let playingScale: CGFloat = audioPlayer?.isPlaying == true ? 1.18 : 1
            for (index, card) in cards.enumerated() {
                let base = coverDragTransforms[index]
                var transform = base
                transform.tx += offset
                if index == 1 {
                    transform.a = base.a + (1 - base.a) * fraction
                    transform.d = transform.a
                } else if index == (distance < 0 ? 2 : 0) {
                    transform.a = base.a + (playingScale - base.a) * fraction
                    transform.d = transform.a
                }
                card.transform = transform
            }
        case .ended, .cancelled, .failed:
            isCoverDragging = false
            let direction = gesture.state == .ended ? PlayerPresentationMotion.coverDirection(
                translation: Double(gesture.translation(in: page2).x),
                velocity: Double(gesture.velocity(in: page2).x), width: 264) : 0
            coverReleaseVelocity = gesture.velocity(in: page2).x
            if direction < 0, getNextTrack() != nil {
                animateCarouselSlide(direction: .forward, incomingTrack: getTrackAfterNext(), commitsSwipe: true)
            } else if direction > 0, getPreviousTrack() != nil {
                animateCarouselSlide(direction: .backward, incomingTrack: getTrackBeforePrevious(), commitsSwipe: true)
            }
            if !isCarouselAnimating {
                applyCarouselLayout(isPlaying: audioPlayer?.isPlaying == true, animated: true)
            }
            coverDragTransforms.removeAll()
        default: break
        }
    }
}

private final class PlayerPresentationDriver: NSObject {
    weak var owner: ViewController?
    init(owner: ViewController) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        guard let owner else { link.invalidate(); return }
        owner.tickPlayerPresentation(link)
    }
}
