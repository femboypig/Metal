//
//  ViewController+UI.swift
//  Metal
//

import UIKit
import Darwin
import Metal
import MetalKit

extension ViewController {

    // MARK: - Adaptive Metal Palette

    func primaryBackgroundColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.055, green: 0.055, blue: 0.063, alpha: 1.0)
                : UIColor(red: 0.965, green: 0.965, blue: 0.975, alpha: 1.0)
        }
    }

    func cardBackgroundColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.095, green: 0.095, blue: 0.108, alpha: 1.0)
                : .white
        }
    }

    func cardBorderColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.09)
                : UIColor.black.withAlphaComponent(0.10)
        }
    }

    func primaryTextColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.957, green: 0.945, blue: 0.914, alpha: 1.0)
                : UIColor(red: 0.08, green: 0.08, blue: 0.095, alpha: 1.0)
        }
    }

    func secondaryTextColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.57, green: 0.57, blue: 0.59, alpha: 1.0)
                : UIColor(red: 0.38, green: 0.38, blue: 0.42, alpha: 1.0)
        }
    }

    func progressTrackColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.12)
        }
    }

    func primaryButtonColor() -> UIColor {
        UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
    }

    func primaryButtonTextColor() -> UIColor {
        .white
    }

    func activeRowColor() -> UIColor {
        UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 0.10)
    }

    func miniPlayerBackgroundColor() -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
                : UIColor.white.withAlphaComponent(0.98)
        }
    }

    // MARK: - UI Layout Setup

    func setupUI() {
        view.backgroundColor = primaryBackgroundColor()

        // Paging ScrollView - Edge-to-Edge full screen
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.delegate = self
        view.addSubview(scrollView)

        // Page Containers
        page0 = UIView()
        page0.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(page0)

        page1 = UIView()
        page1.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(page1)

        page2 = UIView()
        page2.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(page2)

        // Gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            page0.topAnchor.constraint(equalTo: scrollView.topAnchor),
            page0.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            page0.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            page0.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            page0.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            page1.topAnchor.constraint(equalTo: scrollView.topAnchor),
            page1.leadingAnchor.constraint(equalTo: page0.trailingAnchor),
            page1.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            page1.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            page1.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            page2.topAnchor.constraint(equalTo: scrollView.topAnchor),
            page2.leadingAnchor.constraint(equalTo: page1.trailingAnchor),
            page2.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            page2.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            page2.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            page2.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        setupPage0Settings()
        setupPage1Library()
        setupPage2NowPlaying()
    }

    func setupPage0Settings() {
        page0.backgroundColor = primaryBackgroundColor()

        let backButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        backButton.tintColor = primaryTextColor()
        backButton.backgroundColor = cardBackgroundColor()
        backButton.layer.cornerRadius = 20
        backButton.addTarget(self, action: #selector(showLibraryTapped), for: .touchUpInside)
        page0.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 34)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = "Settings"
        page0.addSubview(titleLabel)

        let sectionLabel = UILabel()
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        sectionLabel.textColor = secondaryTextColor()
        sectionLabel.text = "PLAYBACK"
        sectionLabel.letterSpacing(1.2)
        page0.addSubview(sectionLabel)

        // Settings Card
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = cardBackgroundColor()
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1.0
        card.layer.borderColor = cardBorderColor().cgColor
        page0.addSubview(card)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = primaryTextColor()
        label.text = "DJ Transitions"
        card.addSubview(label)

        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = secondaryTextColor()
        descLabel.numberOfLines = 0
        descLabel.text = "Analyzes tempo locally, aligns the next song to the beat, and blends it with an adaptive crossfade."
        card.addSubview(descLabel)

        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false

        if UserDefaults.standard.object(forKey: "Metal_AIDJEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "Metal_AIDJEnabled")
        }
        toggle.isOn = UserDefaults.standard.bool(forKey: "Metal_AIDJEnabled")
        toggle.onTintColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
        toggle.addTarget(self, action: #selector(aidjToggleChanged(_:)), for: .valueChanged)
        card.addSubview(toggle)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: page0.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.trailingAnchor.constraint(equalTo: page0.trailingAnchor, constant: -20),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: page0.safeAreaLayoutGuide.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),

            sectionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 34),
            sectionLabel.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),

            card.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: page0.trailingAnchor, constant: -24),
            card.heightAnchor.constraint(equalToConstant: 112),

            toggle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            toggle.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -16),

            descLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -16)
        ])

        // Appearance Section
        let appearanceLabel = UILabel()
        appearanceLabel.translatesAutoresizingMaskIntoConstraints = false
        appearanceLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        appearanceLabel.textColor = secondaryTextColor()
        appearanceLabel.text = "APPEARANCE"
        appearanceLabel.letterSpacing(1.2)
        page0.addSubview(appearanceLabel)

        // Player Background Setting Card
        let bgCard = UIView()
        bgCard.translatesAutoresizingMaskIntoConstraints = false
        bgCard.backgroundColor = cardBackgroundColor()
        bgCard.layer.cornerRadius = 18
        bgCard.layer.borderWidth = 1.0
        bgCard.layer.borderColor = cardBorderColor().cgColor
        page0.addSubview(bgCard)

        let bgLabel = UILabel()
        bgLabel.translatesAutoresizingMaskIntoConstraints = false
        bgLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        bgLabel.textColor = primaryTextColor()
        bgLabel.text = "Player Background"
        bgCard.addSubview(bgLabel)

        let bgDescLabel = UILabel()
        bgDescLabel.translatesAutoresizingMaskIntoConstraints = false
        bgDescLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        bgDescLabel.textColor = secondaryTextColor()
        bgDescLabel.numberOfLines = 0
        bgDescLabel.text = "Animated liquid plasma synthesized purely from artwork colors, or classic album gradient."
        bgCard.addSubview(bgDescLabel)

        let bgSegmented = UISegmentedControl(items: ["Fluid Plasma", "Gradient"])
        bgSegmented.translatesAutoresizingMaskIntoConstraints = false
        bgSegmented.selectedSegmentIndex = (persistedSettings.playerBackgroundStyle == "gradient") ? 1 : 0
        bgSegmented.addTarget(self, action: #selector(playerBackgroundStyleChanged(_:)), for: .valueChanged)
        bgCard.addSubview(bgSegmented)

        NSLayoutConstraint.activate([
            appearanceLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 28),
            appearanceLabel.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),

            bgCard.topAnchor.constraint(equalTo: appearanceLabel.bottomAnchor, constant: 12),
            bgCard.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),
            bgCard.trailingAnchor.constraint(equalTo: page0.trailingAnchor, constant: -24),

            bgLabel.topAnchor.constraint(equalTo: bgCard.topAnchor, constant: 18),
            bgLabel.leadingAnchor.constraint(equalTo: bgCard.leadingAnchor, constant: 20),
            bgLabel.trailingAnchor.constraint(equalTo: bgCard.trailingAnchor, constant: -20),

            bgDescLabel.topAnchor.constraint(equalTo: bgLabel.bottomAnchor, constant: 4),
            bgDescLabel.leadingAnchor.constraint(equalTo: bgCard.leadingAnchor, constant: 20),
            bgDescLabel.trailingAnchor.constraint(equalTo: bgCard.trailingAnchor, constant: -20),

            bgSegmented.topAnchor.constraint(equalTo: bgDescLabel.bottomAnchor, constant: 14),
            bgSegmented.leadingAnchor.constraint(equalTo: bgCard.leadingAnchor, constant: 20),
            bgSegmented.trailingAnchor.constraint(equalTo: bgCard.trailingAnchor, constant: -20),
            bgSegmented.heightAnchor.constraint(equalToConstant: 32),
            bgSegmented.bottomAnchor.constraint(equalTo: bgCard.bottomAnchor, constant: -16)
        ])

        // Bottom Plain Text: Experimental Build Information
        let expInfoLabel = UILabel()
        expInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        expInfoLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        expInfoLabel.textColor = secondaryTextColor()
        expInfoLabel.textAlignment = .center
        expInfoLabel.numberOfLines = 0
        let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "27.0"
        expInfoLabel.text = "iOS \(UIDevice.current.systemVersion) • \(UIDevice.current.modelName)\nMetal v\(buildVersion) (\(buildNumber)) • Experimental Branch • iOS 26/27 SDK"
        page0.addSubview(expInfoLabel)

        NSLayoutConstraint.activate([
            expInfoLabel.bottomAnchor.constraint(equalTo: page0.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            expInfoLabel.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),
            expInfoLabel.trailingAnchor.constraint(equalTo: page0.trailingAnchor, constant: -24)
        ])
    }

    @objc func showLibraryTapped() {
        view.endEditing(true)
        scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width, y: 0), animated: true)
    }

    @objc func aidjToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "Metal_AIDJEnabled")
        saveSettings()

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    @objc func playerBackgroundStyleChanged(_ sender: UISegmentedControl) {
        persistedSettings.playerBackgroundStyle = (sender.selectedSegmentIndex == 1) ? "gradient" : "fluid"
        saveSettings()
        applyPlayerBackgroundStyle()

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    func setupPage1Library() {
        page1.backgroundColor = primaryBackgroundColor()

        // 1. Pure Visual Ambient Wave ("мумия / волна как у яндекс музыки")
        // Positioned in the open space below header titles down to the midpoint of the search bar
        myWaveView = YandexWaveView()
        myWaveView.translatesAutoresizingMaskIntoConstraints = false
        myWaveView.backgroundColor = .clear
        myWaveView.isUserInteractionEnabled = false
        myWaveView.clipsToBounds = true
        page1.addSubview(myWaveView)

        // 2. Bottom Underlay Panel ("снизу подложка, обрывается сзади половины searchsongs и по бокам закругляется")
        bottomPanel = UIView()
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.backgroundColor = cardBackgroundColor()
        bottomPanel.layer.cornerRadius = 28
        bottomPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomPanel.layer.borderWidth = 1.0
        bottomPanel.layer.borderColor = cardBorderColor().cgColor
        bottomPanel.clipsToBounds = true
        page1.addSubview(bottomPanel)

        // 3. TableView (Songs List) - positioned over bottomPanel
        tableView = CylinderTableView()
        tableView.onLayoutSubviews = { [weak self] in
            self?.applyCylinderEffect()
        }
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TrackCell.self, forCellReuseIdentifier: TrackCell.identifier)
        tableView.contentInset = UIEdgeInsets(top: 56, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 56, left: 0, bottom: 0, right: 0)
        page1.addSubview(tableView)

        applyTableGradientMask()

        let cellLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCellLongPress(_:)))
        tableView.addGestureRecognizer(cellLongPress)

        // 4. Unified Floating Pill Bar for Filters (All, Daily Mix, Favorites, etc.) - Floats ABOVE the songs list
        floatingFiltersContainer = UIView()
        floatingFiltersContainer.translatesAutoresizingMaskIntoConstraints = false
        floatingFiltersContainer.layer.cornerRadius = 20
        floatingFiltersContainer.layer.borderWidth = 0.5
        floatingFiltersContainer.layer.borderColor = cardBorderColor().cgColor
        floatingFiltersContainer.layer.shadowColor = UIColor.black.cgColor
        floatingFiltersContainer.layer.shadowOpacity = 0.16
        floatingFiltersContainer.layer.shadowRadius = 8
        floatingFiltersContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        page1.addSubview(floatingFiltersContainer)

        let pillGlass: UIView
        if #available(iOS 26.0, *) {
            pillGlass = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            pillGlass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        }
        pillGlass.translatesAutoresizingMaskIntoConstraints = false
        pillGlass.layer.cornerRadius = 20
        pillGlass.clipsToBounds = true
        pillGlass.isUserInteractionEnabled = false
        floatingFiltersContainer.addSubview(pillGlass)

        filtersScrollView = UIScrollView()
        filtersScrollView.translatesAutoresizingMaskIntoConstraints = false
        filtersScrollView.showsHorizontalScrollIndicator = false
        filtersScrollView.bounces = true
        filtersScrollView.layer.cornerRadius = 20
        filtersScrollView.clipsToBounds = true
        floatingFiltersContainer.addSubview(filtersScrollView)

        filtersStackView = UIStackView()
        filtersStackView.translatesAutoresizingMaskIntoConstraints = false
        filtersStackView.axis = .horizontal
        filtersStackView.spacing = 6
        filtersStackView.alignment = .center
        filtersScrollView.addSubview(filtersStackView)

        // 5. Search Bar - Acts as physical connector/bridge between header wave and bottomPanel
        searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .clear
        searchBar.layer.borderWidth = 0
        searchBar.placeholder = "Search songs..."
        searchBar.delegate = self
        searchBar.searchTextField.backgroundColor = cardBackgroundColor()
        searchBar.searchTextField.textColor = primaryTextColor()
        searchBar.searchTextField.leftView?.tintColor = secondaryTextColor()
        searchBar.searchTextField.layer.cornerRadius = 15
        searchBar.searchTextField.clipsToBounds = true
        searchBar.searchTextField.layer.borderWidth = 0.5
        searchBar.searchTextField.layer.borderColor = cardBorderColor().cgColor
        searchBar.layer.shadowColor = UIColor.black.cgColor
        searchBar.layer.shadowOpacity = 0.10
        searchBar.layer.shadowRadius = 6
        searchBar.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchBar.clipsToBounds = false
        page1.addSubview(searchBar)

        // 6. Header Titles and Action Button (Mathematically centered between safe zone and search bar)
        let headerArea = UIView()
        headerArea.translatesAutoresizingMaskIntoConstraints = false
        headerArea.isUserInteractionEnabled = false
        page1.addSubview(headerArea)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 38)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = "Metal."
        page1.addSubview(titleLabel)

        importButton = UIButton(type: .system)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        let importImage = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = importImage
            configuration.baseForegroundColor = primaryTextColor()
            importButton.configuration = configuration
        } else {
            importButton.setImage(importImage, for: .normal)
            importButton.tintColor = primaryTextColor()
            importButton.backgroundColor = .clear
        }
        importButton.accessibilityLabel = "Import Music"
        importButton.addTarget(self, action: #selector(importMusicButtonTapped), for: .touchUpInside)
        page1.addSubview(importButton)

        // Miniplayer (Page 1 Interface - Floating Pill Card)
        miniPlayerView = UIView()
        miniPlayerView.translatesAutoresizingMaskIntoConstraints = false
        miniPlayerView.layer.cornerRadius = 29
        miniPlayerView.isUserInteractionEnabled = true

        if #available(iOS 26.0, *) {
            miniPlayerView.backgroundColor = .clear
            miniPlayerView.layer.borderWidth = 0

            let glassView = UIVisualEffectView(effect: UIGlassEffect())
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.isUserInteractionEnabled = false
            glassView.clipsToBounds = true
            glassView.layer.cornerRadius = 29
            miniPlayerView.addSubview(glassView)

            NSLayoutConstraint.activate([
                glassView.topAnchor.constraint(equalTo: miniPlayerView.topAnchor),
                glassView.leadingAnchor.constraint(equalTo: miniPlayerView.leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: miniPlayerView.trailingAnchor),
                glassView.bottomAnchor.constraint(equalTo: miniPlayerView.bottomAnchor)
            ])
        } else {
            miniPlayerView.backgroundColor = miniPlayerBackgroundColor()
            miniPlayerView.layer.borderWidth = 1
            miniPlayerView.layer.borderColor = cardBorderColor().resolvedColor(with: traitCollection).cgColor
            miniPlayerView.layer.shadowColor = UIColor.black.cgColor
            miniPlayerView.layer.shadowOffset = CGSize(width: 0, height: 8)
            miniPlayerView.layer.shadowOpacity = 0.20
            miniPlayerView.layer.shadowRadius = 18
        }
        page1.addSubview(miniPlayerView)

        let miniTap = UITapGestureRecognizer(target: self, action: #selector(miniPlayerTapped(_:)))
        miniPlayerView.addGestureRecognizer(miniTap)

        miniCoverCard = UIView()
        miniCoverCard.translatesAutoresizingMaskIntoConstraints = false
        miniCoverCard.layer.cornerRadius = 12
        miniCoverCard.clipsToBounds = true
        miniCoverCard.layer.borderWidth = 0
        miniPlayerView.addSubview(miniCoverCard)

        miniCoverView = UIImageView()
        miniCoverView.translatesAutoresizingMaskIntoConstraints = false
        miniCoverView.contentMode = .scaleAspectFill
        miniCoverView.clipsToBounds = true
        miniCoverCard.addSubview(miniCoverView)

        let miniTextStack = UIStackView()
        miniTextStack.translatesAutoresizingMaskIntoConstraints = false
        miniTextStack.axis = .vertical
        miniTextStack.spacing = 1
        miniPlayerView.addSubview(miniTextStack)

        miniTitleLabel = UILabel()
        miniTitleLabel.font = UIFont(name: "Georgia-Bold", size: 14)
        miniTitleLabel.textColor = primaryTextColor()
        miniTitleLabel.text = "No Track Selected"
        miniTextStack.addArrangedSubview(miniTitleLabel)

        miniArtistLabel = UILabel()
        miniArtistLabel.font = UIFont(name: "Georgia-Italic", size: 11)
        miniArtistLabel.textColor = secondaryTextColor()
        miniArtistLabel.text = "Select a song below"
        miniTextStack.addArrangedSubview(miniArtistLabel)

        let miniControls = UIStackView()
        miniControls.translatesAutoresizingMaskIntoConstraints = false
        miniControls.axis = .horizontal
        miniControls.spacing = 14
        miniControls.alignment = .center
        miniPlayerView.addSubview(miniControls)

        miniPreviousButton = UIButton(type: .system)
        miniPreviousButton.translatesAutoresizingMaskIntoConstraints = false
        miniPreviousButton.tintColor = UIColor.white.withAlphaComponent(0.82)
        miniPreviousButton.setImage(UIImage(systemName: "backward.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)), for: .normal)
        miniPreviousButton.addTarget(self, action: #selector(playPreviousTrack), for: .touchUpInside)
        miniControls.addArrangedSubview(miniPreviousButton)

        miniPlayPauseButton = UIButton(type: .custom)
        miniPlayPauseButton.translatesAutoresizingMaskIntoConstraints = false
        miniPlayPauseButton.tintColor = primaryTextColor()
        miniPlayPauseButton.layer.cornerRadius = 0
        miniPlayPauseButton.layer.borderWidth = 0
        miniPlayPauseButton.backgroundColor = .clear
        miniPlayPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        miniPlayPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        miniControls.addArrangedSubview(miniPlayPauseButton)

        miniNextButton = UIButton(type: .system)
        miniNextButton.translatesAutoresizingMaskIntoConstraints = false
        miniNextButton.tintColor = UIColor.white.withAlphaComponent(0.82)
        miniNextButton.setImage(UIImage(systemName: "forward.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)), for: .normal)
        miniNextButton.addTarget(self, action: #selector(playNextTrack), for: .touchUpInside)
        miniControls.addArrangedSubview(miniNextButton)

        NSLayoutConstraint.activate([
            headerArea.topAnchor.constraint(equalTo: page1.safeAreaLayoutGuide.topAnchor),
            headerArea.bottomAnchor.constraint(equalTo: searchBar.topAnchor),
            headerArea.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            headerArea.trailingAnchor.constraint(equalTo: page1.trailingAnchor),

            // Header Titles: titleLabel "Metal." and importButton "+" vertically centered mathematically between safe zone and search bar
            titleLabel.centerYAnchor.constraint(equalTo: headerArea.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 20),

            importButton.centerYAnchor.constraint(equalTo: headerArea.centerYAnchor),
            importButton.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -20),
            importButton.widthAnchor.constraint(equalToConstant: 40),
            importButton.heightAnchor.constraint(equalToConstant: 40),

            // Search Bar: sits with generous empty space below safe zone, bridging the wave and bottomPanel
            searchBar.topAnchor.constraint(equalTo: page1.safeAreaLayoutGuide.topAnchor, constant: 92),
            searchBar.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 14),
            searchBar.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -14),
            searchBar.heightAnchor.constraint(equalToConstant: 44),

            // Pure Visual Wave: flows across the entire header area and spreads down behind bottomPanel's rounded corners
            myWaveView.topAnchor.constraint(equalTo: page1.topAnchor),
            myWaveView.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            myWaveView.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            myWaveView.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 72),

            // Bottom Underlay Panel: starts at the center of searchBar and extends to bottom of screen
            bottomPanel.topAnchor.constraint(equalTo: searchBar.centerYAnchor),
            bottomPanel.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: page1.bottomAnchor),

            // Floating Filters Container: floats above the song list inside the bottom panel, self-centering capsule
            floatingFiltersContainer.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 28),
            floatingFiltersContainer.centerXAnchor.constraint(equalTo: page1.centerXAnchor),
            floatingFiltersContainer.leadingAnchor.constraint(greaterThanOrEqualTo: page1.leadingAnchor, constant: 16),
            floatingFiltersContainer.trailingAnchor.constraint(lessThanOrEqualTo: page1.trailingAnchor, constant: -16),
            floatingFiltersContainer.heightAnchor.constraint(equalToConstant: 40),

            pillGlass.topAnchor.constraint(equalTo: floatingFiltersContainer.topAnchor),
            pillGlass.leadingAnchor.constraint(equalTo: floatingFiltersContainer.leadingAnchor),
            pillGlass.trailingAnchor.constraint(equalTo: floatingFiltersContainer.trailingAnchor),
            pillGlass.bottomAnchor.constraint(equalTo: floatingFiltersContainer.bottomAnchor),

            filtersScrollView.topAnchor.constraint(equalTo: floatingFiltersContainer.topAnchor),
            filtersScrollView.leadingAnchor.constraint(equalTo: floatingFiltersContainer.leadingAnchor, constant: 6),
            filtersScrollView.trailingAnchor.constraint(equalTo: floatingFiltersContainer.trailingAnchor, constant: -6),
            filtersScrollView.bottomAnchor.constraint(equalTo: floatingFiltersContainer.bottomAnchor),

            filtersStackView.topAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.topAnchor),
            filtersStackView.bottomAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.bottomAnchor),
            filtersStackView.leadingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.leadingAnchor),
            filtersStackView.trailingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.trailingAnchor),
            filtersStackView.heightAnchor.constraint(equalTo: filtersScrollView.heightAnchor),

            // TableView (Songs List): sits over bottomPanel, content begins below floating filters
            tableView.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 28),
            tableView.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor, constant: -10),

            // Mini Player Constraints
            miniPlayerView.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 16),
            miniPlayerView.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -16),
            miniPlayerView.bottomAnchor.constraint(equalTo: page1.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 58),

            miniCoverCard.leadingAnchor.constraint(equalTo: miniPlayerView.leadingAnchor, constant: 12),
            miniCoverCard.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor),
            miniCoverCard.widthAnchor.constraint(equalToConstant: 40),
            miniCoverCard.heightAnchor.constraint(equalToConstant: 40),

            miniCoverView.topAnchor.constraint(equalTo: miniCoverCard.topAnchor),
            miniCoverView.leadingAnchor.constraint(equalTo: miniCoverCard.leadingAnchor),
            miniCoverView.trailingAnchor.constraint(equalTo: miniCoverCard.trailingAnchor),
            miniCoverView.bottomAnchor.constraint(equalTo: miniCoverCard.bottomAnchor),

            miniTextStack.leadingAnchor.constraint(equalTo: miniCoverCard.trailingAnchor, constant: 12),
            miniTextStack.trailingAnchor.constraint(equalTo: miniControls.leadingAnchor, constant: -10),
            miniTextStack.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor),

            miniControls.trailingAnchor.constraint(equalTo: miniPlayerView.trailingAnchor, constant: -14),
            miniControls.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor),

            miniPlayPauseButton.widthAnchor.constraint(equalToConstant: 32),
            miniPlayPauseButton.heightAnchor.constraint(equalToConstant: 32),

            miniPreviousButton.widthAnchor.constraint(equalToConstant: 24),
            miniPreviousButton.heightAnchor.constraint(equalToConstant: 32),

            miniNextButton.widthAnchor.constraint(equalToConstant: 24),
            miniNextButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        let pillWidthConstraint = floatingFiltersContainer.widthAnchor.constraint(equalTo: filtersStackView.widthAnchor, constant: 12)
        pillWidthConstraint.priority = UILayoutPriority(999)
        pillWidthConstraint.isActive = true

        rebuildFiltersRow()
    }

    @objc func showSettingsTapped() {
        view.endEditing(true)
        scrollView.setContentOffset(.zero, animated: true)
    }

    func setupPage2NowPlaying() {
        page2.backgroundColor = .clear

        // 0. Metal-based Ambient Fluid Plasma (synthesized solely from artwork colors)
        playerFluidView = PlayerFluidBackgroundView()
        playerFluidView.translatesAutoresizingMaskIntoConstraints = false
        playerFluidView.isUserInteractionEnabled = false
        page2.insertSubview(playerFluidView, at: 0)

        // Full Edge-to-Edge Dynamic Ambient Gradient Background (Fills status bar notch & home indicator)
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1.0).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        page2.layer.insertSublayer(gradient, at: 0)
        playerGradientLayer = gradient

        // --- 1. Top Navigation Bar (Positioned at Safe Area Top) ---
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        page2.addSubview(topBar)

        let dismissButton = UIButton(type: .system)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)), for: .normal)
        dismissButton.tintColor = .white
        dismissButton.addTarget(self, action: #selector(dismissPlayerTapped), for: .touchUpInside)
        topBar.addSubview(dismissButton)

        playerHeaderLabel = UILabel()
        playerHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        playerHeaderLabel.font = UIFont(name: "Georgia-Bold", size: 13)
        playerHeaderLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        playerHeaderLabel.textAlignment = .center
        playerHeaderLabel.text = "ALL SONGS"
        topBar.addSubview(playerHeaderLabel)

        let topOptionsButton = UIButton(type: .system)
        topOptionsButton.translatesAutoresizingMaskIntoConstraints = false
        topOptionsButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)), for: .normal)
        topOptionsButton.tintColor = .white
        topOptionsButton.addTarget(self, action: #selector(optionsTapped), for: .touchUpInside)
        topBar.addSubview(topOptionsButton)

        // --- 2. Bottom Secondary Bar (Positioned at Safe Area Bottom) ---
        let bottomBar = UIStackView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.axis = .horizontal
        bottomBar.alignment = .center
        bottomBar.distribution = .equalSpacing
        page2.addSubview(bottomBar)

        let deviceButton = UIButton(type: .system)
        deviceButton.setImage(UIImage(systemName: "airplayaudio", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
        deviceButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        deviceButton.addTarget(self, action: #selector(deviceButtonTapped), for: .touchUpInside)
        bottomBar.addArrangedSubview(deviceButton)

        let rightBottomStack = UIStackView()
        rightBottomStack.axis = .horizontal
        rightBottomStack.spacing = 20
        rightBottomStack.alignment = .center
        bottomBar.addArrangedSubview(rightBottomStack)

        let shareButton = UIButton(type: .system)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
        shareButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        rightBottomStack.addArrangedSubview(shareButton)

        let queueButton = UIButton(type: .system)
        queueButton.setImage(UIImage(systemName: "list.bullet", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
        queueButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        queueButton.addTarget(self, action: #selector(queueButtonTapped), for: .touchUpInside)
        rightBottomStack.addArrangedSubview(queueButton)

        // --- 3. Vertically Centered Main Body (Y-Center of Screen) ---
        let centerContentView = UIView()
        centerContentView.translatesAutoresizingMaskIntoConstraints = false
        page2.addSubview(centerContentView)

        // Artwork Card (Square Container)
        coverArtCard = UIView()
        coverArtCard.translatesAutoresizingMaskIntoConstraints = false
        coverArtCard.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        coverArtCard.layer.cornerRadius = 16
        coverArtCard.clipsToBounds = true
        centerContentView.addSubview(coverArtCard)

        coverImageView = UIImageView()
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverArtCard.addSubview(coverImageView)

        // Info Stack (Title + Artist on left, Heart Favorite button on right)
        let infoStack = UIStackView()
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.axis = .horizontal
        infoStack.alignment = .center
        infoStack.spacing = 12
        centerContentView.addSubview(infoStack)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        infoStack.addArrangedSubview(textStack)

        trackTitleLabel = UILabel()
        trackTitleLabel.font = UIFont(name: "Georgia-Bold", size: 22)
        trackTitleLabel.textColor = .white
        trackTitleLabel.textAlignment = .left
        trackTitleLabel.numberOfLines = 2
        trackTitleLabel.text = "No Track Selected"
        textStack.addArrangedSubview(trackTitleLabel)

        artistLabel = UILabel()
        artistLabel.font = UIFont(name: "Georgia-Italic", size: 16)
        artistLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        artistLabel.textAlignment = .left
        artistLabel.text = "Select a song"
        textStack.addArrangedSubview(artistLabel)

        playerFavoriteButton = UIButton(type: .system)
        playerFavoriteButton.translatesAutoresizingMaskIntoConstraints = false
        playerFavoriteButton.setImage(UIImage(systemName: "heart", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        playerFavoriteButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        playerFavoriteButton.setContentHuggingPriority(.required, for: .horizontal)
        playerFavoriteButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        playerFavoriteButton.addTarget(self, action: #selector(playerFavoriteTapped), for: .touchUpInside)
        infoStack.addArrangedSubview(playerFavoriteButton)

        // Progress Slider & Timers
        progressSlider = UISlider()
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        progressSlider.minimumTrackTintColor = .white
        progressSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
        progressSlider.setThumbImage(makeThumbImage(size: 10), for: .normal)
        progressSlider.addTarget(self, action: #selector(sliderValueChanging(_:)), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderFinishedChanging(_:)), for: [.touchUpInside, .touchUpOutside])
        centerContentView.addSubview(progressSlider)

        elapsedLabel = UILabel()
        elapsedLabel.translatesAutoresizingMaskIntoConstraints = false
        elapsedLabel.font = UIFont(name: "Georgia-Italic", size: 12)
        elapsedLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        elapsedLabel.text = "0:00"
        centerContentView.addSubview(elapsedLabel)

        remainingLabel = UILabel()
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        remainingLabel.font = UIFont(name: "Georgia-Italic", size: 12)
        remainingLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        remainingLabel.text = "-0:00"
        centerContentView.addSubview(remainingLabel)

        // Main Controls Stack (5 buttons)
        let controlsStack = UIStackView()
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .horizontal
        controlsStack.alignment = .center
        controlsStack.distribution = .equalSpacing
        centerContentView.addSubview(controlsStack)

        shuffleButton = UIButton(type: .system)
        shuffleButton.setImage(UIImage(systemName: "shuffle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)), for: .normal)
        shuffleButton.tintColor = UIColor.white.withAlphaComponent(0.4)
        shuffleButton.addTarget(self, action: #selector(shuffleTapped), for: .touchUpInside)
        controlsStack.addArrangedSubview(shuffleButton)

        let prevButton = UIButton(type: .system)
        prevButton.setImage(UIImage(systemName: "backward.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)), for: .normal)
        prevButton.tintColor = .white
        prevButton.addTarget(self, action: #selector(playPreviousTrack), for: .touchUpInside)
        controlsStack.addArrangedSubview(prevButton)

        playPauseButton = UIButton(type: .custom)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.backgroundColor = .white
        playPauseButton.layer.cornerRadius = 32
        playPauseButton.tintColor = .black
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        controlsStack.addArrangedSubview(playPauseButton)

        let nextButton = UIButton(type: .system)
        nextButton.setImage(UIImage(systemName: "forward.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)), for: .normal)
        nextButton.tintColor = .white
        nextButton.addTarget(self, action: #selector(playNextTrack), for: .touchUpInside)
        controlsStack.addArrangedSubview(nextButton)

        repeatButton = UIButton(type: .system)
        repeatButton.setImage(UIImage(systemName: "repeat", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)), for: .normal)
        repeatButton.tintColor = UIColor.white.withAlphaComponent(0.4)
        repeatButton.addTarget(self, action: #selector(repeatTapped), for: .touchUpInside)
        controlsStack.addArrangedSubview(repeatButton)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Full Edge-to-Edge Player Fluid Plasma Background
            playerFluidView.topAnchor.constraint(equalTo: page2.topAnchor),
            playerFluidView.leadingAnchor.constraint(equalTo: page2.leadingAnchor),
            playerFluidView.trailingAnchor.constraint(equalTo: page2.trailingAnchor),
            playerFluidView.bottomAnchor.constraint(equalTo: page2.bottomAnchor),

            // Top Bar (SafeArea top)
            topBar.topAnchor.constraint(equalTo: page2.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: page2.leadingAnchor, constant: 20),
            topBar.trailingAnchor.constraint(equalTo: page2.trailingAnchor, constant: -20),
            topBar.heightAnchor.constraint(equalToConstant: 36),

            dismissButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            dismissButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 32),
            dismissButton.heightAnchor.constraint(equalToConstant: 32),

            playerHeaderLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            playerHeaderLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            topOptionsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            topOptionsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            topOptionsButton.widthAnchor.constraint(equalToConstant: 32),
            topOptionsButton.heightAnchor.constraint(equalToConstant: 32),

            // Bottom Bar (SafeArea bottom)
            bottomBar.bottomAnchor.constraint(equalTo: page2.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomBar.leadingAnchor.constraint(equalTo: page2.leadingAnchor, constant: 28),
            bottomBar.trailingAnchor.constraint(equalTo: page2.trailingAnchor, constant: -28),
            bottomBar.heightAnchor.constraint(equalToConstant: 36),

            // Center Content View (Vertically centered on Y axis!)
            centerContentView.centerYAnchor.constraint(equalTo: page2.centerYAnchor, constant: -8),
            centerContentView.leadingAnchor.constraint(equalTo: page2.leadingAnchor, constant: 28),
            centerContentView.trailingAnchor.constraint(equalTo: page2.trailingAnchor, constant: -28),
            centerContentView.topAnchor.constraint(greaterThanOrEqualTo: topBar.bottomAnchor, constant: 12),
            centerContentView.bottomAnchor.constraint(lessThanOrEqualTo: bottomBar.topAnchor, constant: -12),

            // Artwork Card inside centerContentView
            coverArtCard.topAnchor.constraint(equalTo: centerContentView.topAnchor),
            coverArtCard.leadingAnchor.constraint(equalTo: centerContentView.leadingAnchor),
            coverArtCard.trailingAnchor.constraint(equalTo: centerContentView.trailingAnchor),
            coverArtCard.heightAnchor.constraint(equalTo: coverArtCard.widthAnchor),

            coverImageView.topAnchor.constraint(equalTo: coverArtCard.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: coverArtCard.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: coverArtCard.trailingAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: coverArtCard.bottomAnchor),

            // Info Stack
            infoStack.topAnchor.constraint(equalTo: coverArtCard.bottomAnchor, constant: 20),
            infoStack.leadingAnchor.constraint(equalTo: centerContentView.leadingAnchor),
            infoStack.trailingAnchor.constraint(equalTo: centerContentView.trailingAnchor),

            // Progress Slider & Labels
            progressSlider.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 18),
            progressSlider.leadingAnchor.constraint(equalTo: centerContentView.leadingAnchor),
            progressSlider.trailingAnchor.constraint(equalTo: centerContentView.trailingAnchor),

            elapsedLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 6),
            elapsedLabel.leadingAnchor.constraint(equalTo: progressSlider.leadingAnchor),

            remainingLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 6),
            remainingLabel.trailingAnchor.constraint(equalTo: progressSlider.trailingAnchor),

            // Main Controls Stack
            controlsStack.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 18),
            controlsStack.leadingAnchor.constraint(equalTo: centerContentView.leadingAnchor),
            controlsStack.trailingAnchor.constraint(equalTo: centerContentView.trailingAnchor),
            controlsStack.bottomAnchor.constraint(equalTo: centerContentView.bottomAnchor),

            playPauseButton.widthAnchor.constraint(equalToConstant: 64),
            playPauseButton.heightAnchor.constraint(equalToConstant: 64)
        ])

        applyPlayerBackgroundStyle()
    }

    func updateCardBorders() {
        let border = cardBorderColor().resolvedColor(with: traitCollection).cgColor
        bottomPanel?.backgroundColor = cardBackgroundColor()
        bottomPanel?.layer.borderColor = border
        floatingFiltersContainer?.layer.borderColor = border
        searchBar?.searchTextField.backgroundColor = cardBackgroundColor()
        searchBar?.searchTextField.layer.borderColor = border

        miniPlayerView?.layer.borderColor = border
        miniCoverCard?.layer.borderColor = border
        miniPlayPauseButton?.layer.borderColor = border
        activeSheetView?.layer.borderColor = border

        playerGradientLayer?.frame = page2?.bounds ?? .zero

        progressSlider?.setThumbImage(makeThumbImage(size: 10), for: .normal)
    }

    func makeThumbImage(size: CGFloat) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.white.cgColor)
        context?.fillEllipse(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    // MARK: - Cylinder / Drum-Roll Fade Overlays

    func applyTableGradientMask() {
        page1.viewWithTag(7701)?.removeFromSuperview()
        page1.viewWithTag(7702)?.removeFromSuperview()

        let topFade = GradientOverlayView(fromTop: true) { [weak self] in
            self?.cardBackgroundColor() ?? .clear
        }
        topFade.tag = 7701
        page1.addSubview(topFade)

        let bottomFade = GradientOverlayView(fromTop: false) { [weak self] in
            self?.cardBackgroundColor() ?? .clear
        }
        bottomFade.tag = 7702
        page1.addSubview(bottomFade)

        page1.setNeedsLayout()
    }

    func updateTableGradientMaskFrame() {
        guard let top = page1?.viewWithTag(7701) as? GradientOverlayView,
              let bot = page1?.viewWithTag(7702) as? GradientOverlayView else { return }

        let tableFrame = tableView.frame
        let fadeHeight: CGFloat = 36

        // Position overlays precisely over the tableView edges
        top.frame = CGRect(x: tableFrame.minX, y: tableFrame.minY,
                           width: tableFrame.width, height: fadeHeight)
        bot.frame = CGRect(x: tableFrame.minX, y: tableFrame.maxY - fadeHeight,
                           width: tableFrame.width, height: fadeHeight)

        top.setNeedsLayout()
        top.layoutIfNeeded()
        bot.setNeedsLayout()
        bot.layoutIfNeeded()
    }
}

// MARK: - PlayerPageView (Edge-to-Edge Ambient Gradient Layer Backed View)

class PlayerPageView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    var gradientLayer: CAGradientLayer {
        return layer as! CAGradientLayer
    }
}

// MARK: - GradientOverlayView Class

class GradientOverlayView: UIView {
    private let gradient = CAGradientLayer()
    private let fromTop: Bool
    private let colorProvider: () -> UIColor

    init(fromTop: Bool, colorProvider: @escaping () -> UIColor) {
        self.fromTop = fromTop
        self.colorProvider = colorProvider
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear

        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint   = CGPoint(x: 0.5, y: 1)
        self.layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = self.bounds

        let bg = colorProvider().resolvedColor(with: self.traitCollection)
        let transparentBg = bg.withAlphaComponent(0.0)

        if fromTop {
            // Completely smooth continuous fade from solid to transparent, eliminating any hard line
            gradient.colors = [bg.cgColor, transparentBg.cgColor]
            gradient.locations = [0.0, 1.0]
        } else {
            // Completely smooth continuous fade from transparent to solid
            gradient.colors = [transparentBg.cgColor, bg.cgColor]
            gradient.locations = [0.0, 1.0]
        }
    }
}

private extension UILabel {
    func letterSpacing(_ value: CGFloat) {
        guard let text else { return }
        attributedText = NSAttributedString(string: text, attributes: [.kern: value])
    }
}

// MARK: - Yandex Music "Моя волна" (My Wave) Metal Shader Visualizer

private let waveMetalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct WaveUniforms {
    float2 resolution;
    float time;
    float amplitude;
    float isPlaying;
    float isDark;
    float hasThemeColor;
    float padding1;
    float3 themeColor;
};

vertex VertexOut waveVertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

// Modulo 289
float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float3 permute(float3 x) { return mod289(((x * 34.0) + 1.0) * x); }

// 2D Simplex Noise
float snoise(float2 v) {
    const float4 C = float4(0.211324865405187,
                            0.366025403784439,
                           -0.577350269189626,
                            0.024390243902439);
    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v -   i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0))
                     + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

fragment float4 waveFragmentShader(
    VertexOut in [[stage_in]],
    constant WaveUniforms &uniforms [[buffer(0)]]
) {
    float2 res = uniforms.resolution;
    if (res.x <= 0.0 || res.y <= 0.0) {
        return float4(0.0);
    }

    float minDim = min(res.x, res.y);
    float2 p = (in.position.xy - 0.5 * res) / minDim;

    // Slight vertical center offset for balanced visual mass extending to screen top
    p.y += 0.07;

    float t = uniforms.time * 0.28;
    float amp = uniforms.amplitude;

    // Polar coordinates from center
    float angle = atan2(p.y, p.x);
    float dist = length(p);
    float2 dir = float2(cos(angle), sin(angle));

    // Domain warping vectors
    float2 warp1 = float2(
        snoise(dir * 1.4 + float2(t * 0.28, 0.6)),
        snoise(dir * 1.4 + float2(1.9, t * 0.22))
    );
    float2 warp2 = float2(
        snoise(p * 2.0 + warp1 * 0.55 + float2(t * 0.18, -t * 0.15)),
        snoise(p * 2.0 - warp1 * 0.55 + float2(-t * 0.14, t * 0.20))
    );

    // 1. Large low-frequency bulges and smooth inward dents (6-10s cycle)
    float bulgeLarge = snoise(dir * 1.15 + warp1 * 0.45 + float2(t * 0.20, t * 0.16));

    // 2. Medium asymmetric protrusions (independent frequency and drift)
    float bulgeMedium = snoise(dir * 2.4 - warp2 * 0.5 + float2(-t * 0.26, t * 0.22));

    // 3. Spatial fluid convection through 2D space
    float bulgeSpatial = snoise(p * 1.7 + warp2 * 0.35 + float2(t * 0.12, -t * 0.15));

    // Base radius: fills the area generously with organic curvature
    float baseRadius = 0.55;
    float targetRadius = baseRadius + (bulgeLarge * 0.22 + bulgeMedium * 0.12 + bulgeSpatial * 0.08) * amp;

    // Signed distance to the morphing contour
    float d = dist - targetRadius;

    // Layer 1: Huge soft ambient glow extending edge-to-edge
    float ambientGlow = smoothstep(0.60, -0.22, d);

    // Layer 2: Colored blurred mass
    float blurredMass = smoothstep(0.34, -0.14, d);

    // Layer 3: Main brighter organic body
    float mainBody = smoothstep(0.10, -0.16, d);

    // Layer 4: Deep dense central core
    float deepCore = smoothstep(0.00, -0.30, d);

    // Independent drifting coordinates for the internal liquid color regions:
    float2 colorCoords1 = p * 1.4 + float2(t * 0.15, -t * 0.11);
    float2 colorCoords2 = p * 1.7 + float2(-t * 0.13, t * 0.16);
    float2 colorCoords3 = p * 2.0 + float2(sin(t * 0.16) * 0.35, cos(t * 0.14) * 0.35);

    float internalFluid1 = snoise(colorCoords1 + warp1 * 0.45);
    float internalFluid2 = snoise(colorCoords2 + internalFluid1 * 0.55);
    float internalFluid3 = snoise(colorCoords3 - internalFluid2 * 0.45);

    // Swirling directional angle for region separation (purple vs magenta):
    float fluidAngle = angle + internalFluid1 * 1.6 + t * 0.10;
    float dirX = cos(fluidAngle);

    // Drifting warm yellow core spot (slowly shifts inside the body):
    float2 yellowCenterOffset = float2(
        snoise(float2(t * 0.10, 2.7)) * 0.16,
        snoise(float2(4.8, t * 0.12)) * 0.14 + 0.03
    );
    float distToYellow = length(p - yellowCenterOffset);

    // Base saturated Yandex Music "My Wave" palette:
    float3 cDeepIndigo   = float3(0.22, 0.04, 0.44); // ambient deep purple-indigo
    float3 cRoyalPurple  = float3(0.58, 0.06, 0.76); // rich royal purple
    float3 cHotMagenta   = float3(0.98, 0.12, 0.58); // hot pink / electric magenta
    float3 cMoltenOrange = float3(1.00, 0.42, 0.10); // glowing sunset orange
    float3 cGoldenYellow = float3(1.00, 0.88, 0.22); // radiant yellow / warm amber
    float3 cHighlight    = float3(1.00, 0.98, 0.86); // luminous center highlight
    float3 cElectricCyan = float3(0.12, 0.78, 0.94); // soft electric cyan accent

    // Subtly adapt colors to album artwork if themeColor is present ("цвета мб чуток под обложку")
    if (uniforms.hasThemeColor > 0.5) {
        float3 cover = uniforms.themeColor;
        float maxC = max(cover.r, max(cover.g, cover.b));
        float minC = min(cover.r, min(cover.g, cover.b));
        float l = (maxC + minC) * 0.5;
        float3 vibrantCover = saturate((cover - l) * 1.4 + l + 0.05);

        cRoyalPurple  = mix(cRoyalPurple, vibrantCover * float3(0.75, 0.45, 0.9) + float3(0.15, 0.03, 0.22), 0.40);
        cHotMagenta   = mix(cHotMagenta, vibrantCover * 1.1 + float3(0.18, 0.02, 0.12), 0.42);
        cMoltenOrange = mix(cMoltenOrange, saturate(vibrantCover * 1.15 + float3(0.22, 0.14, 0.0)), 0.35);
        cGoldenYellow = mix(cGoldenYellow, saturate(vibrantCover * float3(1.1, 1.0, 0.5) + float3(0.2, 0.2, 0.0)), 0.26);
    }

    // Blend purple and magenta across asymmetric lobes:
    float magentaMix = smoothstep(-0.40, 0.50, dirX + internalFluid2 * 0.40);
    float3 liquidColor = mix(cRoyalPurple, cHotMagenta, magentaMix);

    // Blend molten orange toward the center:
    float orangeSpread = smoothstep(0.46, 0.12, dist + internalFluid2 * 0.10);
    liquidColor = mix(liquidColor, cMoltenOrange, orangeSpread * 0.86);

    // Drifting golden yellow center:
    float yellowMix = smoothstep(0.30, 0.03, distToYellow + internalFluid1 * 0.08);
    liquidColor = mix(liquidColor, cGoldenYellow, yellowMix);

    // Inner highlight:
    float highlightMix = smoothstep(0.12, 0.00, distToYellow + internalFluid3 * 0.05);
    liquidColor = mix(liquidColor, cHighlight, highlightMix * 0.72);

    // Electric cyan drift along fluid rift:
    float cyanDrift = smoothstep(0.74, 0.96, internalFluid3) * smoothstep(0.30, 0.08, abs(dist - 0.26));
    liquidColor = mix(liquidColor, cElectricCyan, cyanDrift * 0.40);

    // Deep purple outer halo falloff:
    liquidColor = mix(cDeepIndigo, liquidColor, smoothstep(0.42, 0.04, d));

    // Volumetric luminance boosting:
    float bloom = 1.0 + deepCore * 0.32 + highlightMix * 0.42;
    float3 finalRGB = liquidColor * bloom;

    // Alpha falloff blending all layers:
    float alpha = mainBody * 0.94 + blurredMass * 0.46 + ambientGlow * 0.26;
    alpha = clamp(alpha, 0.0, 1.0);

    // Premultiplied alpha for seamless transparency
    return float4(finalRGB * alpha, alpha);
}
"""

class YandexWaveView: UIView, MTKViewDelegate {

    private struct WaveUniforms {
        var resolution: SIMD2<Float> = .zero
        var time: Float = 0.0
        var amplitude: Float = 0.7
        var isPlaying: Float = 0.0
        var isDark: Float = 1.0
        var hasThemeColor: Float = 0.0
        var padding1: Float = 0.0
        var themeColor: SIMD3<Float> = .zero
    }

    private var mtkView: MTKView?
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?

    private var elapsedTime: Float = 0.0
    private var lastFrameTime: CFTimeInterval = 0.0
    private var isPlayingState: Bool = false
    private var currentAmplitude: Float = 0.7
    private var targetAmplitude: Float = 0.7

    private var currentThemeColor: SIMD3<Float> = .zero
    private var targetThemeColor: SIMD3<Float> = .zero
    private var hasThemeColor: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMetalPipeline()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalPipeline()
    }

    private func setupMetalPipeline() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true

        guard let metalDevice = MTLCreateSystemDefaultDevice() else { return }
        self.device = metalDevice
        self.commandQueue = metalDevice.makeCommandQueue()

        do {
            let library = try metalDevice.makeLibrary(source: waveMetalShaderSource, options: nil)
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "waveVertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "waveFragmentShader")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            self.pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)

            let view = MTKView(frame: bounds, device: metalDevice)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.delegate = self
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            view.isOpaque = false
            view.layer.isOpaque = false
            view.backgroundColor = .clear
            view.preferredFramesPerSecond = 60
            view.isPaused = false
            view.enableSetNeedsDisplay = false
            addSubview(view)

            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            self.mtkView = view
        } catch {
            // Pipeline creation failed; safe empty fallback
        }
    }

    func setPlaying(_ playing: Bool) {
        isPlayingState = playing
        targetAmplitude = playing ? 1.25 : 0.70
    }

    func setThemeColor(_ color: UIColor?) {
        guard let color = color else {
            hasThemeColor = false
            return
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            targetThemeColor = SIMD3<Float>(Float(r), Float(g), Float(b))
            hasThemeColor = true
            if currentThemeColor == .zero {
                currentThemeColor = targetThemeColor
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        mtkView?.isPaused = (window == nil)
        if window != nil {
            lastFrameTime = CACurrentMediaTime()
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let pipeline = pipelineState,
              let commandQueue = commandQueue else { return }

        let now = CACurrentMediaTime()
        let dt = lastFrameTime > 0 ? Float(min(now - lastFrameTime, 0.1)) : 0.016
        lastFrameTime = now

        let speedMultiplier: Float = isPlayingState ? 1.40 : 0.85
        elapsedTime += dt * speedMultiplier
        if elapsedTime > 10000.0 { elapsedTime = 0 }

        currentAmplitude += (targetAmplitude - currentAmplitude) * 0.05

        if hasThemeColor {
            currentThemeColor += (targetThemeColor - currentThemeColor) * 0.04
        }

        let drawableSize = view.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else { return }

        var uniforms = WaveUniforms(
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
            time: elapsedTime,
            amplitude: currentAmplitude,
            isPlaying: isPlayingState ? 1.0 : 0.0,
            isDark: traitCollection.userInterfaceStyle == .dark ? 1.0 : 0.0,
            hasThemeColor: hasThemeColor ? 1.0 : 0.0,
            padding1: 0.0,
            themeColor: currentThemeColor
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<WaveUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Device Model Name Resolver

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        switch identifier {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "iPhone17,5": return "iPhone 16e"
        case "i386", "x86_64", "arm64":
            if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
                return "Simulator (\(simModel))"
            }
            return "iPhone Simulator"
        default:
            return identifier.isEmpty ? UIDevice.current.model : identifier
        }
    }
}

// MARK: - Color Interpolator

func interpolateColor(from: UIColor, to: UIColor, progress: CGFloat) -> UIColor {
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

    from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

    let p = max(0.0, min(1.0, progress))
    return UIColor(
        red: r1 + (r2 - r1) * p,
        green: g1 + (g2 - g1) * p,
        blue: b1 + (b2 - b1) * p,
        alpha: a1 + (a2 - a1) * p
    )
}

// MARK: - Metal-based Player Fluid Plasma Background

let playerFluidShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct PlayerFluidUniforms {
    float2 resolution;
    float time;
    float amplitude;
    float isPlaying;
    float isDark;
    float padding1;
    float padding2;
    float3 artworkColor;
};

vertex VertexOut playerFluidVertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

// Modulo 289
static inline float3 pf_mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
static inline float2 pf_mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
static inline float3 pf_permute(float3 x) { return pf_mod289(((x * 34.0) + 1.0) * x); }

// 2D Simplex Noise
static inline float pf_snoise(float2 v) {
    const float4 C = float4(0.211324865405187,
                            0.366025403784439,
                           -0.577350269189626,
                            0.024390243902439);
    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v -   i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = pf_mod289(i);
    float3 p = pf_permute(pf_permute(i.y + float3(0.0, i1.y, 1.0))
                     + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

fragment float4 playerFluidFragmentShader(
    VertexOut in [[stage_in]],
    constant PlayerFluidUniforms &uniforms [[buffer(0)]]
) {
    float2 res = uniforms.resolution;
    if (res.x <= 0.0 || res.y <= 0.0) {
        return float4(0.0);
    }

    float2 uv = in.position.xy / res;
    float minDim = min(res.x, res.y);
    float2 p = (in.position.xy - 0.5 * res) / minDim;

    float t = uniforms.time * 0.16;
    float amp = uniforms.amplitude;

    // Multi-octave organic domain warping
    float2 q = float2(
        pf_snoise(p * 1.2 + float2(t * 0.10, t * 0.08)),
        pf_snoise(p * 1.2 + float2(-t * 0.09, t * 0.11))
    );

    float2 r = float2(
        pf_snoise(p * 1.8 + 1.2 * q + float2(1.7, 9.2) + float2(t * 0.06, -t * 0.08)),
        pf_snoise(p * 1.8 + 1.2 * q + float2(8.3, 2.8) + float2(-t * 0.07, t * 0.05))
    );

    float f = pf_snoise(p * 1.5 + 1.4 * r + float2(t * 0.05, t * 0.04));

    // Synthesize harmonious palette ONLY from artworkColor ("онли артворк цвета")
    float3 rawColor = uniforms.artworkColor;
    if (length(rawColor) < 0.02) {
        rawColor = float3(0.18, 0.18, 0.22);
    }

    // Boost artwork saturation for vibrant fluid lobes
    float maxC = max(rawColor.r, max(rawColor.g, rawColor.b));
    float minC = min(rawColor.r, min(rawColor.g, rawColor.b));
    float lum = (maxC + minC) * 0.5;
    float3 satArt = saturate((rawColor - lum) * 1.35 + lum);

    // Deep velvety background floor (keeps controls visible and provides deep contrast)
    float3 cBase = satArt * 0.12 + float3(0.025, 0.025, 0.035);

    // Primary rich artwork color
    float3 cPrimary = satArt * 0.70 + float3(0.04, 0.04, 0.05);

    // Harmonic shifted tone (subtle complementary/analogous variation from artwork color)
    float3 cHarmonic = satArt.brg * 0.55 + satArt * 0.35 + float3(0.03, 0.02, 0.05);

    // Soft luminous bloom highlight
    float3 cHighlight = saturate(satArt * 1.1 + float3(0.14, 0.14, 0.16));

    // Multi-layered organic blend
    float weightPrimary = smoothstep(-0.45, 0.45, f + q.x * 0.35 * amp);
    float weightHarmonic = smoothstep(-0.35, 0.55, r.y + q.y * 0.40 * amp);
    float weightHighlight = smoothstep(0.30, 0.85, f * amp);

    float3 fluidColor = mix(cBase, cPrimary, weightPrimary);
    fluidColor = mix(fluidColor, cHarmonic, weightHarmonic * 0.65);
    fluidColor += cHighlight * weightHighlight * 0.38;

    // Compositional vignette for player usability:
    // Keep lower section (slider + buttons) darker and calmer
    float bottomDamping = smoothstep(0.40, 0.95, uv.y);
    fluidColor = mix(fluidColor, cBase, bottomDamping * 0.50);

    // Soft radial contrast behind album artwork center
    float centerDist = length(p);
    float centerSoftness = smoothstep(0.15, 0.65, centerDist);
    fluidColor = mix(fluidColor * 0.85, fluidColor, centerSoftness);

    return float4(fluidColor, 1.0);
}
"""

class PlayerFluidBackgroundView: UIView, MTKViewDelegate {
    struct PlayerFluidUniforms {
        var resolution: SIMD2<Float> = .zero
        var time: Float = 0
        var amplitude: Float = 0.7
        var isPlaying: Float = 0.0
        var isDark: Float = 1.0
        var padding1: Float = 0.0
        var padding2: Float = 0.0
        var artworkColor: SIMD3<Float> = .zero
    }

    private var mtkView: MTKView?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var startTime: CFTimeInterval = 0

    private var isPlayingState: Bool = false
    private var currentAmplitude: Float = 0.65
    private var targetAmplitude: Float = 0.65

    private var currentArtworkColor: SIMD3<Float> = SIMD3<Float>(0.13, 0.13, 0.15)
    private var targetArtworkColor: SIMD3<Float> = SIMD3<Float>(0.13, 0.13, 0.15)

    var isPaused: Bool {
        get { mtkView?.isPaused ?? false }
        set { mtkView?.isPaused = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMetalPipeline()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalPipeline()
    }

    private func setupMetalPipeline() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let metalView = MTKView(frame: .zero, device: device)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.clearColor = MTLClearColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1.0)
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.delegate = self
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.preferredFramesPerSecond = 60
        addSubview(metalView)
        self.mtkView = metalView

        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        do {
            let library = try device.makeLibrary(source: playerFluidShaderSource, options: nil)
            let vertexFunction = library.makeFunction(name: "playerFluidVertexShader")
            let fragmentFunction = library.makeFunction(name: "playerFluidFragmentShader")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            self.commandQueue = device.makeCommandQueue()
            self.startTime = CACurrentMediaTime()
        } catch {
            print("Failed to compile player fluid Metal shader: \(error)")
        }
    }

    func setPlaying(_ playing: Bool) {
        isPlayingState = playing
        targetAmplitude = playing ? 1.15 : 0.65
    }

    func setArtworkColor(_ color: UIColor?) {
        guard let color = color else { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            targetArtworkColor = SIMD3<Float>(Float(r), Float(g), Float(b))
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        mtkView?.isPaused = (window == nil)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipelineState = pipelineState,
              let commandQueue = commandQueue,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        let elapsed = Float(CACurrentMediaTime() - startTime)
        currentAmplitude += (targetAmplitude - currentAmplitude) * 0.04
        currentArtworkColor += (targetArtworkColor - currentArtworkColor) * 0.03

        let drawableSize = view.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else { return }

        var uniforms = PlayerFluidUniforms(
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
            time: elapsed,
            amplitude: currentAmplitude,
            isPlaying: isPlayingState ? 1.0 : 0.0,
            isDark: traitCollection.userInterfaceStyle == .dark ? 1.0 : 0.0,
            padding1: 0.0,
            padding2: 0.0,
            artworkColor: currentArtworkColor
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<PlayerFluidUniforms>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}


