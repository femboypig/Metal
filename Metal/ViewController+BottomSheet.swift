//
//  ViewController+BottomSheet.swift
//  Metal
//

import UIKit

extension ViewController {

    // MARK: - Custom Bottom Sheet Presentation Engine (Floating Island Capsule style)
    
    func presentCustomBottomSheet(title: String, subtitle: String? = nil, artwork: UIImage? = nil, items: [BottomSheetItem]) {
        dismissActiveSheet { [weak self] in
            guard let self = self else { return }
            self.setupAndPresentSheet(title: title, subtitle: subtitle, artwork: artwork, items: items)
        }
    }
    
    func setupAndPresentSheet(title: String, subtitle: String?, artwork: UIImage? = nil, items: [BottomSheetItem]) {
        let dimmedBg = UIView()
        dimmedBg.translatesAutoresizingMaskIntoConstraints = false
        dimmedBg.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimmedBg.alpha = 0.0
        view.addSubview(dimmedBg)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissCustomBottomSheet))
        dimmedBg.addGestureRecognizer(tap)
        
        let sheetView = UIView()
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = cardBackgroundColor()
        sheetView.layer.cornerRadius = 24
        sheetView.layer.borderWidth = 1.0
        sheetView.layer.borderColor = cardBorderColor().cgColor
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOffset = CGSize(width: 0, height: 8)
        sheetView.layer.shadowOpacity = 0.12
        sheetView.layer.shadowRadius = 14
        sheetView.clipsToBounds = false
        view.addSubview(sheetView)
        
        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill
        sheetView.addSubview(contentStack)
        
        // 1. Top Drag Handle Pill
        let handleContainer = UIView()
        handleContainer.translatesAutoresizingMaskIntoConstraints = false
        let grabber = UIView()
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.backgroundColor = cardBorderColor().withAlphaComponent(0.7)
        grabber.layer.cornerRadius = 2.5
        handleContainer.addSubview(grabber)
        contentStack.addArrangedSubview(handleContainer)
        
        NSLayoutConstraint.activate([
            handleContainer.heightAnchor.constraint(equalToConstant: 16),
            grabber.centerXAnchor.constraint(equalTo: handleContainer.centerXAnchor),
            grabber.topAnchor.constraint(equalTo: handleContainer.topAnchor, constant: 8),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5)
        ])
        
        // 2. Header (with optional artwork thumbnail)
        let titleHeader = UIView()
        titleHeader.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(titleHeader)
        
        let headerContentStack = UIStackView()
        headerContentStack.translatesAutoresizingMaskIntoConstraints = false
        headerContentStack.axis = .horizontal
        headerContentStack.spacing = 14
        headerContentStack.alignment = .center
        titleHeader.addSubview(headerContentStack)
        
        if let art = artwork ?? UIImage(named: "PlaceholderArtwork") {
            let artView = UIImageView(image: art)
            artView.translatesAutoresizingMaskIntoConstraints = false
            artView.contentMode = .scaleAspectFill
            artView.layer.cornerRadius = 10
            artView.clipsToBounds = true
            artView.layer.borderWidth = 0.5
            artView.layer.borderColor = cardBorderColor().cgColor
            headerContentStack.addArrangedSubview(artView)
            
            NSLayoutConstraint.activate([
                artView.widthAnchor.constraint(equalToConstant: 48),
                artView.heightAnchor.constraint(equalToConstant: 48)
            ])
        }
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        headerContentStack.addArrangedSubview(textStack)
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = title
        titleLabel.numberOfLines = 1
        textStack.addArrangedSubview(titleLabel)
        
        if let sub = subtitle {
            let subLabel = UILabel()
            subLabel.font = UIFont(name: "Georgia-Italic", size: 12) ?? .italicSystemFont(ofSize: 12)
            subLabel.textColor = secondaryTextColor()
            subLabel.text = sub
            subLabel.numberOfLines = 1
            textStack.addArrangedSubview(subLabel)
        }
        
        NSLayoutConstraint.activate([
            headerContentStack.topAnchor.constraint(equalTo: titleHeader.topAnchor, constant: 6),
            headerContentStack.leadingAnchor.constraint(equalTo: titleHeader.leadingAnchor, constant: 20),
            headerContentStack.trailingAnchor.constraint(equalTo: titleHeader.trailingAnchor, constant: -20),
            headerContentStack.bottomAnchor.constraint(equalTo: titleHeader.bottomAnchor, constant: -14)
        ])
        
        let headerDivider = UIView()
        headerDivider.backgroundColor = cardBorderColor()
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(headerDivider)
        headerDivider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        
        // 3. Action Items
        for (index, item) in items.enumerated() {
            let btnContainer = UIView()
            btnContainer.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview(btnContainer)
            
            let btn = UIButton(type: .custom)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btnContainer.addSubview(btn)
            
            let elementStack = UIStackView()
            elementStack.translatesAutoresizingMaskIntoConstraints = false
            elementStack.axis = .horizontal
            elementStack.spacing = 14
            elementStack.alignment = .center
            elementStack.distribution = .fill
            elementStack.isUserInteractionEnabled = false
            btn.addSubview(elementStack)
            
            // Icon Pill Container
            let iconBox = UIView()
            iconBox.translatesAutoresizingMaskIntoConstraints = false
            iconBox.layer.cornerRadius = 9
            iconBox.backgroundColor = item.isDestructive
                ? UIColor.systemRed.withAlphaComponent(0.12)
                : cardBorderColor().withAlphaComponent(0.4)
            elementStack.addArrangedSubview(iconBox)
            
            let icon = UIImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.contentMode = .scaleAspectFit
            icon.tintColor = item.isDestructive ? .systemRed : primaryTextColor()
            icon.image = UIImage(systemName: item.iconName)
            iconBox.addSubview(icon)
            
            NSLayoutConstraint.activate([
                iconBox.widthAnchor.constraint(equalToConstant: 32),
                iconBox.heightAnchor.constraint(equalToConstant: 32),
                icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16)
            ])
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont(name: "Georgia-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
            label.textColor = item.isDestructive ? .systemRed : primaryTextColor()
            label.text = item.title
            label.textAlignment = .left
            elementStack.addArrangedSubview(label)
            
            if !item.isDestructive {
                let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
                chevron.translatesAutoresizingMaskIntoConstraints = false
                chevron.contentMode = .scaleAspectFit
                chevron.tintColor = secondaryTextColor().withAlphaComponent(0.4)
                chevron.setContentHuggingPriority(.required, for: .horizontal)
                elementStack.addArrangedSubview(chevron)
            }
            
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: btnContainer.topAnchor),
                btn.bottomAnchor.constraint(equalTo: btnContainer.bottomAnchor),
                btn.leadingAnchor.constraint(equalTo: btnContainer.leadingAnchor),
                btn.trailingAnchor.constraint(equalTo: btnContainer.trailingAnchor),
                btn.heightAnchor.constraint(equalToConstant: 52),
                
                elementStack.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 20),
                elementStack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -20),
                elementStack.topAnchor.constraint(equalTo: btn.topAnchor),
                elementStack.bottomAnchor.constraint(equalTo: btn.bottomAnchor)
            ])
            
            btn.addTarget(self, action: #selector(bottomSheetItemTapped(_:)), for: .touchUpInside)
            objc_setAssociatedObject(btn, &ViewController.categoryAssociationKey, item, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            if index < items.count - 1 {
                let div = UIView()
                div.backgroundColor = cardBorderColor()
                div.translatesAutoresizingMaskIntoConstraints = false
                contentStack.addArrangedSubview(div)
                div.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            }
        }
        
        self.activeDimmedBg = dimmedBg
        self.activeSheetView = sheetView
        
        self.activeSheetBottomConstraint = sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 500)
        
        NSLayoutConstraint.activate([
            dimmedBg.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            self.activeSheetBottomConstraint!,
            
            contentStack.topAnchor.constraint(equalTo: sheetView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor, constant: -8)
        ])
        
        view.layoutIfNeeded()
        
        self.activeSheetBottomConstraint?.constant = -16
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5, options: [], animations: {
            dimmedBg.alpha = 1.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc func bottomSheetItemTapped(_ sender: UIButton) {
        guard let item = objc_getAssociatedObject(sender, &ViewController.categoryAssociationKey) as? BottomSheetItem else { return }
        dismissActiveSheet {
            item.action()
        }
    }
    
    // MARK: - Custom Context Menus (Track & Playlist)
    
    func presentTrackContextMenu(for track: Track, at index: Int, isPlayer: Bool = false) {
        var items: [BottomSheetItem] = []
        
        let isCurrent = (audioPlayer != nil && audioPlayer?.url == track.url && audioPlayer?.isPlaying == true)
        if !isPlayer {
            let playTitle = isCurrent ? "Pause" : "Play Now"
            let playIcon = isCurrent ? "pause.fill" : "play.fill"
            items.append(BottomSheetItem(title: playTitle, iconName: playIcon, isDestructive: false, action: { [weak self] in
                guard let self = self else { return }
                if isCurrent {
                    self.playPauseTapped()
                } else if index < self.filteredTracks.count {
                    let indexPath = IndexPath(row: index, section: 0)
                    self.tableView(self.tableView, didSelectRowAt: indexPath)
                }
            }))
        }
        
        items.append(BottomSheetItem(title: "Add to Playlist", iconName: "plus.circle", isDestructive: false, action: { [weak self] in
            self?.showAddToPlaylistSelector(track: track)
        }))
        
        items.append(BottomSheetItem(title: "Share Song", iconName: "square.and.arrow.up", isDestructive: false, action: { [weak self] in
            self?.shareTrack(track)
        }))
        
        items.append(BottomSheetItem(title: "Sleep Timer", iconName: "timer", isDestructive: false, action: { [weak self] in
            self?.showSleepTimerSelector()
        }))
        
        if case .playlist(let playlistName) = activeFilter {
            items.append(BottomSheetItem(title: "Remove from \(playlistName)", iconName: "minus.circle", isDestructive: true, action: { [weak self] in
                self?.removeFromPlaylist(track: track, name: playlistName)
            }))
        }
        
        items.append(BottomSheetItem(title: "Delete Song", iconName: "trash", isDestructive: true, action: { [weak self] in
            self?.deleteTrack(at: index)
        }))
        
        presentCustomBottomSheet(title: track.title, subtitle: track.artist, artwork: track.artwork, items: items)
    }
    
    func presentPlaylistContextMenu(name: String) {
        let count = playlists[name]?.count ?? 0
        let items = [
            BottomSheetItem(title: "Play Playlist", iconName: "play.fill", isDestructive: false, action: { [weak self] in
                guard let self = self else { return }
                self.activeFilter = .playlist(name)
                self.filterTracks()
                self.rebuildFiltersRow()
                if !self.filteredTracks.isEmpty {
                    self.playbackQueue = self.filteredTracks
                    self.currentPlaybackContext = name.uppercased()
                    self.currentTrackIndex = 0
                    self.playCurrentTrack()
                }
            }),
            BottomSheetItem(title: "Delete Playlist", iconName: "trash", isDestructive: true, action: { [weak self] in
                self?.deletePlaylist(named: name)
            })
        ]
        presentCustomBottomSheet(title: name, subtitle: "\(count) songs", artwork: nil, items: items)
    }
    
    
    func shareTrack(_ track: Track) {
        let shareVC = UIActivityViewController(activityItems: [track.url], applicationActivities: nil)
        present(shareVC, animated: true)
    }
    
    @objc func optionsTapped() {
        guard let index = currentTrackIndex, index < filteredTracks.count else { return }
        let track = filteredTracks[index]
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        presentTrackContextMenu(for: track, at: index, isPlayer: true)
    }
    
    // MARK: - Dedicated Up Next Queue Sheet
    
    func presentQueueSheet() {
        dismissActiveSheet { [weak self] in
            guard let self = self else { return }
            self.setupAndPresentQueueSheet()
        }
    }
    
    private func setupAndPresentQueueSheet() {
        let queue = currentQueue
        let dimmedBg = UIView()
        dimmedBg.translatesAutoresizingMaskIntoConstraints = false
        dimmedBg.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimmedBg.alpha = 0.0
        view.addSubview(dimmedBg)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissCustomBottomSheet))
        dimmedBg.addGestureRecognizer(tap)
        
        let sheetView = UIView()
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = cardBackgroundColor()
        sheetView.layer.cornerRadius = 24
        sheetView.layer.borderWidth = 1.0
        sheetView.layer.borderColor = cardBorderColor().cgColor
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOffset = CGSize(width: 0, height: 8)
        sheetView.layer.shadowOpacity = 0.12
        sheetView.layer.shadowRadius = 14
        sheetView.clipsToBounds = false
        view.addSubview(sheetView)
        
        // Grabber
        let grabber = UIView()
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.backgroundColor = cardBorderColor().withAlphaComponent(0.7)
        grabber.layer.cornerRadius = 2.5
        sheetView.addSubview(grabber)
        
        // Header
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = "Up Next Queue"
        sheetView.addSubview(titleLabel)
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = UIFont(name: "Georgia-Italic", size: 12) ?? .italicSystemFont(ofSize: 12)
        subLabel.textColor = secondaryTextColor()
        subLabel.text = "\(queue.count) songs in queue"
        sheetView.addSubview(subLabel)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        closeBtn.tintColor = secondaryTextColor().withAlphaComponent(0.7)
        closeBtn.addTarget(self, action: #selector(dismissCustomBottomSheet), for: .touchUpInside)
        sheetView.addSubview(closeBtn)
        
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = cardBorderColor()
        sheetView.addSubview(divider)
        
        // Queue Table View
        let queueTable = UITableView()
        queueTable.translatesAutoresizingMaskIntoConstraints = false
        queueTable.backgroundColor = .clear
        queueTable.separatorStyle = .none
        queueTable.showsVerticalScrollIndicator = true
        sheetView.addSubview(queueTable)
        
        let dataSource = QueueSheetDataSource(parent: self, queue: queue) { [weak self] track, index in
            guard let self = self else { return }
            self.recordManualSelection(for: track)
            self.currentTrackIndex = index
            self.playCurrentTrack()
            self.dismissActiveSheet()
        }
        queueTable.dataSource = dataSource
        queueTable.delegate = dataSource
        objc_setAssociatedObject(queueTable, &ViewController.categoryAssociationKey, dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Scroll to currently playing row if possible
        if let currentIdx = currentTrackIndex, currentIdx < queue.count {
            DispatchQueue.main.async {
                queueTable.scrollToRow(at: IndexPath(row: currentIdx, section: 0), at: .middle, animated: false)
            }
        }
        
        let tableHeight: CGFloat = min(440, max(200, CGFloat(queue.count) * 56))
        
        self.activeDimmedBg = dimmedBg
        self.activeSheetView = sheetView
        self.activeSheetBottomConstraint = sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 600)
        
        NSLayoutConstraint.activate([
            dimmedBg.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            self.activeSheetBottomConstraint!,
            
            grabber.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            grabber.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 8),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            
            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),
            
            divider.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            
            queueTable.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            queueTable.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            queueTable.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            queueTable.heightAnchor.constraint(equalToConstant: tableHeight),
            queueTable.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor, constant: -16)
        ])
        
        view.layoutIfNeeded()
        
        self.activeSheetBottomConstraint?.constant = -16
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5, options: [], animations: {
            dimmedBg.alpha = 1.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    // MARK: - Custom Modal TextInput Sheet Presentation (Floating Island Capsule style)
    
    func presentCustomInputSheet(title: String, placeholder: String, submitTitle: String, onSubmit: @escaping (String) -> Void) {
        dismissActiveSheet { [weak self] in
            guard let self = self else { return }
            self.setupAndPresentInputSheet(title: title, placeholder: placeholder, submitTitle: submitTitle, onSubmit: onSubmit)
        }
    }
    
    func setupAndPresentInputSheet(title: String, placeholder: String, submitTitle: String, onSubmit: @escaping (String) -> Void) {
        let dimmedBg = UIView()
        dimmedBg.translatesAutoresizingMaskIntoConstraints = false
        dimmedBg.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimmedBg.alpha = 0.0
        view.addSubview(dimmedBg)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissCustomBottomSheet))
        dimmedBg.addGestureRecognizer(tap)
        
        let sheetView = UIView()
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = cardBackgroundColor()
        sheetView.layer.cornerRadius = 24
        sheetView.layer.borderWidth = 1.0
        sheetView.layer.borderColor = cardBorderColor().cgColor
        
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOffset = CGSize(width: 0, height: 8)
        sheetView.layer.shadowOpacity = 0.12
        sheetView.layer.shadowRadius = 14
        sheetView.clipsToBounds = false
        view.addSubview(sheetView)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = title
        titleLabel.textAlignment = .left
        sheetView.addSubview(titleLabel)
        
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.backgroundColor = primaryBackgroundColor()
        textField.textColor = primaryTextColor()
        textField.font = UIFont(name: "Georgia-Italic", size: 15) ?? .italicSystemFont(ofSize: 15)
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = cardBorderColor().cgColor
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        sheetView.addSubview(textField)
        
        let buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        sheetView.addSubview(buttonStack)
        
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        cancelBtn.setTitleColor(secondaryTextColor(), for: .normal)
        cancelBtn.layer.cornerRadius = 14
        cancelBtn.layer.borderWidth = 1.0
        cancelBtn.layer.borderColor = cardBorderColor().cgColor
        cancelBtn.addTarget(self, action: #selector(dismissCustomBottomSheet), for: .touchUpInside)
        buttonStack.addArrangedSubview(cancelBtn)
        
        let submitBtn = UIButton(type: .custom)
        submitBtn.setTitle(submitTitle, for: .normal)
        submitBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        submitBtn.setTitleColor(primaryButtonTextColor(), for: .normal)
        submitBtn.backgroundColor = primaryButtonColor()
        submitBtn.layer.cornerRadius = 14
        buttonStack.addArrangedSubview(submitBtn)
        
        let wrapper = InputSubmitWrapper(onSubmit)
        objc_setAssociatedObject(submitBtn, &ViewController.categoryAssociationKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(submitBtn, &ViewController.textAssociationKey, textField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        submitBtn.addTarget(self, action: #selector(customInputSubmitted(_:)), for: .touchUpInside)
        
        self.activeDimmedBg = dimmedBg
        self.activeSheetView = sheetView
        self.activeSheetBottomConstraint = sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 450)
        
        NSLayoutConstraint.activate([
            dimmedBg.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            self.activeSheetBottomConstraint!,
            
            titleLabel.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            textField.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            textField.heightAnchor.constraint(equalToConstant: 44),
            
            buttonStack.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 16),
            buttonStack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),
            buttonStack.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor, constant: -20)
        ])
        
        view.layoutIfNeeded()
        
        self.activeSheetBottomConstraint?.constant = -16
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: [], animations: {
            dimmedBg.alpha = 1.0
            self.view.layoutIfNeeded()
        }) { _ in
            textField.becomeFirstResponder()
        }
    }
    
    @objc func customInputSubmitted(_ sender: UIButton) {
        guard let wrapper = objc_getAssociatedObject(sender, &ViewController.categoryAssociationKey) as? InputSubmitWrapper,
              let textField = objc_getAssociatedObject(sender, &ViewController.textAssociationKey) as? UITextField,
              let text = textField.text, !text.isEmpty else { return }
        
        dismissActiveSheet {
            wrapper.action(text)
        }
    }
    
    func dismissActiveSheet(completion: (() -> Void)? = nil) {
        guard let bg = activeDimmedBg, let sheet = activeSheetView else {
            completion?()
            return
        }
        
        activeSheetBottomConstraint?.constant = 650
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseIn, animations: {
            bg.alpha = 0.0
            self.view.layoutIfNeeded()
        }) { _ in
            bg.removeFromSuperview()
            sheet.removeFromSuperview()
            self.activeDimmedBg = nil
            self.activeSheetView = nil
            self.activeSheetBottomConstraint = nil
            completion?()
        }
    }
    
    @objc func dismissCustomBottomSheet() {
        dismissActiveSheet()
    }
    
    func showAddToPlaylistSelector(track: Track) {
        if playlists.isEmpty {
            presentCustomInputSheet(title: "New Playlist", placeholder: "Playlist Name", submitTitle: "Create") { [weak self] name in
                self?.playlists[name] = [track.url.lastPathComponent]
                self?.savePlaylists()
                self?.rebuildFiltersRow()
                self?.showToast(message: "Created and added to \(name)", success: true)
            }
            return
        }
        
        var items = [BottomSheetItem]()
        for name in playlists.keys.sorted() {
            items.append(BottomSheetItem(title: name, iconName: "music.note.list", isDestructive: false, action: { [weak self] in
                var list = self?.playlists[name] ?? []
                let filename = track.url.lastPathComponent
                if !list.contains(filename) {
                    list.append(filename)
                    self?.playlists[name] = list
                    self?.savePlaylists()
                    self?.showToast(message: "Added to \(name)", success: true)
                } else {
                    self?.showToast(message: "Already in \(name)", success: false)
                }
            }))
        }
        
        items.append(BottomSheetItem(title: "New Playlist...", iconName: "plus", isDestructive: false, action: { [weak self] in
            self?.presentCustomInputSheet(title: "New Playlist", placeholder: "Playlist Name", submitTitle: "Create") { [weak self] name in
                self?.playlists[name] = [track.url.lastPathComponent]
                self?.savePlaylists()
                self?.rebuildFiltersRow()
                self?.showToast(message: "Created and added to \(name)", success: true)
            }
        }))
        
        presentCustomBottomSheet(title: "Add to Playlist", subtitle: track.title, artwork: track.artwork, items: items)
    }
    
    // MARK: - Circular Sleep Timer
    
    func showSleepTimerSelector() {
        presentCircularSleepTimerSheet()
    }
    
    func showCustomSleepTimerPrompt() {
        presentCircularSleepTimerSheet()
    }
    
    func presentCircularSleepTimerSheet() {
        dismissActiveSheet { [weak self] in
            guard let self = self else { return }
            self.setupAndPresentCircularSleepTimerSheet()
        }
    }
    
    private func setupAndPresentCircularSleepTimerSheet() {
        let dimmedBg = UIView()
        dimmedBg.translatesAutoresizingMaskIntoConstraints = false
        dimmedBg.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimmedBg.alpha = 0.0
        view.addSubview(dimmedBg)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissCustomBottomSheet))
        dimmedBg.addGestureRecognizer(tap)
        
        let sheetView = UIView()
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = cardBackgroundColor()
        sheetView.layer.cornerRadius = 24
        sheetView.layer.borderWidth = 1.0
        sheetView.layer.borderColor = cardBorderColor().cgColor
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOffset = CGSize(width: 0, height: 8)
        sheetView.layer.shadowOpacity = 0.12
        sheetView.layer.shadowRadius = 14
        sheetView.clipsToBounds = false
        view.addSubview(sheetView)
        
        // Grabber
        let grabber = UIView()
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.backgroundColor = cardBorderColor().withAlphaComponent(0.7)
        grabber.layer.cornerRadius = 2.5
        sheetView.addSubview(grabber)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleLabel.textColor = primaryTextColor()
        titleLabel.text = "Sleep Timer"
        sheetView.addSubview(titleLabel)
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = UIFont(name: "Georgia-Italic", size: 13) ?? .italicSystemFont(ofSize: 13)
        subLabel.textColor = secondaryTextColor()
        subLabel.text = "Rotate the dial to set sleep timer"
        sheetView.addSubview(subLabel)
        
        // Mode Selector: Custom Pill Bar
        let modeContainer = UIView()
        modeContainer.translatesAutoresizingMaskIntoConstraints = false
        modeContainer.backgroundColor = cardBorderColor().withAlphaComponent(0.4)
        modeContainer.layer.cornerRadius = 16
        sheetView.addSubview(modeContainer)
        
        let minBtn = UIButton(type: .custom)
        minBtn.translatesAutoresizingMaskIntoConstraints = false
        minBtn.setTitle("Minutes", for: .normal)
        minBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        minBtn.setTitleColor(primaryButtonTextColor(), for: .normal)
        minBtn.backgroundColor = primaryButtonColor()
        minBtn.layer.cornerRadius = 14
        modeContainer.addSubview(minBtn)
        
        let hrBtn = UIButton(type: .custom)
        hrBtn.translatesAutoresizingMaskIntoConstraints = false
        hrBtn.setTitle("Hours", for: .normal)
        hrBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        hrBtn.setTitleColor(secondaryTextColor(), for: .normal)
        hrBtn.backgroundColor = .clear
        hrBtn.layer.cornerRadius = 14
        modeContainer.addSubview(hrBtn)
        
        NSLayoutConstraint.activate([
            modeContainer.widthAnchor.constraint(equalToConstant: 180),
            modeContainer.heightAnchor.constraint(equalToConstant: 34),
            
            minBtn.leadingAnchor.constraint(equalTo: modeContainer.leadingAnchor, constant: 2),
            minBtn.topAnchor.constraint(equalTo: modeContainer.topAnchor, constant: 2),
            minBtn.bottomAnchor.constraint(equalTo: modeContainer.bottomAnchor, constant: -2),
            minBtn.widthAnchor.constraint(equalToConstant: 86),
            
            hrBtn.trailingAnchor.constraint(equalTo: modeContainer.trailingAnchor, constant: -2),
            hrBtn.topAnchor.constraint(equalTo: modeContainer.topAnchor, constant: 2),
            hrBtn.bottomAnchor.constraint(equalTo: modeContainer.bottomAnchor, constant: -2),
            hrBtn.widthAnchor.constraint(equalToConstant: 86)
        ])
        
        // Circular Dial
        let dial = CircularTimerDialView()
        dial.translatesAutoresizingMaskIntoConstraints = false
        dial.trackColor = cardBorderColor()
        dial.progressColor = primaryButtonColor()
        dial.textColor = primaryTextColor()
        dial.subtitleColor = secondaryTextColor()
        sheetView.addSubview(dial)
        
        let updateModeUI: (CircularTimerDialView.Mode) -> Void = { mode in
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
            dial.mode = mode
            if mode == .minutes {
                minBtn.backgroundColor = self.primaryButtonColor()
                minBtn.setTitleColor(self.primaryButtonTextColor(), for: .normal)
                hrBtn.backgroundColor = .clear
                hrBtn.setTitleColor(self.secondaryTextColor(), for: .normal)
            } else {
                hrBtn.backgroundColor = self.primaryButtonColor()
                hrBtn.setTitleColor(self.primaryButtonTextColor(), for: .normal)
                minBtn.backgroundColor = .clear
                minBtn.setTitleColor(self.secondaryTextColor(), for: .normal)
            }
        }
        
        minBtn.addAction(UIAction { _ in updateModeUI(.minutes) }, for: .touchUpInside)
        hrBtn.addAction(UIAction { _ in updateModeUI(.hours) }, for: .touchUpInside)
        
        if let endDate = sleepTimerEndDate, endDate > Date() {
            let remaining = max(5.0, ceil(endDate.timeIntervalSinceNow / 60.0))
            dial.setDuration(minutes: remaining)
            if remaining > 60.0 {
                updateModeUI(.hours)
            }
        }
        
        // Preset Chips
        let chipsStack = UIStackView()
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.axis = .horizontal
        chipsStack.spacing = 8
        chipsStack.distribution = .fillEqually
        sheetView.addSubview(chipsStack)
        
        let presets: [(String, Double, CircularTimerDialView.Mode)] = [
            ("15m", 15.0, .minutes),
            ("30m", 30.0, .minutes),
            ("45m", 45.0, .minutes),
            ("1h", 60.0, .minutes),
            ("2h", 120.0, .hours)
        ]
        
        for (name, val, targetMode) in presets {
            let chip = UIButton(type: .system)
            chip.setTitle(name, for: .normal)
            chip.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
            chip.setTitleColor(primaryTextColor(), for: .normal)
            chip.backgroundColor = primaryBackgroundColor()
            chip.layer.cornerRadius = 10
            chip.layer.borderWidth = 1.0
            chip.layer.borderColor = cardBorderColor().cgColor
            chip.addAction(UIAction { _ in
                updateModeUI(targetMode)
                dial.setDuration(minutes: val)
            }, for: .touchUpInside)
            chipsStack.addArrangedSubview(chip)
        }
        
        var statusBadge: UIView?
        if let endDate = sleepTimerEndDate, endDate > Date() {
            let remaining = Int(ceil(endDate.timeIntervalSinceNow / 60.0))
            let badge = UIView()
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.backgroundColor = primaryButtonColor().withAlphaComponent(0.12)
            badge.layer.cornerRadius = 10
            sheetView.addSubview(badge)
            
            let badgeLabel = UILabel()
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.font = UIFont(name: "Georgia-BoldItalic", size: 12) ?? .boldSystemFont(ofSize: 12)
            badgeLabel.textColor = primaryButtonColor()
            badgeLabel.text = "⏱ Active timer: \(remaining)m remaining"
            badge.addSubview(badgeLabel)
            
            NSLayoutConstraint.activate([
                badgeLabel.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
                badgeLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
                badge.heightAnchor.constraint(equalToConstant: 28),
                badge.leadingAnchor.constraint(greaterThanOrEqualTo: sheetView.leadingAnchor, constant: 20),
                badge.trailingAnchor.constraint(lessThanOrEqualTo: sheetView.trailingAnchor, constant: -20),
                badge.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor)
            ])
            statusBadge = badge
        }
        
        let buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 8
        buttonStack.distribution = .fill
        sheetView.addSubview(buttonStack)
        
        let submitBtn = UIButton(type: .custom)
        submitBtn.translatesAutoresizingMaskIntoConstraints = false
        submitBtn.setTitle("Start Sleep Timer", for: .normal)
        submitBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
        submitBtn.setTitleColor(primaryButtonTextColor(), for: .normal)
        submitBtn.backgroundColor = primaryButtonColor()
        submitBtn.layer.cornerRadius = 14
        submitBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        submitBtn.addAction(UIAction { [weak self] _ in
            self?.dismissActiveSheet {
                self?.startSleepTimer(minutes: dial.durationMinutes)
            }
        }, for: .touchUpInside)
        buttonStack.addArrangedSubview(submitBtn)
        
        if sleepTimer != nil {
            let cancelTimerBtn = UIButton(type: .system)
            cancelTimerBtn.translatesAutoresizingMaskIntoConstraints = false
            cancelTimerBtn.setTitle("Cancel Active Timer", for: .normal)
            cancelTimerBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
            cancelTimerBtn.setTitleColor(.systemRed, for: .normal)
            cancelTimerBtn.layer.cornerRadius = 14
            cancelTimerBtn.layer.borderWidth = 1.0
            cancelTimerBtn.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
            cancelTimerBtn.heightAnchor.constraint(equalToConstant: 42).isActive = true
            cancelTimerBtn.addAction(UIAction { [weak self] _ in
                self?.dismissActiveSheet {
                    self?.cancelSleepTimer()
                }
            }, for: .touchUpInside)
            buttonStack.addArrangedSubview(cancelTimerBtn)
        }
        
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setTitle("Close", for: .normal)
        closeBtn.titleLabel?.font = UIFont(name: "Georgia-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        closeBtn.setTitleColor(secondaryTextColor(), for: .normal)
        closeBtn.heightAnchor.constraint(equalToConstant: 38).isActive = true
        closeBtn.addAction(UIAction { [weak self] _ in
            self?.dismissActiveSheet()
        }, for: .touchUpInside)
        buttonStack.addArrangedSubview(closeBtn)
        
        self.activeDimmedBg = dimmedBg
        self.activeSheetView = sheetView
        self.activeSheetBottomConstraint = sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 650)
        
        var layoutConstraints: [NSLayoutConstraint] = [
            dimmedBg.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedBg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedBg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedBg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            self.activeSheetBottomConstraint!,
            
            grabber.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            grabber.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 8),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            subLabel.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            
            modeContainer.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 14),
            modeContainer.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            
            dial.topAnchor.constraint(equalTo: modeContainer.bottomAnchor, constant: 12),
            dial.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            dial.widthAnchor.constraint(equalToConstant: 220),
            dial.heightAnchor.constraint(equalToConstant: 220),
            
            chipsStack.topAnchor.constraint(equalTo: dial.bottomAnchor, constant: 10),
            chipsStack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            chipsStack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            chipsStack.heightAnchor.constraint(equalToConstant: 34)
        ]
        
        if let badge = statusBadge {
            layoutConstraints.append(contentsOf: [
                badge.topAnchor.constraint(equalTo: chipsStack.bottomAnchor, constant: 10),
                buttonStack.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 14)
            ])
        } else {
            layoutConstraints.append(
                buttonStack.topAnchor.constraint(equalTo: chipsStack.bottomAnchor, constant: 16)
            )
        }
        
        layoutConstraints.append(contentsOf: [
            buttonStack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor, constant: -18)
        ])
        
        NSLayoutConstraint.activate(layoutConstraints)
        view.layoutIfNeeded()
        
        self.activeSheetBottomConstraint?.constant = -16
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5, options: [], animations: {
            dimmedBg.alpha = 1.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func startSleepTimer(minutes: Double) {
        sleepTimer?.invalidate()
        sleepTimerEndDate = Date().addingTimeInterval(minutes * 60)
        let seconds = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.stopPlaybackDueToSleepTimer()
        }
        
        let message: String
        if minutes < 60 {
            message = "Sleep timer set for \(Int(minutes)) minutes"
        } else if Int(minutes) % 60 == 0 {
            let hours = Int(minutes / 60)
            message = "Sleep timer set for \(hours) \(hours == 1 ? "hour" : "hours")"
        } else {
            let hours = Int(minutes) / 60
            let remainderMins = Int(minutes) % 60
            message = "Sleep timer set for \(hours)h \(remainderMins)m"
        }
        showToast(message: message, success: true)
    }
    
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
        showToast(message: "Sleep timer cancelled", success: true)
    }
    
    func stopPlaybackDueToSleepTimer() {
        guard let player = audioPlayer, player.isPlaying else {
            sleepTimer = nil
            sleepTimerEndDate = nil
            return
        }
        
        let initialVolume = player.volume
        var currentFadeStep = 0
        let totalSteps = 20
        let interval = 0.25 // 5 seconds total fade out
        
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentFadeStep += 1
            let progress = Float(totalSteps - currentFadeStep) / Float(totalSteps)
            player.volume = initialVolume * progress
            
            if currentFadeStep >= totalSteps {
                timer.invalidate()
                player.pause()
                player.volume = initialVolume // Restore volume
                
                self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 52, weight: .bold)), for: .normal)
                self.stopArtworkAnimation()
                self.updateNowPlayingInfo()
                self.updateMiniPlayerUI()
                self.sleepTimer = nil
                self.sleepTimerEndDate = nil
            }
        }
    }
}

