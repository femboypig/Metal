import UIKit

extension ViewController {
    func setupPlayerPresentation() {
        playerDismissPan = UIPanGestureRecognizer(target: self, action: #selector(dragPlayerDown(_:)))
        playerDismissPan.delegate = self
        playerDismissPan.maximumNumberOfTouches = 1
        page2.addGestureRecognizer(playerDismissPan)
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

    func setPlayerPresented(_ presented: Bool, animated: Bool = true) {
        view.endEditing(true)
        view.layoutIfNeeded()
        stopPlayerPresentationMotion()
        playerPresentationStart = playerPresentation
        playerPresentationTarget = presented ? 1 : 0
        playerPresentationDuration = presented ? (playerPresentation > 0.9 ? 0.16 : 0.34) : 0.28
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
        if playerPresentationTime == 0 { playerPresentationTime = link.timestamp }
        let elapsed = link.targetTimestamp - playerPresentationTime
        playerPresentation = CGFloat(PlayerPresentationMotion.position(start: Double(playerPresentationStart),
            target: Double(playerPresentationTarget), elapsed: elapsed, duration: playerPresentationDuration))
        renderPlayerPresentation()
        if elapsed >= playerPresentationDuration {
            stopPlayerPresentationMotion()
            UIAccessibility.post(notification: .screenChanged,
                argument: playerPresentationTarget == 1 ? playerDismissButton : miniPlayerView)
        }
    }

    func renderPlayerPresentation() {
        guard let page2, let playerSlidingSurface else { return }
        let progress = min(1, max(0, playerPresentation))
        // The host and its safe-area layout stay fixed; only the inner surface slides.
        playerSlidingSurface.transform = CGAffineTransform(translationX: 0,
            y: (1 - progress) * view.bounds.height)
        playerScrim.alpha = 0.18 * progress
        page2.isHidden = progress == 0 && playerPresentationTarget == 0
        playerScrim.isHidden = progress == 0
        page1.isUserInteractionEnabled = progress == 0
        updatePulseVisibility()
    }

    @objc func dragPlayerDown(_ gesture: UIPanGestureRecognizer) {
        // Crossing the threshold hands control to the closing animation, even while held.
        // Remaining changed/ended/cancelled events from that touch cannot reverse it.
        if gesture.state == .began {
            playerDismissCommitted = false
            stopPlayerPresentationMotion()
        }
        guard !playerDismissCommitted else { return }
        let distance = Double(gesture.translation(in: view).y)
        let velocity = Double(gesture.velocity(in: view).y)
        switch gesture.state {
        case .began, .changed, .ended:
            if PlayerPresentationMotion.shouldCommitPull(translation: distance, velocity: velocity) {
                playerDismissCommitted = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
                setPlayerPresented(false)
            } else if gesture.state == .ended {
                setPlayerPresented(true)
            } else {
                let offset = PlayerPresentationMotion.pullOffset(translation: distance)
                playerPresentation = 1 - CGFloat(offset) / max(1, view.bounds.height)
                renderPlayerPresentation()
            }
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
