//
//  ViewController+UI.swift
//  Metal
//

import UIKit
import Darwin

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

        // Section: Experimental Build Information
        let buildSectionLabel = UILabel()
        buildSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        buildSectionLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        buildSectionLabel.textColor = secondaryTextColor()
        buildSectionLabel.text = "EXPERIMENTAL BUILD"
        buildSectionLabel.letterSpacing(1.2)
        page0.addSubview(buildSectionLabel)

        // Experimental Build Card
        let buildCard = UIView()
        buildCard.translatesAutoresizingMaskIntoConstraints = false
        buildCard.backgroundColor = cardBackgroundColor()
        buildCard.layer.cornerRadius = 18
        buildCard.layer.borderWidth = 1.0
        buildCard.layer.borderColor = cardBorderColor().cgColor
        page0.addSubview(buildCard)

        let iosRow = createSettingsInfoRow(title: "iOS Version", value: "iOS \(UIDevice.current.systemVersion)")
        buildCard.addSubview(iosRow)

        let deviceRow = createSettingsInfoRow(title: "Device Model", value: UIDevice.current.modelName)
        buildCard.addSubview(deviceRow)

        let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "27.0"
        let buildRow = createSettingsInfoRow(title: "Build", value: "Metal v\(buildVersion) (\(buildNumber)-experimental)")
        buildCard.addSubview(buildRow)

        let badgeContainer = UIView()
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.backgroundColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 0.12)
        badgeContainer.layer.cornerRadius = 9
        buildCard.addSubview(badgeContainer)

        let badgeLabel = UILabel()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
        badgeLabel.text = "● Experimental Branch • iOS 26/27 SDK"
        badgeContainer.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            buildSectionLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 28),
            buildSectionLabel.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),

            buildCard.topAnchor.constraint(equalTo: buildSectionLabel.bottomAnchor, constant: 10),
            buildCard.leadingAnchor.constraint(equalTo: page0.leadingAnchor, constant: 24),
            buildCard.trailingAnchor.constraint(equalTo: page0.trailingAnchor, constant: -24),
            buildCard.heightAnchor.constraint(equalToConstant: 160),

            iosRow.topAnchor.constraint(equalTo: buildCard.topAnchor, constant: 14),
            iosRow.leadingAnchor.constraint(equalTo: buildCard.leadingAnchor, constant: 18),
            iosRow.trailingAnchor.constraint(equalTo: buildCard.trailingAnchor, constant: -18),
            iosRow.heightAnchor.constraint(equalToConstant: 22),

            deviceRow.topAnchor.constraint(equalTo: iosRow.bottomAnchor, constant: 8),
            deviceRow.leadingAnchor.constraint(equalTo: buildCard.leadingAnchor, constant: 18),
            deviceRow.trailingAnchor.constraint(equalTo: buildCard.trailingAnchor, constant: -18),
            deviceRow.heightAnchor.constraint(equalToConstant: 22),

            buildRow.topAnchor.constraint(equalTo: deviceRow.bottomAnchor, constant: 8),
            buildRow.leadingAnchor.constraint(equalTo: buildCard.leadingAnchor, constant: 18),
            buildRow.trailingAnchor.constraint(equalTo: buildCard.trailingAnchor, constant: -18),
            buildRow.heightAnchor.constraint(equalToConstant: 22),

            badgeContainer.topAnchor.constraint(equalTo: buildRow.bottomAnchor, constant: 12),
            badgeContainer.leadingAnchor.constraint(equalTo: buildCard.leadingAnchor, constant: 18),
            badgeContainer.trailingAnchor.constraint(lessThanOrEqualTo: buildCard.trailingAnchor, constant: -18),
            badgeContainer.heightAnchor.constraint(equalToConstant: 24),

            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -10),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
        ])
    }

    func createSettingsInfoRow(title: String, value: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLbl.textColor = secondaryTextColor()
        titleLbl.text = title
        container.addSubview(titleLbl)

        let valLbl = UILabel()
        valLbl.translatesAutoresizingMaskIntoConstraints = false
        valLbl.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        valLbl.textColor = primaryTextColor()
        valLbl.text = value
        container.addSubview(valLbl)

        NSLayoutConstraint.activate([
            titleLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valLbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valLbl.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
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

    func setupPage1Library() {
        page1.backgroundColor = primaryBackgroundColor()

        // 1. Top Header Card (Panel behind header, ends halfway through searchBar with rounded bottom corners)
        headerCardView = UIView()
        headerCardView.translatesAutoresizingMaskIntoConstraints = false
        headerCardView.backgroundColor = cardBackgroundColor()
        headerCardView.layer.cornerRadius = 28
        headerCardView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        headerCardView.clipsToBounds = true
        page1.addSubview(headerCardView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 38)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = "Metal."
        page1.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont(name: "Georgia-Italic", size: 15)
        subtitleLabel.textColor = secondaryTextColor()
        subtitleLabel.text = "Your auditory shelf."
        page1.addSubview(subtitleLabel)

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

        // 2. Search Bar - Acts as physical connector/bridge between top header card and lower area
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

        // 3. Yandex Music "Моя волна" (My Wave) Card & Generative Fluid Visualizer
        myWaveCardView = UIView()
        myWaveCardView.translatesAutoresizingMaskIntoConstraints = false
        myWaveCardView.backgroundColor = cardBackgroundColor()
        myWaveCardView.layer.cornerRadius = 22
        myWaveCardView.layer.borderWidth = 1.0
        myWaveCardView.layer.borderColor = cardBorderColor().cgColor
        myWaveCardView.clipsToBounds = true
        let waveTap = UITapGestureRecognizer(target: self, action: #selector(myWaveCardTapped))
        myWaveCardView.addGestureRecognizer(waveTap)
        page1.addSubview(myWaveCardView)

        myWaveView = YandexWaveView()
        myWaveView.translatesAutoresizingMaskIntoConstraints = false
        myWaveCardView.addSubview(myWaveView)

        let waveHeaderStack = UIStackView()
        waveHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        waveHeaderStack.axis = .horizontal
        waveHeaderStack.alignment = .center
        waveHeaderStack.spacing = 10
        myWaveCardView.addSubview(waveHeaderStack)

        let waveIcon = UIImageView()
        waveIcon.translatesAutoresizingMaskIntoConstraints = false
        waveIcon.image = UIImage(systemName: "waveform.path", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        waveIcon.tintColor = primaryButtonColor()
        waveIcon.contentMode = .scaleAspectFit
        waveHeaderStack.addArrangedSubview(waveIcon)

        let waveTextStack = UIStackView()
        waveTextStack.axis = .vertical
        waveTextStack.spacing = 1
        waveHeaderStack.addArrangedSubview(waveTextStack)

        let waveTitleLabel = UILabel()
        waveTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        waveTitleLabel.textColor = primaryTextColor()
        waveTitleLabel.text = "МОЯ ВОЛНА"
        waveTitleLabel.letterSpacing(0.8)
        waveTextStack.addArrangedSubview(waveTitleLabel)

        let waveSubtitleLabel = UILabel()
        waveSubtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        waveSubtitleLabel.textColor = secondaryTextColor()
        waveSubtitleLabel.text = "Бесконечный поток под твой вайб"
        waveTextStack.addArrangedSubview(waveSubtitleLabel)

        wavePlayButton = UIButton(type: .system)
        wavePlayButton.translatesAutoresizingMaskIntoConstraints = false
        let playImg = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        wavePlayButton.setImage(playImg, for: .normal)
        wavePlayButton.tintColor = .white
        wavePlayButton.backgroundColor = primaryButtonColor()
        wavePlayButton.layer.cornerRadius = 16
        wavePlayButton.addTarget(self, action: #selector(myWaveCardTapped), for: .touchUpInside)
        myWaveCardView.addSubview(wavePlayButton)

        // 4. TableView (Songs List) - extends below wave card
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
        tableView.contentInset = UIEdgeInsets(top: 48, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 48, left: 0, bottom: 0, right: 0)
        page1.addSubview(tableView)

        applyTableGradientMask()

        let cellLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCellLongPress(_:)))
        tableView.addGestureRecognizer(cellLongPress)

        // 5. Unified Floating Pill Bar for Filters (All, Daily Mix, Favorites, etc.) - Floats ABOVE the songs list
        floatingFiltersContainer = UIView()
        floatingFiltersContainer.translatesAutoresizingMaskIntoConstraints = false
        floatingFiltersContainer.layer.cornerRadius = 19
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
        pillGlass.layer.cornerRadius = 19
        pillGlass.clipsToBounds = true
        pillGlass.isUserInteractionEnabled = false
        floatingFiltersContainer.addSubview(pillGlass)

        filtersScrollView = UIScrollView()
        filtersScrollView.translatesAutoresizingMaskIntoConstraints = false
        filtersScrollView.showsHorizontalScrollIndicator = false
        filtersScrollView.bounces = true
        filtersScrollView.layer.cornerRadius = 19
        filtersScrollView.clipsToBounds = true
        floatingFiltersContainer.addSubview(filtersScrollView)

        filtersStackView = UIStackView()
        filtersStackView.translatesAutoresizingMaskIntoConstraints = false
        filtersStackView.axis = .horizontal
        filtersStackView.spacing = 3
        filtersStackView.alignment = .center
        filtersScrollView.addSubview(filtersStackView)

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
            // Top Header Card: starts at page1.topAnchor and ends at searchBar.centerYAnchor
            headerCardView.topAnchor.constraint(equalTo: page1.topAnchor),
            headerCardView.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            headerCardView.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            headerCardView.bottomAnchor.constraint(equalTo: searchBar.centerYAnchor),

            // Header Elements inside top card
            titleLabel.topAnchor.constraint(equalTo: page1.safeAreaLayoutGuide.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 20),

            importButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            importButton.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -20),
            importButton.widthAnchor.constraint(equalToConstant: 40),
            importButton.heightAnchor.constraint(equalToConstant: 40),

            // Search Bar: sits on the bottom seam of headerCardView
            searchBar.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            searchBar.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 14),
            searchBar.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -14),
            searchBar.heightAnchor.constraint(equalToConstant: 44),

            // My Wave Card: in the open space below searchBar
            myWaveCardView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            myWaveCardView.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 16),
            myWaveCardView.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -16),
            myWaveCardView.heightAnchor.constraint(equalToConstant: 96),

            myWaveView.topAnchor.constraint(equalTo: myWaveCardView.topAnchor),
            myWaveView.leadingAnchor.constraint(equalTo: myWaveCardView.leadingAnchor),
            myWaveView.trailingAnchor.constraint(equalTo: myWaveCardView.trailingAnchor),
            myWaveView.bottomAnchor.constraint(equalTo: myWaveCardView.bottomAnchor),

            waveHeaderStack.topAnchor.constraint(equalTo: myWaveCardView.topAnchor, constant: 12),
            waveHeaderStack.leadingAnchor.constraint(equalTo: myWaveCardView.leadingAnchor, constant: 14),
            waveHeaderStack.trailingAnchor.constraint(lessThanOrEqualTo: wavePlayButton.leadingAnchor, constant: -10),
            waveIcon.widthAnchor.constraint(equalToConstant: 18),
            waveIcon.heightAnchor.constraint(equalToConstant: 18),

            wavePlayButton.centerYAnchor.constraint(equalTo: waveHeaderStack.centerYAnchor),
            wavePlayButton.trailingAnchor.constraint(equalTo: myWaveCardView.trailingAnchor, constant: -14),
            wavePlayButton.widthAnchor.constraint(equalToConstant: 32),
            wavePlayButton.heightAnchor.constraint(equalToConstant: 32),

            // TableView (Songs List): occupies space from wave card down to mini player
            tableView.topAnchor.constraint(equalTo: myWaveCardView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: page1.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: page1.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor, constant: -10),

            // Floating Filters Container: sits FLOATING right over tableView top!
            floatingFiltersContainer.topAnchor.constraint(equalTo: myWaveCardView.bottomAnchor, constant: 8),
            floatingFiltersContainer.leadingAnchor.constraint(equalTo: page1.leadingAnchor, constant: 16),
            floatingFiltersContainer.trailingAnchor.constraint(equalTo: page1.trailingAnchor, constant: -16),
            floatingFiltersContainer.heightAnchor.constraint(equalToConstant: 38),

            pillGlass.topAnchor.constraint(equalTo: floatingFiltersContainer.topAnchor),
            pillGlass.leadingAnchor.constraint(equalTo: floatingFiltersContainer.leadingAnchor),
            pillGlass.trailingAnchor.constraint(equalTo: floatingFiltersContainer.trailingAnchor),
            pillGlass.bottomAnchor.constraint(equalTo: floatingFiltersContainer.bottomAnchor),

            filtersScrollView.topAnchor.constraint(equalTo: floatingFiltersContainer.topAnchor),
            filtersScrollView.leadingAnchor.constraint(equalTo: floatingFiltersContainer.leadingAnchor, constant: 4),
            filtersScrollView.trailingAnchor.constraint(equalTo: floatingFiltersContainer.trailingAnchor, constant: -4),
            filtersScrollView.bottomAnchor.constraint(equalTo: floatingFiltersContainer.bottomAnchor),

            filtersStackView.topAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.topAnchor),
            filtersStackView.bottomAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.bottomAnchor),
            filtersStackView.leadingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.leadingAnchor),
            filtersStackView.trailingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.trailingAnchor),
            filtersStackView.heightAnchor.constraint(equalTo: filtersScrollView.heightAnchor),

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
        page2.backgroundColor = .clear

        // Full Edge-to-Edge Dynamic Ambient Gradient Background (Fills status bar notch & home indicator)
        playerGradientLayer = CAGradientLayer()
        playerGradientLayer.colors = [
            UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1.0).cgColor
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
        let border = cardBorderColor().resolvedColor(with: traitCollection).cgColor
        headerCardView?.backgroundColor = cardBackgroundColor()
        myWaveCardView?.backgroundColor = cardBackgroundColor()
        myWaveCardView?.layer.borderColor = border
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

