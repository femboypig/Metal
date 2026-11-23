import UIKit

extension ViewController {
    func setupPlayerPresentation() {
        playerDismissPan = UIPanGestureRecognizer(target: self, action: #selector(dragPlayerDown(_:)))
        playerDismissPan.delegate = self
        playerDismissPan.maximumNumberOfTouches = 1
        page2.addGestureRecognizer(playerDismissPan)
        playerTransitionCard = UIView()
        playerTransitionCard.isUserInteractionEnabled = false
        playerTransitionCard.clipsToBounds = true
        playerTransitionCard.layer.cornerCurve = .continuous
        playerTransitionCard.layer.addSublayer(playerTransitionGradient)
        playerTransitionGradient.startPoint = CGPoint(x: 0.5, y: 0)
        playerTransitionGradient.endPoint = CGPoint(x: 0.5, y: 1)
        page2.insertSubview(playerTransitionCard, belowSubview: playerSlidingSurface)
        playerTransitionArtwork = GlassArtworkImageView()
        playerTransitionArtwork.contentMode = .scaleAspectFill
        playerTransitionArtwork.clipsToBounds = true
        playerTransitionArtwork.layer.cornerCurve = .continuous
        playerTransitionArtwork.isUserInteractionEnabled = false
        page2.addSubview(playerTransitionArtwork)
        playerTransitionTitle = PlayerTransitionLabel()
        playerTransitionArtist = PlayerTransitionLabel()
        page2.addSubview(playerTransitionTitle)
        page2.addSubview(playerTransitionArtist)
        for button in [miniFavoriteButton!, miniPlayPauseButton!] {
            let icon = UIImageView()
            icon.contentMode = .scaleAspectFit
            page2.addSubview(icon)
            playerTransitionMiniControls.append((icon, button))
        }
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
        if playerPresentation == 0 || playerPresentation == 1 { preparePlayerTransition() }
        playerPresentationStart = playerPresentation
        playerPresentationTarget = presented ? 1 : 0
        playerPresentationDuration = presented ? (playerPresentation > 0.9 ? 0.16 : 0.46) : 0.38
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

    func preparePlayerTransition() {
        playerTransitionArtwork.setArtwork(coverImageView.image, seed: trackTitleLabel.text)
        playerTransitionTitle.configure(source: miniTitleLabel, destination: trackTitleLabel)
        playerTransitionArtist.configure(source: miniArtistLabel, destination: artistLabel)
        for (icon, button) in playerTransitionMiniControls {
            icon.image = button.currentImage
            icon.tintColor = button.tintColor
        }
    }

    func renderPlayerPresentation() {
        guard let page2, let playerSlidingSurface, let playerTransitionCard,
              let playerTransitionArtwork, let coverArtCard else { return }
        let progress = min(1, max(0, playerPresentation))
        let moving = progress > 0 && progress < 1
        let miniFrame = miniPlayerView.convert(miniPlayerView.bounds, to: view)
        let cardFrame = PlayerPresentationMotion.frame(source: miniFrame,
            destination: view.bounds, progress: Double(progress))
        let coverFrame = PlayerPresentationMotion.frame(
            source: miniCoverView.convert(miniCoverView.bounds, to: view),
            destination: coverArtCard.convert(coverArtCard.bounds, to: view), progress: Double(progress))
        let bodyAlpha = CGFloat(PlayerPresentationMotion.phase(Double(progress), from: 0.4, to: 0.85))
        let coverAlpha = CGFloat(PlayerPresentationMotion.phase(Double(progress), from: 0.82, to: 1))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Fullscreen layout never moves or resizes. Only this independent card and shared elements do.
        playerSlidingSurface.transform = .identity
        playerTransitionCard.frame = cardFrame
        playerTransitionCard.layer.cornerRadius = miniPlayerView.layer.cornerRadius * (1 - progress)
        playerTransitionCard.backgroundColor = miniPlayerBackgroundColor()
        playerTransitionGradient.frame = playerTransitionCard.bounds
        playerTransitionGradient.colors = playerGradientLayer.colors
        playerTransitionGradient.opacity = Float(PlayerPresentationMotion.phase(Double(progress), from: 0, to: 0.35))
        playerTransitionCard.isHidden = !moving
        playerGradientLayer.isHidden = progress < 1
        playerTransitionBody.alpha = progress == 0 ? 0 : bodyAlpha
        playerTransitionHeader.alpha = CGFloat(PlayerPresentationMotion.phase(Double(progress), from: 0.94, to: 1))
        playerTransitionFooter.alpha = CGFloat(PlayerPresentationMotion.phase(Double(progress), from: 0.55, to: 1))
        coverCarouselContainer.alpha = coverAlpha
        trackTitleLabel.alpha = moving ? 0 : 1
        artistLabel.alpha = moving ? 0 : 1
        playerTransitionArtwork.frame = coverFrame
        let fullCorner = coverArtCard.layer.cornerRadius * abs(coverArtCard.transform.a)
        playerTransitionArtwork.layer.cornerRadius = 11 + (fullCorner - 11) * progress
        playerTransitionArtwork.alpha = 1 - coverAlpha
        playerTransitionArtwork.isHidden = !moving
        let titleFrame = PlayerPresentationMotion.frame(source: miniTitleLabel.convert(miniTitleLabel.bounds, to: view),
            destination: trackTitleLabel.convert(trackTitleLabel.bounds, to: view), progress: Double(progress))
        playerTransitionTitle.render(frame: titleFrame, progress: progress)
        let artistFrame = PlayerPresentationMotion.frame(source: miniArtistLabel.convert(miniArtistLabel.bounds, to: view),
            destination: artistLabel.convert(artistLabel.bounds, to: view), progress: Double(progress))
        playerTransitionArtist.render(frame: artistFrame, progress: progress)
        playerTransitionTitle.isHidden = !moving
        playerTransitionArtist.isHidden = !moving
        for (icon, button) in playerTransitionMiniControls {
            if let source = button.imageView {
                icon.transform = .identity
                icon.frame = source.convert(source.bounds, to: view)
                icon.transform = CGAffineTransform(translationX: 0, y: cardFrame.minY - miniFrame.minY)
            }
            icon.alpha = 1 - CGFloat(PlayerPresentationMotion.phase(Double(progress), from: 0, to: 0.2))
            icon.isHidden = !moving
        }
        CATransaction.commit()
        miniPlayerView.alpha = progress == 0 ? 1 : 0
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
            preparePlayerTransition()
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

/// The source and destination fonts crossfade while their shared frame moves along the same path.
/// Text is always drawn at its actual font size, avoiding stretched snapshots.
final class PlayerTransitionLabel: UIView {
    private let source = UILabel()
    private let destination = UILabel()
    private var destinationHidden = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        addSubview(source)
        addSubview(destination)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(source from: UILabel, destination to: UILabel) {
        for (copy, original) in [(source, from), (destination, to)] {
            copy.text = original.text
            copy.font = original.font
            copy.textColor = original.textColor
            copy.textAlignment = original.textAlignment
            copy.numberOfLines = original.numberOfLines
            copy.lineBreakMode = original.lineBreakMode
        }
        destinationHidden = to.isHidden
    }

    func render(frame: CGRect, progress: CGFloat) {
        self.frame = frame
        source.frame = bounds
        destination.frame = bounds
        let blend = CGFloat(PlayerPresentationMotion.phase(Double(progress), from: 0.2, to: 0.8))
        source.alpha = 1 - blend
        destination.alpha = destinationHidden ? 0 : blend
    }
}
