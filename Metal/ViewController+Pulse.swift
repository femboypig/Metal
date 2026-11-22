import UIKit
import AVFoundation

extension ViewController {
    func setupPulseExperience(header: UIView) {
        pulseHero = UIStackView()
        pulseHero.translatesAutoresizingMaskIntoConstraints = false
        pulseHero.axis = .vertical
        pulseHero.alignment = .center
        pulseHero.spacing = 12
        pulseHero.alpha = 0
        pulseHero.isUserInteractionEnabled = false
        page1.insertSubview(pulseHero, belowSubview: libraryViewport)

        pulsePlayButton = UIButton(type: .custom)
        pulsePlayButton.backgroundColor = .black
        pulsePlayButton.tintColor = .white
        pulsePlayButton.layer.cornerRadius = 28
        pulsePlayButton.addTarget(self, action: #selector(pulsePlayTapped), for: .touchUpInside)
        pulseHero.addArrangedSubview(pulsePlayButton)
        pulsePlayButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        pulsePlayButton.heightAnchor.constraint(equalToConstant: 56).isActive = true

        pulseTitleLabel = UILabel()
        pulseTitleLabel.text = "Your vibe."
        pulseTitleLabel.font = UIFont(name: "Fraunces72pt-Bold", size: 32) ?? UIFont(name: "Georgia-Bold", size: 32)
        pulseTitleLabel.textColor = .white
        pulseTitleLabel.textAlignment = .center
        pulseTitleLabel.accessibilityTraits = .header
        pulseTitleLabel.layer.shadowColor = UIColor.black.cgColor
        pulseTitleLabel.layer.shadowOpacity = 0.55
        pulseTitleLabel.layer.shadowRadius = 8
        pulseTitleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        pulseHero.addArrangedSubview(pulseTitleLabel)

        pulseCustomizeButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Customize"
        config.image = UIImage(systemName: "slider.horizontal.3", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11))
        config.imagePadding = 6
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.58)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 15, bottom: 9, trailing: 15)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return result
        }
        pulseCustomizeButton.configuration = config
        pulseCustomizeButton.showsMenuAsPrimaryAction = true
        pulseCustomizeButton.accessibilityLabel = "Customize your vibe"
        pulseHero.addArrangedSubview(pulseCustomizeButton)
        pulseHero.setCustomSpacing(8, after: pulseTitleLabel)

        pulseReadabilityView = PulseCaptionShadeView(frame: .zero)
        pulseReadabilityView.translatesAutoresizingMaskIntoConstraints = false
        pulseReadabilityView.alpha = 0
        page1.insertSubview(pulseReadabilityView, belowSubview: pulseHero)
        pulseHeroCenterConstraint = pulseHero.centerYAnchor.constraint(equalTo: page1.topAnchor)
        NSLayoutConstraint.activate([
            pulseHero.centerXAnchor.constraint(equalTo: page1.centerXAnchor),
            pulseHeroCenterConstraint,
            pulseHero.leadingAnchor.constraint(greaterThanOrEqualTo: page1.leadingAnchor, constant: 20),
            pulseHero.trailingAnchor.constraint(lessThanOrEqualTo: page1.trailingAnchor, constant: -20),
            pulseReadabilityView.centerXAnchor.constraint(equalTo: pulseTitleLabel.centerXAnchor),
            pulseReadabilityView.centerYAnchor.constraint(equalTo: pulseTitleLabel.centerYAnchor, constant: 18),
            pulseReadabilityView.widthAnchor.constraint(equalToConstant: 300),
            pulseReadabilityView.heightAnchor.constraint(equalToConstant: 140)
        ])
        libraryPan = UIPanGestureRecognizer(target: self, action: #selector(dragLibrary(_:)))
        libraryPan.delegate = self
        page1.addGestureRecognizer(libraryPan)
        searchBar.searchTextField.accessibilityHint = "Drag vertically to expand or hide the library"
        searchBar.searchTextField.accessibilityCustomActions = [UIAccessibilityCustomAction(
            name: "Expand or hide library", target: self, selector: #selector(toggleLibraryAccessibility))]
        myWaveView.onAudioFrame = { [weak self] in self?.samplePulseAudio() }
        myWaveView.setVibe(pulseVibe)
        updatePulseCustomizeMenu()
        updatePulsePlayButton()
        libraryCollapse = UserDefaults.standard.bool(forKey: "Metal_LibraryCollapsed") ? 1 : 0
    }

    func updatePulseCustomizeMenu() {
        let choices = PulseVibe.allCases.map { vibe -> UIAction in
            let action = UIAction(title: vibe.title, state: vibe == pulseVibe ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.pulseVibe = vibe
                UserDefaults.standard.set(vibe.rawValue, forKey: "Metal_PulseVibe")
                self.myWaveView.setVibe(vibe)
                self.activatePulseVibe(autoplay: false)
                self.updatePulseCustomizeMenu()
                self.becomeFirstResponder()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            if #available(iOS 16.0, *) { action.subtitle = vibe.subtitle }
            else { action.title = "\(vibe.title) · \(vibe.subtitle)" }
            return action
        }
        pulseCustomizeButton.menu = UIMenu(title: "Your vibe", children: choices)
        pulseCustomizeButton.accessibilityValue = "\(pulseVibe.title), \(pulseVibe.subtitle)"
    }

    @objc func pulsePlayTapped() {
        if playbackSource == .pulseVibe { playOrPause() }
        else { activatePulseVibe(autoplay: true) }
        becomeFirstResponder()
    }

    func updatePulsePlayButton() {
        let playing = playbackSource == .pulseVibe && audioPlayer?.isPlaying == true
        pulsePlayButton?.setImage(playing ? PlaybackIcon.pause.image(size: 24) : PulseControlArtwork.play, for: .normal)
        pulsePlayButton?.accessibilityLabel = playing ? "Pause your vibe" : "Play your vibe"
        pulsePlayButton?.isEnabled = !tracks.isEmpty
    }

    var pulseDrawerGeometry: LibraryDrawerGeometry {
        LibraryDrawerGeometry(safeTop: Double(page1.safeAreaInsets.top),
            miniPlayerTop: Double(miniPlayerView.frame.minY))
    }

    func updateLibraryPresentationForLayout() {
        guard libraryViewport != nil, libraryTopConstraint != nil, miniPlayerView.frame.height > 0,
              !isLayingOutLibrary else { return }
        isLayingOutLibrary = true
        defer { isLayingOutLibrary = false }
        if pulseDrawerGeometry.travel < 1 { libraryCollapse = 0 }
        libraryTopConstraint.constant = pulseDrawerGeometry.top(progress: Double(libraryCollapse)) - Double(page1.safeAreaInsets.top)
        let expandedSearchTop = CGFloat(pulseDrawerGeometry.expandedTop + LibraryDrawerGeometry.searchOverscan)
        libraryTableHeightConstraint.constant = max(1, miniPlayerView.frame.minY - 10 - expandedSearchTop - 32)
        let compact = pulseDrawerGeometry.travel < 200
        if pulseTitleLabel.isHidden != compact {
            pulseTitleLabel.isHidden = compact
            page1.layoutIfNeeded()
        }
        let progress = min(1, max(0, libraryCollapse))
        let expandedWaveHeight = expandedSearchTop + 94
        let compactCenter = expandedWaveHeight * 0.5 - min(page1.bounds.width, expandedWaveHeight) * 0.07
        let playOffset = pulsePlayButton.frame.midY - pulseHero.bounds.midY
        let endStackCenter = (page1.safeAreaInsets.top + 92 + CGFloat(pulseDrawerGeometry.collapsedTop) + 10) * 0.5 - 8
        let endPulseCenter = endStackCenter + playOffset
        let center = compactCenter + (endPulseCenter - compactCenter) * progress
        pulseHeroCenterConstraint.constant = center - playOffset
        page1.layoutIfNeeded()

        let fade = min(1, max(0, (progress - 0.78) / 0.22))
        let contentAlpha = 1 - fade * fade * (3 - 2 * fade)
        tableView.alpha = contentAlpha
        floatingFiltersContainer.alpha = contentAlpha
        tableView.isUserInteractionEnabled = progress < 0.95
        floatingFiltersContainer.isUserInteractionEnabled = progress < 0.95
        tableView.accessibilityElementsHidden = progress > 0.8
        floatingFiltersContainer.accessibilityElementsHidden = progress > 0.8
        let reveal = min(1, max(0, (progress - 0.2) / 0.45))
        let heroAlpha = reveal * reveal * (3 - 2 * reveal)
        pulseHero.alpha = heroAlpha
        pulseReadabilityView.alpha = compact ? 0 : heroAlpha
        pulseHero.isUserInteractionEnabled = progress > 0.8
        pulseHero.accessibilityElementsHidden = progress < 0.8
        let waveHeight = max(1, myWaveView.bounds.height)
        myWaveView.setPresentation(Float(progress), centerY: Float(center / waveHeight),
            compactHeight: Float(expandedWaveHeight / waveHeight))
    }

    @objc func toggleLibraryAccessibility() -> Bool {
        setLibraryCollapsed(libraryCollapse < 0.5, animated: true)
        return true
    }

    func stopLibraryMotion() {
        libraryDisplayLink?.invalidate()
        libraryDisplayLink = nil
        libraryMotionTime = 0
    }

    func setLibraryCollapsed(_ collapsed: Bool, animated: Bool, initialVelocity: CGFloat = 0) {
        guard libraryViewport != nil else { return }
        if collapsed { searchBar.resignFirstResponder() }
        stopLibraryMotion()
        libraryMotionTarget = collapsed && pulseDrawerGeometry.travel > 1 ? 1 : 0
        UserDefaults.standard.set(libraryMotionTarget > 0.5, forKey: "Metal_LibraryCollapsed")
        guard animated, !UIAccessibility.isReduceMotionEnabled,
              abs(libraryMotionTarget - libraryCollapse) > 0.001 else {
            libraryCollapse = libraryMotionTarget
            updateLibraryPresentationForLayout()
            return
        }
        libraryMotionVelocity = min(3, max(-3, initialVelocity))
        let driver = LibraryMotionDriver(owner: self)
        let link = CADisplayLink(target: driver, selector: #selector(LibraryMotionDriver.tick(_:)))
        link.preferredFramesPerSecond = 60
        libraryDisplayLink = link
        link.add(to: .main, forMode: .common)
    }

    func tickLibraryMotion(_ link: CADisplayLink) {
        let dt = CGFloat(libraryMotionTime > 0 ? min(1.0 / 30, link.timestamp - libraryMotionTime) : 1.0 / 60)
        libraryMotionTime = link.timestamp
        // Critically damped; no overshoot, model/presentation-frame mismatch or
        // separate shader easing. Every visual follows this one progress value.
        let next = LibraryDrawerMotion.step(position: Double(libraryCollapse),
            velocity: Double(libraryMotionVelocity), target: Double(libraryMotionTarget), delta: Double(dt))
        libraryMotionVelocity = CGFloat(next.velocity)
        libraryCollapse = CGFloat(next.position)
        if next.finished { stopLibraryMotion() }
        updateLibraryPresentationForLayout()
    }

    @objc func dragLibrary(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            stopLibraryMotion()
            libraryPanStart = libraryCollapse
            searchBar.resignFirstResponder()
            becomeFirstResponder()
            tableView.isScrollEnabled = false
        case .changed:
            libraryCollapse = min(1, max(0, libraryPanStart + pan.translation(in: page1).y / CGFloat(max(1, pulseDrawerGeometry.travel))))
            updateLibraryPresentationForLayout()
        case .ended, .cancelled, .failed:
            tableView.isScrollEnabled = true
            let velocity = Double(pan.velocity(in: page1).y)
            let target = pan.state == .ended
                ? pulseDrawerGeometry.destination(progress: Double(libraryCollapse), velocity: velocity)
                : (libraryPanStart > 0.5 ? 1.0 : 0.0)
            setLibraryCollapsed(target > 0.5, animated: true,
                initialVelocity: pan.state == .ended ? CGFloat(velocity / max(1, pulseDrawerGeometry.travel)) : 0)
        default: break
        }
    }

    @objc func pulseDidBecomeActive() { updatePulseVisibility() }

    func updatePulseVisibility() {
        guard isViewLoaded, let wave = myWaveView, let scroll = scrollView, let page = page1 else { return }
        wave.setRenderingActive(UIApplication.shared.applicationState == .active && scroll.bounds.intersects(page.frame))
    }

    func samplePulseAudio() {
        guard !pulseSamplePending, UIApplication.shared.applicationState == .active else { return }
        var players: [AVAudioPlayer] = []
        if aidj.isTransitioning {
            players = [aidj.primaryPlayer, aidj.secondaryPlayer].compactMap { $0 }.filter { $0.isPlaying }
        } else if let player = audioPlayer, player.isPlaying { players = [player] }
        guard !players.isEmpty else {
            myWaveView.setPlaying(false)
            myWaveView.setAudioFrame(PulseAudioFrame())
            return
        }
        myWaveView.setPlaying(true)
        let sources = players.compactMap { player -> PulseAudioSource? in
            guard let url = player.url else { return nil }
            let bpm = Float(dailyMixVibeCache[url.lastPathComponent]?.profile.bpm ?? aidj.bpm(for: url))
            return PulseAudioSource(url: url, time: player.currentTime,
                weight: aidj.isTransitioning ? player.volume * player.volume : 1, bpm: bpm)
        }
        if players.count == 2, let aURL = players[0].url, let bURL = players[1].url,
           let a = tracks.first(where: { $0.url == aURL }), let b = tracks.first(where: { $0.url == bURL }) {
            let sum = sources.reduce(Float(0)) { $0 + $1.weight }
            let fraction = sum > 0 ? CGFloat(sources.last!.weight / sum) : 0
            myWaveView.setThemeColor(interpolateColor(from: pulseColor(for: a), to: pulseColor(for: b), progress: fraction))
        }
        if players.count == 1, let url = players[0].url, let track = tracks.first(where: { $0.url == url }) {
            myWaveView.setThemeColor(pulseColor(for: track))
        }
        pulseSamplePending = true
        pulseAudioSampler.sample(sources) { [weak self] frame in
            guard let self else { return }
            self.pulseSamplePending = false
            self.myWaveView?.setAudioFrame(self.audioPlayer?.isPlaying == true ? frame : PulseAudioFrame())
        }
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === libraryPan else { return true }
        guard pulseDrawerGeometry.travel > 1 else { return false }
        let velocity = libraryPan.velocity(in: page1)
        guard abs(velocity.y) > abs(velocity.x) * 1.15 else { return false }
        let point = libraryPan.location(in: page1)
        guard point.y < miniPlayerView.frame.minY - 10 else { return false }
        let searchFrame = searchBar.convert(searchBar.bounds, to: page1).insetBy(dx: 0, dy: -10)
        if searchFrame.contains(point) { return true }
        guard libraryViewport.frame.contains(point) else { return false }
        return libraryCollapse > 0.01 || (velocity.y > 0 && tableView.contentOffset.y <= -tableView.adjustedContentInset.top + 1)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer === libraryPan && otherGestureRecognizer === tableView.panGestureRecognizer)
            || (otherGestureRecognizer === libraryPan && gestureRecognizer === tableView.panGestureRecognizer)
    }
}

private final class LibraryMotionDriver: NSObject {
    weak var owner: ViewController?
    init(owner: ViewController) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        guard let owner else { link.invalidate(); return }
        owner.tickLibraryMotion(link)
    }
}

