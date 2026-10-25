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
    
    // MARK: - Native Context Menus (Track & Player)
    
    func makeTrackContextMenu(for track: Track, at index: Int, isPlayer: Bool = false) -> UIMenu {
        var actions: [UIMenuElement] = []
        
        // 1. Play / Pause Action
        if !isPlayer {
            let isCurrent = (audioPlayer != nil && audioPlayer?.url == track.url && audioPlayer?.isPlaying == true)
            let playTitle = isCurrent ? "Pause" : "Play"
            let playIcon = isCurrent ? "pause.fill" : "play.fill"
            let playAction = UIAction(title: playTitle, image: UIImage(systemName: playIcon)) { [weak self] _ in
                guard let self = self else { return }
                if isCurrent {
                    self.playPauseTapped()
                } else if index < self.filteredTracks.count {
                    let indexPath = IndexPath(row: index, section: 0)
                    self.tableView(self.tableView, didSelectRowAt: indexPath)
                }
            }
            actions.append(playAction)
        }
        
        // 2. Add to Playlist Submenu
        var playlistElements: [UIMenuElement] = []
        let sortedPlaylists = playlists.keys.sorted()
        for name in sortedPlaylists {
            let inPlaylist = playlists[name]?.contains(track.url.lastPathComponent) == true
            let icon = inPlaylist ? "checkmark" : "music.note.list"
            let item = UIAction(title: name, image: UIImage(systemName: icon)) { [weak self] _ in
                self?.addTrackToPlaylist(track: track, playlistName: name)
            }
            playlistElements.append(item)
        }
        
        let newPlaylistAction = UIAction(title: "New Playlist...", image: UIImage(systemName: "plus")) { [weak self] _ in
            self?.presentCustomInputSheet(title: "New Playlist", placeholder: "Playlist Name", submitTitle: "Create") { [weak self] name in
                self?.playlists[name] = [track.url.lastPathComponent]
                self?.savePlaylists()
                self?.rebuildFiltersRow()
                self?.showToast(message: "Created and added to \(name)", success: true)
            }
        }
        playlistElements.append(newPlaylistAction)
        
        let playlistMenu = UIMenu(title: "Add to Playlist", image: UIImage(systemName: "plus.circle"), children: playlistElements)
        actions.append(playlistMenu)
        
        // 3. Share Song
        let shareAction = UIAction(title: "Share Song", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.shareTrack(track)
        }
        actions.append(shareAction)
        
        // 4. Sleep Timer
        let sleepTimerAction = UIAction(title: "Sleep Timer", image: UIImage(systemName: "timer")) { [weak self] _ in
            self?.showSleepTimerSelector()
        }
        actions.append(sleepTimerAction)
        
        // 5. Remove from Playlist (if activeFilter is playlist)
        if case .playlist(let playlistName) = activeFilter {
            let removeAction = UIAction(title: "Remove from \(playlistName)", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
                self?.removeFromPlaylist(track: track, name: playlistName)
            }
            actions.append(removeAction)
        }
        
        // 6. Delete Song
        let deleteAction = UIAction(title: "Delete Song", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.deleteTrack(at: index)
        }
        actions.append(deleteAction)
        
        let menu = UIMenu(title: track.title, children: actions)
        if #available(iOS 15.0, *) {
            menu.subtitle = track.artist
        }
        return menu
    }
    
    func makePlayerOptionsMenu() -> UIMenu {
        guard let index = currentTrackIndex, index < filteredTracks.count else {
            return UIMenu(title: "Options", children: [])
        }
        let track = filteredTracks[index]
        return makeTrackContextMenu(for: track, at: index, isPlayer: true)
    }
    
    func updatePlayerOptionsMenu() {
        playerOptionsButton?.menu = makePlayerOptionsMenu()
    }
    
    func addTrackToPlaylist(track: Track, playlistName name: String) {
        var list = playlists[name] ?? []
        let filename = track.url.lastPathComponent
        if !list.contains(filename) {
            list.append(filename)
            playlists[name] = list
            savePlaylists()
            showToast(message: "Added to \(name)", success: true)
        } else {
            showToast(message: "Already in \(name)", success: false)
        }
    }
    
    func shareTrack(_ track: Track) {
        let shareVC = UIActivityViewController(activityItems: [track.url], applicationActivities: nil)
        present(shareVC, animated: true)
    }
    
    @objc func optionsTapped() {
        updatePlayerOptionsMenu()
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
        queueTable.register(TrackCell.self, forCellReuseIdentifier: TrackCell.identifier)
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
        
        // Circular Dial
        let dial = CircularTimerDialView()
        dial.translatesAutoresizingMaskIntoConstraints = false
        dial.trackColor = cardBorderColor()
        dial.progressColor = primaryButtonColor()
        dial.textColor = primaryTextColor()
        dial.subtitleColor = secondaryTextColor()
        sheetView.addSubview(dial)
        
        if let endDate = sleepTimerEndDate, endDate > Date() {
            let remaining = max(5.0, ceil(endDate.timeIntervalSinceNow / 60.0))
            dial.setDuration(minutes: remaining)
        }
        
        let buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 10
        buttonStack.distribution = .fill
        sheetView.addSubview(buttonStack)
        
        let isTimerActive = (sleepTimer != nil && sleepTimerEndDate != nil && sleepTimerEndDate! > Date())
        
        let submitBtn = UIButton(type: .custom)
        submitBtn.translatesAutoresizingMaskIntoConstraints = false
        submitBtn.setTitle(isTimerActive ? "Update Sleep Timer" : "Start Sleep Timer", for: .normal)
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
        
        if isTimerActive {
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
            
            grabber.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            grabber.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 8),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            subLabel.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            
            dial.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 16),
            dial.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            dial.widthAnchor.constraint(equalToConstant: 220),
            dial.heightAnchor.constraint(equalToConstant: 220),
            
            buttonStack.topAnchor.constraint(equalTo: dial.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor, constant: -20)
        ])
        
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.identifier, for: indexPath) as? TrackCell,
              let parent = parent else {
            return UITableViewCell()
        }
        let track = queue[indexPath.row]
        let isPlaying = (parent.audioPlayer != nil && parent.audioPlayer?.url == track.url)
        cell.configure(with: track, index: indexPath.row, isPlaying: isPlaying, colors: parent)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let track = queue[indexPath.row]
        onSelect(track, indexPath.row)
    }
}

