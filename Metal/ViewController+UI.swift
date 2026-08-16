//
//  ViewController+UI.swift
//  Metal
//

import UIKit

extension ViewController {

    // MARK: - Metal Dark Palette

    func primaryBackgroundColor() -> UIColor {
        UIColor(red: 0.055, green: 0.055, blue: 0.063, alpha: 1.0)
    }

    func cardBackgroundColor() -> UIColor {
        UIColor(red: 0.095, green: 0.095, blue: 0.108, alpha: 1.0)
    }

    func cardBorderColor() -> UIColor {
        UIColor.white.withAlphaComponent(0.09)
    }

    func primaryTextColor() -> UIColor {
        UIColor(red: 0.957, green: 0.945, blue: 0.914, alpha: 1.0)
    }

    func secondaryTextColor() -> UIColor {
        UIColor(red: 0.57, green: 0.57, blue: 0.59, alpha: 1.0)
    }

    func progressTrackColor() -> UIColor {
        UIColor.white.withAlphaComponent(0.12)
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

    // MARK: - UI Layout Setup

    func setupUI() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = primaryBackgroundColor()

        // Paging ScrollView - Edge-to-Edge full screen
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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

        let eyebrowLabel = UILabel()
        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        eyebrowLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        eyebrowLabel.textColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
        eyebrowLabel.text = "KRANK"
        eyebrowLabel.letterSpacing(1.8)
        page0.addSubview(eyebrowLabel)

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

            eyebrowLabel.topAnchor.constraint(equalTo: page0.safeAreaLayoutGuide.topAnchor, constant: 14),
            eyebrowLabel.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),

