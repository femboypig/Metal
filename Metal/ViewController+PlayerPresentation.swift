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

    func setPlayerPresented(_ presented: Bool, animated: Bool = true, velocity: CGFloat = 0) {
        view.endEditing(true)
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
        guard page2 != nil else { return }
        let progress = min(1, max(0, playerPresentation))
        // The library stays fixed. The player rises above it and its artwork settles separately.
        page2.transform = CGAffineTransform(translationX: 0, y: (1 - progress) * view.bounds.height)
        page2.layer.cornerRadius = 30 * min(1, (1 - progress) * 5)
        let settle = 1 - progress
        coverCarouselContainer?.transform = CGAffineTransform(translationX: 0, y: settle * 22)
            .scaledBy(x: 1 - settle * 0.045, y: 1 - settle * 0.045)
        playerScrim.alpha = 0.22 * progress
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
        case .changed:
            playerPresentation = min(1, max(0, playerPanStart - gesture.translation(in: view).y / height))
            renderPlayerPresentation()
        case .ended:
            let dismiss = PlayerPresentationMotion.shouldDismiss(progress: Double(playerPresentation),
                velocity: Double(velocity), height: Double(height))
            setPlayerPresented(!dismiss, velocity: -velocity / height)
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
            coverDragTransforms = cards.map(\.transform)
            cards.forEach { $0.layer.removeAllAnimations() }
        case .changed:
            let distance = gesture.translation(in: page2).x
            let available = distance < 0 ? getNextTrack() != nil : getPreviousTrack() != nil
            let offset = available ? distance : distance * 0.18
            for (card, base) in zip(cards, coverDragTransforms) {
                var transform = base
                transform.tx += offset
                card.transform = transform
            }
        case .ended, .cancelled, .failed:
            isCoverDragging = false
            let direction = gesture.state == .ended ? PlayerPresentationMotion.coverDirection(
                translation: Double(gesture.translation(in: page2).x),
                velocity: Double(gesture.velocity(in: page2).x), width: 264) : 0
            if direction < 0, getNextTrack() != nil { playNextTrack() }
            else if direction > 0, getPreviousTrack() != nil { playPreviousTrack() }
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