// MARK: - Circular Sleep Timer Dial View

class CircularTimerDialView: UIControl {
    private(set) var durationMinutes: Double = 30.0
    var onDurationChanged: ((Double) -> Void)?
    
    private var angle: CGFloat = (.pi * 0.5) // ~30 minutes
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
        valueLabel.font = UIFont(name: "Georgia-Bold", size: 36) ?? UIFont.systemFont(ofSize: 36, weight: .bold)
        valueLabel.textAlignment = .center
        addSubview(valueLabel)
        
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.font = UIFont(name: "Georgia-Italic", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
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
        durationMinutes = min(120.0, max(5.0, minutes))
        syncAngleFromDuration()
        updateDisplay()
        setNeedsDisplay()
    }
    
    private func syncAngleFromDuration() {
        let fraction = (durationMinutes - 5.0) / 115.0
        angle = CGFloat(fraction) * 2 * .pi
    }
    
    private func updateDisplay() {
        valueLabel.textColor = textColor
        unitLabel.textColor = subtitleColor
        
        let mins = Int(durationMinutes)
        if mins < 60 {
            valueLabel.text = "\(mins)"
            unitLabel.text = "MINUTES"
        } else if mins == 60 {
            valueLabel.text = "1"
            unitLabel.text = "HOUR"
        } else if mins == 120 {
            valueLabel.text = "2"
            unitLabel.text = "HOURS"
        } else {
            let h = mins / 60
            let m = mins % 60
            valueLabel.text = "\(h)h \(m)m"
            unitLabel.text = "SLEEP TIMER"
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
        
        let rawMins = 5.0 + fraction * 115.0
        var snapped = round(rawMins / 5.0) * 5.0
        if snapped < 5.0 { snapped = 5.0 }
        if snapped > 120.0 { snapped = 120.0 }
        durationMinutes = snapped
        angle = CGFloat((snapped - 5.0) / 115.0) * 2 * .pi
        
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
        
        progressColor.withAlphaComponent(0.25).setStroke()
        knobPath.lineWidth = 1.0
        knobPath.stroke()
        
        let dotPath = UIBezierPath(arcCenter: knobCenter, radius: 4.5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        progressColor.setFill()
        dotPath.fill()
    }
}