// MARK: - Queue Sheet Data Source Helper

private class QueueSheetDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var parent: ViewController?
    let queue: [Track]
    let onSelect: (Track, Int) -> Void
    
    init(parent: ViewController, queue: [Track], onSelect: @escaping (Track, Int) -> Void) {
        self.parent = parent
        self.queue = queue
        self.onSelect = onSelect
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return queue.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QueueCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "QueueCell")
        let track = queue[indexPath.row]
        let isPlaying = (parent?.audioPlayer != nil && parent?.audioPlayer?.url == track.url)
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        cell.textLabel?.font = UIFont(name: "Georgia-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        cell.textLabel?.textColor = isPlaying ? (parent?.primaryButtonColor() ?? .systemOrange) : (parent?.primaryTextColor() ?? .white)
        cell.textLabel?.text = track.title
        
        cell.detailTextLabel?.font = UIFont(name: "Georgia-Italic", size: 12) ?? .italicSystemFont(ofSize: 12)
        cell.detailTextLabel?.textColor = parent?.secondaryTextColor() ?? .gray
        cell.detailTextLabel?.text = track.artist != "Unknown Artist" ? track.artist : ""
        
        let artwork = track.artwork ?? UIImage(named: "PlaceholderArtwork")
        cell.imageView?.image = artwork
        cell.imageView?.layer.cornerRadius = 6
        cell.imageView?.clipsToBounds = true
        
        if isPlaying {
            let indicator = UIImageView(image: UIImage(systemName: "waveform", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)))
            indicator.tintColor = parent?.primaryButtonColor() ?? .systemOrange
            cell.accessoryView = indicator
        } else {
            let durLabel = UILabel()
            durLabel.font = UIFont(name: "Georgia-Italic", size: 12) ?? .italicSystemFont(ofSize: 12)
            durLabel.textColor = parent?.secondaryTextColor() ?? .gray
            durLabel.text = parent?.formatTime(track.duration) ?? ""
            durLabel.sizeToFit()
            cell.accessoryView = durLabel
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let track = queue[indexPath.row]
        onSelect(track, indexPath.row)
    }
}