private final class PulseCaptionShadeView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        let gradient = layer as! CAGradientLayer
        gradient.type = .radial
        gradient.colors = [UIColor.black.withAlphaComponent(0.65).cgColor,
            UIColor.black.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor]
        gradient.locations = [0, 0.55, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private enum PulseControlArtwork {
    static let play: UIImage? = {
        guard let source = PlaybackIcon.play.image(size: 24) else { return nil }
        // The curved glyph's center of ink is left of its canvas center.
        // A 32 pt transparent canvas leaves room for a true optical correction.
        return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { _ in
            source.draw(in: CGRect(x: 16 - 97.56 * 24 / 256,
                y: 16 - 126.88 * 24 / 256, width: 24, height: 24))
        }.withRenderingMode(.alwaysTemplate)
    }()
}

extension ViewController {
    @discardableResult
    func activatePulseVibe(autoplay: Bool) -> Bool {
        let current = currentPlaybackTrack()
        let snapshot = playbackQueueSnapshot()
        let wasPulse = playbackSource == .pulseVibe
        let oldUpcoming = current == nil ? snapshot.trackIDs
            : Array(snapshot.trackIDs.dropFirst((snapshot.currentIndex ?? -1) + 1))
        let recent = wasPulse ? mixSessionRecentIDs : Array((listeningTelemetry.sessions ?? [])
            .filter { $0.source == .pulseVibe }.suffix(64).map(\.filename))
        let ids = PulseFlowEngine.nextTracks(from: dailyMixCandidates(), vibe: pulseVibe,
            previousTrackID: current?.url.lastPathComponent, recentTrackIDs: recent,
            reservedTrackIDs: Set(current.map { [$0.url.lastPathComponent] } ?? []),
            previousUpcoming: oldUpcoming, seed: UInt64.random(in: .min ... .max))
        let byID = Dictionary(tracks.map { ($0.url.lastPathComponent, $0) }, uniquingKeysWith: { a, _ in a })
        let upcoming = ids.compactMap { byID[$0] }
        guard !upcoming.isEmpty || current != nil else {
            if !tracks.isEmpty { showToast(message: "No rested tracks for this vibe yet", success: false) }
            return false
        }
        if aidj.isTransitioning { aidj.cancel(keeping: audioPlayer) }
        audioPlayer?.delegate = self
        isUpdatingMixQueue = true
        defer { isUpdatingMixQueue = false }
        pulsePreviousUpcoming = Array(oldUpcoming.prefix(24))
        playbackSource = .pulseVibe
        mixSessionRecentIDs = recent
        if let current {
            var history = wasPulse ? Array(snapshot.trackIDs.prefix((snapshot.currentIndex ?? -1) + 1)
                .suffix(21).compactMap { byID[$0] }) : []
            if history.last?.url != current.url { history.append(current) }
            playbackQueue = history + upcoming
            currentTrackIndex = history.count - 1
            if mixSessionRecentIDs.last != current.url.lastPathComponent {
                mixSessionRecentIDs.append(current.url.lastPathComponent)
            }
        } else {
            playbackQueue = upcoming
            currentTrackIndex = 0
        }
        currentPlaybackContext = "YOUR VIBE · \(pulseVibe.title.uppercased())"
        isShuffleEnabled = false
        isRepeatEnabled = false
        shuffledIndices = []
        shuffledPosition = 0
        lastMixExtensionAttempt = nil
        playbackPreparationGeneration += 1
        preparedPlayer = nil
        preparedPlayerURL = nil
        playerHeaderLabel?.text = currentPlaybackContext
        queueSheetTable?.reloadData()
        queueSheetCountLabel?.text = "\(playbackQueue.count) songs in queue"
        updateCarouselArtworks(animated: true)
        updatePlayerOptionsMenu()
        updateNowPlayingInfo()
        updateMiniPlayerUI()
        savePlaybackState()
        if current == nil, let first = upcoming.first {
            trackTitleLabel?.text = first.title
            artistLabel?.text = first.artist
            artistLabel?.isHidden = first.artist.isEmpty || first.artist == "Unknown Artist"
            updatePlayerTheme(with: first.artwork)
        }
        if autoplay {
            if audioPlayer == nil { playCurrentTrack() }
            else if audioPlayer?.isPlaying != true { playOrPause() }
        } else { prepareUpcomingTrack() }
        return true
    }

    func shakePulseVibeIfVisible() -> Bool {
        let width = scrollView?.bounds.width ?? 0
        let libraryVisible = width > 0 && abs(scrollView.contentOffset.x - width) < width * 0.4
        let showingVibe = (libraryVisible && (libraryCollapse > 0.5 || playbackSource == .pulseVibe))
            || (isPlayerPageVisible && playbackSource == .pulseVibe)
        guard showingVibe else { return false }
        guard UIApplication.shared.applicationState == .active,
              presentedViewController == nil, activeSheetView == nil,
              !searchBar.searchTextField.isFirstResponder, !isCarouselAnimating,
              tracks.count > 1 else { return true }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastMixShakeTime > 1.6 else { return true }
        lastMixShakeTime = now
        if activatePulseVibe(autoplay: false) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            myWaveView.shakeMix()
            UIAccessibility.post(notification: .announcement,
                argument: "Vibe refreshed. Current song keeps playing.")
        }
        return true
    }
}
