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
        pulsePlayButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        pulseHero.addArrangedSubview(pulsePlayButton)
        pulsePlayButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        pulsePlayButton.heightAnchor.constraint(equalToConstant: 56).isActive = true

        pulseTitleLabel = UILabel()
        pulseTitleLabel.text = "Your vibe."
        pulseTitleLabel.font = .systemFont(ofSize: 27, weight: .bold)
        pulseTitleLabel.textColor = primaryTextColor()
        pulseTitleLabel.textAlignment = .center
        pulseHero.addArrangedSubview(pulseTitleLabel)

        pulseCustomizeButton = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "Customize"
        config.image = UIImage(systemName: "slider.horizontal.3", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11))
        config.imagePadding = 6
        config.baseForegroundColor = primaryTextColor()
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            return result
        }
        pulseCustomizeButton.configuration = config
        pulseCustomizeButton.showsMenuAsPrimaryAction = true
        pulseCustomizeButton.accessibilityLabel = "Customize pulse"
        pulseHero.addArrangedSubview(pulseCustomizeButton)
        pulseHero.setCustomSpacing(2, after: pulseTitleLabel)

        let heroArea = UILayoutGuide()
        page1.addLayoutGuide(heroArea)
        NSLayoutConstraint.activate([
            heroArea.topAnchor.constraint(equalTo: header.bottomAnchor),
            heroArea.bottomAnchor.constraint(equalTo: libraryViewport.topAnchor),
            heroArea.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            heroArea.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            pulseHero.centerXAnchor.constraint(equalTo: heroArea.centerXAnchor),
            pulseHero.centerYAnchor.constraint(equalTo: heroArea.centerYAnchor, constant: -8),
            pulseHero.leadingAnchor.constraint(greaterThanOrEqualTo: page1.leadingAnchor, constant: 24),
            pulseHero.trailingAnchor.constraint(lessThanOrEqualTo: page1.trailingAnchor, constant: -24)
        ])

        libraryHandle = UIButton(type: .custom)
        libraryHandle.translatesAutoresizingMaskIntoConstraints = false
        libraryHandle.addTarget(self, action: #selector(toggleLibraryPresentation), for: .touchUpInside)
        libraryHandle.accessibilityHint = "Double tap, or drag up and down to expand or hide the library"
        page1.addSubview(libraryHandle)
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.isUserInteractionEnabled = false
        line.backgroundColor = secondaryTextColor().withAlphaComponent(0.55)
        line.layer.cornerRadius = 2
        libraryHandle.addSubview(line)
        NSLayoutConstraint.activate([
            libraryHandle.centerXAnchor.constraint(equalTo: page1.centerXAnchor),
            libraryHandle.bottomAnchor.constraint(equalTo: libraryViewport.topAnchor, constant: 3),
            libraryHandle.widthAnchor.constraint(equalToConstant: 100),
            libraryHandle.heightAnchor.constraint(equalToConstant: 28),
            line.centerXAnchor.constraint(equalTo: libraryHandle.centerXAnchor),
            line.centerYAnchor.constraint(equalTo: libraryHandle.centerYAnchor),
            line.widthAnchor.constraint(equalToConstant: 34),
            line.heightAnchor.constraint(equalToConstant: 4)
        ])
        libraryPan = UIPanGestureRecognizer(target: self, action: #selector(dragLibrary(_:)))
        libraryPan.delegate = self
        page1.addGestureRecognizer(libraryPan)
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
                self.updatePulseCustomizeMenu()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            if #available(iOS 16.0, *) { action.subtitle = vibe.subtitle }
            else { action.title = "\(vibe.title) · \(vibe.subtitle)" }
            return action
        }
        pulseCustomizeButton.menu = UIMenu(title: "Pulse character", children: choices)
        pulseCustomizeButton.accessibilityValue = "\(pulseVibe.title), \(pulseVibe.subtitle)"
    }

    func updatePulsePlayButton() {
        let playing = audioPlayer?.isPlaying == true
        pulsePlayButton?.setImage((playing ? PlaybackIcon.pause : .play).image(size: 24), for: .normal)
        pulsePlayButton?.accessibilityLabel = playing ? "Pause" : "Play"
        pulsePlayButton?.isEnabled = !tracks.isEmpty
    }

    private var drawerGeometry: LibraryDrawerGeometry {
        LibraryDrawerGeometry(safeTop: Double(page1.safeAreaInsets.top),
            miniPlayerTop: Double(miniPlayerView.frame.minY))
    }

    func updateLibraryPresentationForLayout() {
        guard libraryViewport != nil, libraryTopConstraint != nil, miniPlayerView.frame.height > 0 else { return }
        // A property animator owns intermediate layout during its spring.
        if libraryAnimator == nil {
            if drawerGeometry.travel < 1 { libraryCollapse = 0 }
            let relativeTop = drawerGeometry.top(progress: Double(libraryCollapse)) - Double(page1.safeAreaInsets.top)
            if abs(libraryTopConstraint.constant - relativeTop) > 0.1 {
                libraryTopConstraint.constant = relativeTop
            }
        }
        applyLibraryPresentation()
    }

    private func applyLibraryPresentation() {
        let progress = min(1, max(0, libraryCollapse))
        let compact = drawerGeometry.travel < 200
        let axis: NSLayoutConstraint.Axis = compact ? .horizontal : .vertical
        if pulseHero.axis != axis { pulseHero.axis = axis }
        if pulseTitleLabel.isHidden != compact { pulseTitleLabel.isHidden = compact }
        let contentAlpha = pow(1 - progress, 2)
        tableView.alpha = contentAlpha
        floatingFiltersContainer.alpha = contentAlpha
        tableView.isUserInteractionEnabled = progress < 0.95
        floatingFiltersContainer.isUserInteractionEnabled = progress < 0.95
        tableView.accessibilityElementsHidden = progress > 0.5
        floatingFiltersContainer.accessibilityElementsHidden = progress > 0.5
        pulseHero.alpha = min(1, max(0, (progress - 0.25) / 0.6))
        pulseHero.isUserInteractionEnabled = progress > 0.8
        pulseHero.accessibilityElementsHidden = progress < 0.8
        pulseTitleLabel.textColor = primaryTextColor()
        libraryHandle.accessibilityLabel = progress > 0.5 ? "Expand library" : "Hide library"
        let heroCenter = pulsePlayButton.convert(CGPoint(x: pulsePlayButton.bounds.midX,
            y: pulsePlayButton.bounds.midY), to: myWaveView)
        let normalizedY = myWaveView.bounds.height > 0 ? heroCenter.y / myWaveView.bounds.height : 0.43
        myWaveView.setPresentation(Float(progress), centerY: Float(normalizedY))
    }

    @objc func toggleLibraryPresentation() {
        setLibraryCollapsed(libraryCollapse < 0.5, animated: true)
    }

    private func stopLibrarySpringAtVisiblePosition() {
        guard let animator = libraryAnimator else { return }
        let top = libraryViewport.layer.presentation()?.frame.minY ?? libraryViewport.frame.minY
        animator.stopAnimation(true)
        libraryAnimator = nil
        libraryCollapse = CGFloat(min(1, max(0, (Double(top) - drawerGeometry.expandedTop) / max(1, drawerGeometry.travel))))
        libraryTopConstraint.constant = drawerGeometry.top(progress: Double(libraryCollapse)) - Double(page1.safeAreaInsets.top)
        UIView.performWithoutAnimation {
            self.page1.layoutIfNeeded()
            self.applyLibraryPresentation()
        }
    }

    func setLibraryCollapsed(_ collapsed: Bool, animated: Bool) {
        guard libraryViewport != nil else { return }
        if collapsed { searchBar.resignFirstResponder() }
        stopLibrarySpringAtVisiblePosition()
        libraryCollapse = collapsed && drawerGeometry.travel > 1 ? 1 : 0
        UserDefaults.standard.set(libraryCollapse > 0.5, forKey: "Metal_LibraryCollapsed")
        libraryTopConstraint.constant = drawerGeometry.top(progress: Double(libraryCollapse)) - Double(page1.safeAreaInsets.top)
        let changes = {
            self.page1.layoutIfNeeded()
            self.applyLibraryPresentation()
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else { changes(); return }
        let animator = UIViewPropertyAnimator(duration: 0.42, dampingRatio: 0.88, animations: changes)
        libraryAnimator = animator
        animator.addCompletion { [weak self] _ in
            self?.libraryAnimator = nil
            self?.updateLibraryPresentationForLayout()
        }
        animator.startAnimation()
    }

    @objc func dragLibrary(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            // Continue from the rendered position if a spring is interrupted.
            stopLibrarySpringAtVisiblePosition()
            libraryPanStart = libraryCollapse
            searchBar.resignFirstResponder()
            tableView.isScrollEnabled = false
        case .changed:
            let travel = max(1, drawerGeometry.travel)
            libraryCollapse = min(1, max(0, libraryPanStart + pan.translation(in: page1).y / CGFloat(travel)))
            libraryTopConstraint.constant = drawerGeometry.top(progress: Double(libraryCollapse)) - Double(page1.safeAreaInsets.top)
            page1.layoutIfNeeded()
            applyLibraryPresentation()
        case .ended, .cancelled, .failed:
            tableView.isScrollEnabled = true
            let target = pan.state == .ended
                ? drawerGeometry.destination(progress: Double(libraryCollapse), velocity: Double(pan.velocity(in: page1).y))
                : (libraryPanStart > 0.5 ? 1.0 : 0.0)
            setLibraryCollapsed(target > 0.5, animated: true)
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
            let bpm = Float(dailyMixVibeCache[url.lastPathComponent]?.profile.bpm ?? 120)
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
        guard drawerGeometry.travel > 1 else { return false }
        let velocity = libraryPan.velocity(in: page1)
        guard abs(velocity.y) > abs(velocity.x) * 1.15 else { return false }
        let point = libraryPan.location(in: page1)
        let viewportPoint = libraryPan.location(in: libraryViewport)
        let handlePoint = libraryPan.location(in: libraryHandle)
        if libraryHandle.bounds.contains(handlePoint) { return true }
        guard libraryViewport.frame.contains(point), viewportPoint.y > searchBar.frame.maxY else { return false }
        return libraryCollapse > 0.01 || (velocity.y > 0 && tableView.contentOffset.y <= -tableView.adjustedContentInset.top + 1)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer === libraryPan && otherGestureRecognizer === tableView.panGestureRecognizer)
            || (otherGestureRecognizer === libraryPan && gestureRecognizer === tableView.panGestureRecognizer)
    }
}

