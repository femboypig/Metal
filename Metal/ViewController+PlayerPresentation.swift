import UIKit

extension ViewController {
    func setupPlayerPresentation() {
        playerDismissPan = UIPanGestureRecognizer(target: self, action: #selector(dragPlayerDown(_:)))
        playerDismissPan.delegate = self
        playerDismissPan.maximumNumberOfTouches = 1
        page2.addGestureRecognizer(playerDismissPan)
        playerViewportMask.backgroundColor = .black
        playerViewportMask.layer.cornerCurve = .continuous
        page2.mask = playerViewportMask
        page2.accessibilityViewIsModal = true
        page2.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Close player", target: self,
            selector: #selector(closePlayerAccessibility))]
        preparePlayerTransition()
        renderPlayerPresentation()
    }

    @objc func closePlayerAccessibility() -> Bool {
        setPlayerPresented(false)
        return true
    }

    func setPlayerPresented(_ presented: Bool, animated: Bool = true) {
        if playerPresentationAnimator != nil {
            pendingPlayerPresentation = presented
            return
        }
        view.endEditing(true)
        view.layoutIfNeeded()
        if playerPresentation == 0 || playerPresentation == 1 { preparePlayerTransition() }
        let target: CGFloat = presented ? 1 : 0
        playerPresentationTarget = target
        guard target != playerPresentation else { return }
        page1.accessibilityElementsHidden = presented
        page2.accessibilityElementsHidden = !presented
        page2.layer.removeAnimation(forKey: "miniPlayerArrival")
        page2.isHidden = false
        page1.isUserInteractionEnabled = false
        // Keep the real material rendering beneath the opaque player so it is ready on arrival.
        miniPlayerView.isHidden = false
        if !animated || UIAccessibility.isReduceMotionEnabled {
            playerPresentation = target
            renderPlayerPresentation()
            return
        }
        // UIKit commits all real view transforms and the clipping viewport together.
        // No per-frame layout, replica artwork, opacity ramps, or temporary background.
        let duration: TimeInterval = presented ? (playerPresentation > 0.9 ? 0.16 : 0.38) : 0.32
        let animator = UIViewPropertyAnimator(duration: duration,
            controlPoint1: CGPoint(x: 0.22, y: 0.78), controlPoint2: CGPoint(x: 0.24, y: 1))
        playerPresentationAnimator = animator
        animator.addAnimations { [weak self] in
            guard let self else { return }
            self.playerPresentation = target
            self.applyPlayerPresentationGeometry()
        }
        animator.addCompletion { [weak self] _ in
            guard let self else { return }
            self.playerPresentationAnimator = nil
            self.playerPresentation = target
            self.renderPlayerPresentation()
            UIAccessibility.post(notification: .screenChanged,
                argument: presented ? self.playerDismissButton : self.miniPlayerView)
            let pending = self.pendingPlayerPresentation
            self.pendingPlayerPresentation = nil
            if let pending, pending != presented { self.setPlayerPresented(pending) }
        }
        if !presented {
            // A discrete compositor handoff, not a fade. The final 10% of the easing covers
            // only the last pixels of travel, but a delayed main-thread completion can linger here.
            // Expose the already-rendered mini-player on the render server before that tail.
            let arrival = CAKeyframeAnimation(keyPath: "opacity")
            arrival.values = [1, 0, 0]
            arrival.keyTimes = [0, 0.9, 1]
            arrival.calculationMode = .discrete
            arrival.timingFunction = CAMediaTimingFunction(name: .linear)
            arrival.duration = duration
            arrival.fillMode = .forwards
            arrival.isRemovedOnCompletion = false
            page2.layer.add(arrival, forKey: "miniPlayerArrival")
        }
        animator.startAnimation()
        updatePulseVisibility()
    }

    func preparePlayerTransition() {
        guard !isPreparingPlayerTransition else { return }
        isPreparingPlayerTransition = true
        defer { isPreparingPlayerTransition = false }
        // Capture the actual fullscreen geometry once, before the GPU starts the transition.
        for item in playerMotionElements { item.view.transform = .identity }
        view.layoutIfNeeded()
        let mini = miniPlayerView.convert(miniPlayerView.bounds, to: view)
        let cover = coverArtCard.convert(coverArtCard.bounds, to: view)
        let miniCover = miniCoverView.convert(miniCoverView.bounds, to: view)
        var elements: [(view: UIView, collapsed: CGAffineTransform)] = [
            (playerArtworkMotionView, PlayerPresentationMotion.collapsedTransform(from: cover, to: miniCover))
        ]
        for (label, source) in [(trackTitleLabel!, miniTitleLabel!), (artistLabel!, miniArtistLabel!)] {
            let full = label.convert(label.bounds, to: view)
            let small = source.convert(source.bounds, to: view)
            elements.append((label, PlayerPresentationMotion.collapsedTransform(from: full, to: small)))
        }
        let header = playerTransitionHeader.convert(playerTransitionHeader.bounds, to: view)
        elements.append((playerTransitionHeader, CGAffineTransform(translationX: 0, y: mini.minY - header.maxY - 8)))
        for element in [playerMainControls!, progressSlider!, elapsedLabel!, remainingLabel!,
                        playerFavoriteButton!, playerTransitionFooter!] as [UIView] {
            let frame = element.convert(element.bounds, to: view)
            elements.append((element, CGAffineTransform(translationX: 0,
                y: max(0, mini.maxY + 32 - frame.minY))))
        }
        playerMotionElements = elements
        applyPlayerPresentationGeometry()
    }

    func applyPlayerPresentationGeometry() {
        if page2.mask !== playerViewportMask { page2.mask = playerViewportMask }
        let progress = min(1, max(0, playerPresentation))
        let mini = miniPlayerView.convert(miniPlayerView.bounds, to: view)
        playerViewportMask.frame = PlayerPresentationMotion.frame(source: mini,
            destination: view.bounds, progress: Double(progress))
        playerViewportMask.layer.cornerRadius = miniPlayerView.layer.cornerRadius * (1 - progress)
        for item in playerMotionElements {
            item.view.transform = PlayerPresentationMotion.transform(item.collapsed, progress: Double(progress))
        }
    }

    func renderPlayerPresentation() {
        guard page2 != nil, playerArtworkMotionView != nil, playerPresentationAnimator == nil,
              !isPreparingPlayerTransition else { return }
        applyPlayerPresentationGeometry()
        let closed = playerPresentation == 0
        page2.isHidden = closed
        // The real mini-player remains live underneath the clipped, opaque player throughout.
        miniPlayerView.isHidden = false
        page2.layer.removeAnimation(forKey: "miniPlayerArrival")
        page1.isUserInteractionEnabled = closed
        if playerPresentation == 1 { page2.mask = nil }
        updatePulseVisibility()
    }

    @objc func dragPlayerDown(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            playerDismissCommitted = false
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
                applyPlayerPresentationGeometry()
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