            titleLabel.topAnchor.constraint(equalTo: eyebrowLabel.bottomAnchor, constant: 5),
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
    }

    @objc func showLibraryTapped() {
        view.endEditing(true)
        scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width, y: 0), animated: true)
    }

    @objc func aidjToggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "Metal_AIDJEnabled")

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    func setupPage1Library() {
        page1.backgroundColor = primaryBackgroundColor()

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 42)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = "Metal."
        page1.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont(name: "Georgia-Italic", size: 16)
        subtitleLabel.textColor = secondaryTextColor()
        subtitleLabel.text = "Your auditory shelf."
        page1.addSubview(subtitleLabel)

        importButton = UIButton(type: .system)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)), for: .normal)
        importButton.tintColor = primaryTextColor()
        importButton.backgroundColor = .clear
        importButton.accessibilityLabel = "Import Music"
        importButton.addTarget(self, action: #selector(importMusicButtonTapped), for: .touchUpInside)
        page1.addSubview(importButton)

        searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Search songs..."
        searchBar.delegate = self
        searchBar.searchTextField.backgroundColor = cardBackgroundColor()
        searchBar.searchTextField.textColor = primaryTextColor()
        searchBar.searchTextField.leftView?.tintColor = secondaryTextColor()
        searchBar.searchTextField.layer.cornerRadius = 14
        searchBar.searchTextField.clipsToBounds = true
        page1.addSubview(searchBar)

        filtersScrollView = UIScrollView()
        filtersScrollView.translatesAutoresizingMaskIntoConstraints = false
        filtersScrollView.showsHorizontalScrollIndicator = false
        filtersScrollView.bounces = true
        page1.addSubview(filtersScrollView)

        filtersStackView = UIStackView()
        filtersStackView.translatesAutoresizingMaskIntoConstraints = false
        filtersStackView.axis = .horizontal
        filtersStackView.spacing = 8
        filtersStackView.alignment = .center
        filtersScrollView.addSubview(filtersStackView)

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
        page1.addSubview(tableView)

        applyTableGradientMask()

        let cellLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCellLongPress(_:)))
        tableView.addGestureRecognizer(cellLongPress)

        miniPlayerView = UIView()
        miniPlayerView.translatesAutoresizingMaskIntoConstraints = false
        miniPlayerView.backgroundColor = UIColor(red: 0.105, green: 0.105, blue: 0.118, alpha: 0.98)
        miniPlayerView.layer.cornerRadius = 29
        miniPlayerView.layer.borderWidth = 1
        miniPlayerView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        miniPlayerView.isUserInteractionEnabled = true

        miniPlayerView.layer.shadowColor = UIColor.black.cgColor
        miniPlayerView.layer.shadowOffset = CGSize(width: 0, height: 8)
        miniPlayerView.layer.shadowOpacity = 0.20
        miniPlayerView.layer.shadowRadius = 18
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
            titleLabel.topAnchor.constraint(equalTo: page1.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 20),

            importButton.topAnchor.constraint(equalTo: page1.safeAreaLayoutGuide.topAnchor, constant: 18),
            importButton.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -20),
            importButton.widthAnchor.constraint(equalToConstant: 40),
            importButton.heightAnchor.constraint(equalToConstant: 40),

            searchBar.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            searchBar.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -12),

            filtersScrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 6),
            filtersScrollView.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 16),
            filtersScrollView.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -16),
            filtersScrollView.heightAnchor.constraint(equalToConstant: 36),

            filtersStackView.topAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.topAnchor),
            filtersStackView.bottomAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.bottomAnchor),
            filtersStackView.leadingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.leadingAnchor),
            filtersStackView.trailingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.trailingAnchor),
            filtersStackView.heightAnchor.constraint(equalToConstant: 36),

            tableView.topAnchor.constraint(equalTo: filtersScrollView.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor, constant: -10),

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

        let centerConstraint = filtersStackView.centerXAnchor.constraint(equalTo: filtersScrollView.centerXAnchor)
        centerConstraint.priority = .defaultLow
        centerConstraint.isActive = true

        rebuildFiltersRow()
    }

    @objc func showSettingsTapped() {
        view.endEditing(true)
        scrollView.setContentOffset(.zero, animated: true)
    }

    func setupPage2NowPlaying() {
        page2.backgroundColor = .black

        // Full Edge-to-Edge Dynamic Ambient Gradient Background (Fills status bar notch & home indicator)
        playerGradientLayer = CAGradientLayer()
        playerGradientLayer.colors = [
            UIColor(red: 0.24, green: 0.08, blue: 0.08, alpha: 1.0).cgColor,
            UIColor(red: 0.07, green: 0.04, blue: 0.04, alpha: 1.0).cgColor
        ]
        playerGradientLayer.locations = [0.0, 1.0]
        page2.layer.insertSublayer(playerGradientLayer, at: 0)

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
    }

    func updateCardBorders() {
        let border = cardBorderColor().cgColor
        miniPlayerView.layer.borderColor = border
        miniCoverCard.layer.borderColor = border
        miniPlayPauseButton.layer.borderColor = border

        playerGradientLayer?.frame = page2.bounds

        progressSlider.setThumbImage(makeThumbImage(size: 10), for: .normal)
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
            self?.primaryBackgroundColor() ?? .clear
        }
        topFade.tag = 7701
        page1.addSubview(topFade)

        let bottomFade = GradientOverlayView(fromTop: false) { [weak self] in
            self?.primaryBackgroundColor() ?? .clear
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
            // Solid color for first 30% of height, then fades out to transparent
            gradient.colors = [bg.cgColor, bg.cgColor, transparentBg.cgColor]
            gradient.locations = [0.0, 0.3, 1.0]
        } else {
            // Transparent for first 70% of height, then solid color for the final 30%
            gradient.colors = [transparentBg.cgColor, bg.cgColor, bg.cgColor]
            gradient.locations = [0.0, 0.7, 1.0]
        }
    }
}

private extension UILabel {
    func letterSpacing(_ value: CGFloat) {
        guard let text else { return }
        attributedText = NSAttributedString(string: text, attributes: [.kern: value])
    }
}