// MARK: - Circular Sleep Timer Dial View

class CircularTimerDialView: UIControl {
    enum Mode {
        case minutes
        case hours
    }
    
    var mode: Mode = .minutes {
        didSet {
            syncAngleFromDuration()
            updateDisplay()
            setNeedsDisplay()
        }
    }
    
    private(set) var durationMinutes: Double = 30.0
    var onDurationChanged: ((Double) -> Void)?
    
    private var angle: CGFloat = .pi
    private let feedback = UISelectionFeedbackGenerator()
    
    var trackColor: UIColor = UIColor.white.withAlphaComponent(0.12)
    var progressColor: UIColor = UIColor(red: 0.85, green: 0.36, blue: 0.22, alpha: 1.0)
    var textColor: UIColor = .white
    var subtitleColor: UIColor = UIColor.white.withAlphaComponent(0.6)
    
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont(name: "Georgia-Bold", size: 44) ?? UIFont.systemFont(ofSize: 44, weight: .bold)
        valueLabel.textAlignment = .center
        addSubview(valueLabel)
        
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.font = UIFont(name: "Georgia-Italic", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .medium)
        unitLabel.textAlignment = .center
        addSubview(unitLabel)
        
        NSLayoutConstraint.activate([
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            
            unitLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            unitLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        syncAngleFromDuration()
        updateDisplay()
    }
    
    func setDuration(minutes: Double) {
        durationMinutes = max(5.0, minutes)
        if durationMinutes > 60.0 && mode != .hours {
            mode = .hours
        } else {
            syncAngleFromDuration()
            updateDisplay()
            setNeedsDisplay()
        }
    }
    
    private func syncAngleFromDuration() {
        switch mode {
        case .minutes:
            let clamped = min(60.0, max(5.0, durationMinutes))
            angle = CGFloat(clamped / 60.0) * 2 * .pi
        case .hours:
            let hours = min(12.0, max(0.5, durationMinutes / 60.0))
            angle = CGFloat(hours / 12.0) * 2 * .pi
        }
    }
    
    private func updateDisplay() {
        valueLabel.textColor = textColor
        unitLabel.textColor = subtitleColor
        
        switch mode {
        case .minutes:
            valueLabel.text = "\(Int(durationMinutes))"
            unitLabel.text = "MINUTES"
        case .hours:
            let hours = durationMinutes / 60.0
            if hours == floor(hours) {
                valueLabel.text = "\(Int(hours))"
                unitLabel.text = hours == 1 ? "HOUR" : "HOURS"
            } else {
                valueLabel.text = String(format: "%.1f", hours)
                unitLabel.text = "HOURS"
            }
        }
    }
    
    // MARK: - Touch Tracking
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        feedback.prepare()
        handleTouch(touch)
        return true
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        handleTouch(touch)
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let touch = touch {
            handleTouch(touch)
        }
        sendActions(for: .valueChanged)
    }
    