// MARK: - Yandex Music "Моя волна" (My Wave) Generative Visualizer

class YandexWaveView: UIView {

    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0.0
    private var isPlaying: Bool = false
    private var currentAmplitudeMultiplier: CGFloat = 0.7
    private var targetAmplitudeMultiplier: CGFloat = 0.7

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        targetAmplitudeMultiplier = playing ? 1.35 : 0.65
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(updateWaveAnimation))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        stopDisplayLink()
    }

    @objc private func updateWaveAnimation() {
        let speed: CGFloat = isPlaying ? 0.038 : 0.016
        phase += speed
        if phase > .pi * 2000 { phase = 0 }

        // Smooth transition of amplitude multiplier
        currentAmplitudeMultiplier += (targetAmplitudeMultiplier - currentAmplitudeMultiplier) * 0.08

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), rect.width > 0, rect.height > 0 else { return }

        let width = rect.width
        let height = rect.height
        let baseHeight = height * 0.58
        let amp = currentAmplitudeMultiplier

        let isDark = traitCollection.userInterfaceStyle == .dark

        // Layer 1: Deep ambient violet / berry glow (background wave)
        let layer1Start = UIColor(red: 0.45, green: 0.12, blue: 0.78, alpha: isDark ? 0.45 : 0.35).cgColor
        let layer1End = UIColor(red: 0.15, green: 0.35, blue: 0.88, alpha: isDark ? 0.20 : 0.15).cgColor
        drawSingleWave(
            context: context,
            rect: rect,
            baseY: baseHeight + 4,
            amplitude1: 14.0 * amp,
            freq1: 0.012,
            speed1: 1.1,
            amplitude2: 9.0 * amp,
            freq2: 0.024,
            speed2: -0.8,
            phaseOffset: 0.0,
            startColor: layer1Start,
            endColor: layer1End,
            crestColor: UIColor(red: 0.65, green: 0.30, blue: 0.95, alpha: 0.7).cgColor
        )

        // Layer 2: Sunset orange / golden amber fluid (mid wave)
        let layer2Start = UIColor(red: 0.96, green: 0.42, blue: 0.18, alpha: isDark ? 0.65 : 0.50).cgColor
        let layer2End = UIColor(red: 0.88, green: 0.20, blue: 0.45, alpha: isDark ? 0.40 : 0.30).cgColor
        drawSingleWave(
            context: context,
            rect: rect,
            baseY: baseHeight,
            amplitude1: 18.0 * amp,
            freq1: 0.016,
            speed1: 1.5,
            amplitude2: 12.0 * amp,
            freq2: 0.032,
            speed2: -1.2,
            phaseOffset: 1.8,
            startColor: layer2Start,
            endColor: layer2End,
            crestColor: UIColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.85).cgColor
        )

        // Layer 3: Vibrant terracotta / neon crest (foreground wave)
        let layer3Start = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: isDark ? 0.85 : 0.75).cgColor
        let layer3End = UIColor(red: 1.00, green: 0.52, blue: 0.30, alpha: isDark ? 0.55 : 0.45).cgColor
        drawSingleWave(
            context: context,
            rect: rect,
            baseY: baseHeight - 4,
            amplitude1: 16.0 * amp,
            freq1: 0.020,
            speed1: 1.8,
            amplitude2: 10.0 * amp,
            freq2: 0.040,
            speed2: -1.6,
            phaseOffset: 3.4,
            startColor: layer3Start,
            endColor: layer3End,
            crestColor: UIColor.white.withAlphaComponent(0.9).cgColor
        )

        // Floating ambient light particles / vibe sparks
        drawVibeOrbs(context: context, rect: rect, amp: amp)
    }

    private func drawSingleWave(
        context: CGContext,
        rect: CGRect,
        baseY: CGFloat,
        amplitude1: CGFloat,
        freq1: CGFloat,
        speed1: CGFloat,
        amplitude2: CGFloat,
        freq2: CGFloat,
        speed2: CGFloat,
        phaseOffset: CGFloat,
        startColor: CGColor,
        endColor: CGColor,
        crestColor: CGColor
    ) {
        let width = rect.width
        let height = rect.height
        let step: CGFloat = 4.0

        let path = CGMutablePath()
        let crestPath = CGMutablePath()

        var firstPoint = true

        for x in stride(from: 0.0, through: width + step, by: step) {
            let y1 = sin(x * freq1 + phase * speed1 + phaseOffset) * amplitude1
            let y2 = cos(x * freq2 + phase * speed2 + phaseOffset * 0.7) * amplitude2
            let y = baseY + y1 + y2

            if firstPoint {
                path.move(to: CGPoint(x: x, y: y))
                crestPath.move(to: CGPoint(x: x, y: y))
                firstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
                crestPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Close path down to bottom of view
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        // Draw wave fill with gradient
        context.saveGState()
        context.addPath(path)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [startColor, endColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: baseY - amplitude1 - amplitude2),
                end: CGPoint(x: width, y: height),
                options: []
            )
        }
        context.restoreGState()

        // Stroke the glowing crest line
        context.saveGState()
        context.addPath(crestPath)
        context.setStrokeColor(crestColor)
        context.setLineWidth(1.2)
        context.strokePath()
        context.restoreGState()
    }

    private func drawVibeOrbs(context: CGContext, rect: CGRect, amp: CGFloat) {
        let width = rect.width
        let height = rect.height

        let particles: [(xFactor: CGFloat, yFactor: CGFloat, radius: CGFloat, speed: CGFloat, color: UIColor)] = [
            (0.25, 0.45, 14.0 * amp, 0.9, UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 0.25)),
            (0.60, 0.38, 18.0 * amp, 1.3, UIColor(red: 0.8, green: 0.2, blue: 0.9, alpha: 0.20)),
            (0.85, 0.52, 12.0 * amp, 0.7, UIColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 0.22))
        ]

        for p in particles {
            let dx = sin(phase * p.speed) * 16.0
            let dy = cos(phase * p.speed * 0.8) * 10.0
            let cx = width * p.xFactor + dx
            let cy = height * p.yFactor + dy
            let r = max(p.radius, 4.0)

            let orbRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            context.saveGState()
            context.setFillColor(p.color.cgColor)
            context.fillEllipse(in: orbRect)
            context.restoreGState()
        }
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