#if DEBUG
extension ViewController {
    /// Runs only in the disposable simulator used by the CI preview task.
    func verifyPulseLayoutIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--verify-pulse-layout") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            let requested = self.libraryCollapse > 0.5
            self.view.layoutIfNeeded()
            let miniFrame = self.miniPlayerView.frame
            self.setLibraryCollapsed(false, animated: false)
            self.view.layoutIfNeeded()
            precondition(abs(self.libraryViewport.frame.minY - self.page1.safeAreaInsets.top - 92) < 1)
            precondition(self.miniPlayerView.frame == miniFrame)
            self.setLibraryCollapsed(true, animated: false)
            self.view.layoutIfNeeded()
            precondition(abs(self.libraryViewport.frame.height - 56) < 1)
            precondition(self.tableView.alpha == 0 && self.floatingFiltersContainer.alpha == 0)
            precondition(self.miniPlayerView.frame == miniFrame)
            precondition(self.libraryViewport.clipsToBounds)
            self.setLibraryCollapsed(requested, animated: false)
            self.view.layoutIfNeeded()
            // Check a real intermediate spring frame as well as both endpoints.
            self.setLibraryCollapsed(!requested, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                let visibleMini = self.miniPlayerView.layer.presentation()?.frame ?? self.miniPlayerView.frame
                precondition(abs(visibleMini.minY - miniFrame.minY) < 0.1)
                precondition(visibleMini.size == miniFrame.size)
                self.setLibraryCollapsed(requested, animated: false)
                self.view.layoutIfNeeded()
                precondition(self.miniPlayerView.frame == miniFrame)
                let report: [String: Any] = ["passed": true,
                    "collapsed": requested, "vibe": self.pulseVibe.rawValue, "animatedMiniStable": true,
                    "miniFrame": String(describing: miniFrame),
                    "searchFrame": String(describing: self.searchBar.convert(self.searchBar.bounds, to: self.page1))]
                if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                   let data = try? JSONSerialization.data(withJSONObject: report) {
                    try? data.write(to: url.appendingPathComponent("pulse-layout-checks.json"), options: .atomic)
                }
            }
        }
    }
}
#endif