    private func handleTouch(_ touch: UITouch) {
        let loc = touch.location(in: self)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = loc.x - center.x
        let dy = loc.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 24 else { return }
        
        var rad = atan2(dy, dx) + .pi / 2
        if rad < 0 { rad += 2 * .pi }
        
        let fraction = min(max(rad / (2 * .pi), 0.0), 1.0)
        let oldDuration = durationMinutes
        
        switch mode {
        case .minutes:
            let rawMins = fraction * 60.0
            var snapped = round(rawMins / 5.0) * 5.0
            if snapped < 5.0 { snapped = 5.0 }
            if snapped > 60.0 { snapped = 60.0 }
            durationMinutes = snapped
            angle = CGFloat(snapped / 60.0) * 2 * .pi
        case .hours:
            let rawHours = fraction * 12.0
            var snappedHours = round(rawHours / 0.5) * 0.5
            if snappedHours < 0.5 { snappedHours = 0.5 }
            if snappedHours > 12.0 { snappedHours = 12.0 }
            durationMinutes = snappedHours * 60.0
            angle = CGFloat(snappedHours / 12.0) * 2 * .pi
        }
        
        if abs(durationMinutes - oldDuration) > 0.001 {
            feedback.selectionChanged()
            onDurationChanged?(durationMinutes)
        }
        
        updateDisplay()
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2.0 - 22.0
        guard radius > 0 else { return }
        
        let trackPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        trackColor.setStroke()
        trackPath.lineWidth = 7.0
        trackPath.stroke()
        
        let tickCount = 12
        for i in 0..<tickCount {
            let tickAngle = (CGFloat(i) / CGFloat(tickCount)) * 2 * .pi - .pi / 2
            let isQuarter = (i % 3 == 0)
            let tickLen: CGFloat = isQuarter ? 8.0 : 4.5
            let startR = radius - 14.0
            let endR = startR + tickLen
            
            let p1 = CGPoint(x: center.x + startR * cos(tickAngle), y: center.y + startR * sin(tickAngle))
            let p2 = CGPoint(x: center.x + endR * cos(tickAngle), y: center.y + endR * sin(tickAngle))
            
            let tickPath = UIBezierPath()
            tickPath.move(to: p1)
            tickPath.addLine(to: p2)
            tickPath.lineWidth = isQuarter ? 1.5 : 1.0
            textColor.withAlphaComponent(isQuarter ? 0.35 : 0.16).setStroke()
            tickPath.stroke()
        }
        
        let startAngle: CGFloat = -.pi / 2
        let currentAngle = startAngle + angle
        if angle > 0.01 {
            let arcPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: currentAngle, clockwise: true)
            progressColor.setStroke()
            arcPath.lineWidth = 7.0
            arcPath.lineCapStyle = .round
            arcPath.stroke()
        }
        
        let knobCenter = CGPoint(x: center.x + radius * cos(currentAngle), y: center.y + radius * sin(currentAngle))
        let knobRadius: CGFloat = 13.0
        
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: UIColor.black.withAlphaComponent(0.35).cgColor)
        let knobPath = UIBezierPath(arcCenter: knobCenter, radius: knobRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        UIColor.white.setFill()
        knobPath.fill()
        ctx.restoreGState()
        
        progressColor.withAlphaComponent(0.2).setStroke()
        knobPath.lineWidth = 1.0
        knobPath.stroke()
        
        let dotPath = UIBezierPath(arcCenter: knobCenter, radius: 4.5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        progressColor.setFill()
        dotPath.fill()
    }
}
