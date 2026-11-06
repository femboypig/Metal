//
//  ViewController+BottomSheet.swift
//  Metal
//

import UIKit
import AVFoundation

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
        
        do {
            let artView = GlassArtworkImageView()
            artView.setArtwork(artwork, seed: title)
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
        
        if isPlayer {
            let vibe = UIAction(title: "Continue this vibe", image: UIImage(systemName: "dot.radiowaves.left.and.right")) { [weak self] _ in
                self?.continueTrackVibe(from: track)
            }
            actions.append(UIMenu(options: .displayInline, children: [vibe]))
        }

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
        let sleepTitle = sleepTimerEndDate.map { $0 > Date() ? "Sleep Timer · On" : "Sleep Timer" } ?? "Sleep Timer"
        let sleepTimerAction = UIAction(title: sleepTitle, image: UIImage(systemName: "moon.zzz")) { [weak self] _ in
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
            self?.deleteTrack(track: track)
        }
        actions.append(deleteAction)
        
        let menu = UIMenu(title: track.title, children: actions)
        if #available(iOS 15.0, *) {
            menu.subtitle = track.artist
        }
        return menu
    }
    
    func makePlayerOptionsMenu() -> UIMenu {
        guard let track = currentPlaybackTrack() else {
            return UIMenu(title: "Options", children: [])
        }
        let index = filteredTracks.firstIndex { $0.url == track.url } ?? 0
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
        queueSheetCountLabel = subLabel
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
        
        queueSheetTable = queueTable
        let dataSource = QueueSheetDataSource(parent: self) { [weak self] track, index in
            guard let self, self.currentQueue.indices.contains(index), self.currentQueue[index].url == track.url else { return }
            self.recordManualSelection(for: track)
            self.currentTrackIndex = index
            if self.isShuffleEnabled { self.rebuildShuffleQueue() }
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
            guard let self, self.presentedViewController == nil else { return }
            let controller = SleepTimerViewController()
            controller.endDate = self.sleepTimerEndDate
            controller.onStart = { [weak self] minutes in self?.startSleepTimer(minutes: minutes) }
            controller.onCancel = { [weak self] in self?.cancelSleepTimer() }
            controller.modalPresentationStyle = .pageSheet
            if let sheet = controller.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    let height: CGFloat = controller.endDate.map { $0 > Date() } == true ? 528 : 476
                    sheet.detents = [.custom(identifier: .init("sleepTimer")) { context in
                        min(height, context.maximumDetentValue)
                    }]
                } else {
                    sheet.detents = [.medium(), .large()]
                }
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 32
            }
            self.present(controller, animated: true)
        }
    }

    func startSleepTimer(minutes: Double) {
        guard minutes.isFinite, minutes > 0 else { return }
        cancelSleepFade()
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
        updatePlayerOptionsMenu()
        showToast(message: message, success: true)
    }
    
    func cancelSleepTimer() {
        cancelSleepFade()
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
        updatePlayerOptionsMenu()
        showToast(message: "Sleep timer cancelled", success: true)
    }
    
    func cancelSleepFade() {
        sleepFadeTimer?.invalidate()
        sleepFadeTimer = nil
        sleepFadePlayer?.volume = sleepFadeVolume
        sleepFadePlayer = nil
    }

    func finishSleepTimerStop(for player: AVAudioPlayer) {
        updateListeningTelemetry(with: player)
        finishListeningTelemetry(completed: false, skipped: false,
            progress: player.duration > 0 ? player.currentTime / player.duration : 0,
            reason: .sleepTimer)
        player.pause()
        cancelSleepFade()
        updateTimer?.invalidate()
        savePlaybackState()
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
        stopArtworkAnimation()
        updateNowPlayingInfo()
        updateMiniPlayerUI()
    }

    func stopPlaybackDueToSleepTimer() {
        guard sleepFadeTimer == nil else { return }
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
        updatePlayerOptionsMenu()
        guard let player = audioPlayer, player.isPlaying else { return }
        if aidj.isTransitioning { aidj.cancel(keeping: player) }
        sleepFadePlayer = player
        sleepFadeVolume = player.volume
        let initialVolume = player.volume
        let started = ProcessInfo.processInfo.systemUptime
        sleepFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak player] timer in
            guard let self, let player, self.audioPlayer === player else {
                timer.invalidate()
                return
            }
            let progress = min(1, (ProcessInfo.processInfo.systemUptime - started) / 5)
            player.volume = initialVolume * Float(1 - progress)
            if progress >= 1 {
                self.finishSleepTimerStop(for: player)
            }
        }
    }

}

// MARK: - Queue Sheet Data Source Helper

private class QueueSheetDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var parent: ViewController?
    var queue: [Track] { parent?.currentQueue ?? [] }
    let onSelect: (Track, Int) -> Void
    
    init(parent: ViewController, onSelect: @escaping (Track, Int) -> Void) {
        self.parent = parent
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
        guard queue.indices.contains(indexPath.row) else { return cell }
        let track = queue[indexPath.row]
        let isPlaying = (parent.audioPlayer != nil && parent.audioPlayer?.url == track.url)
        cell.configure(with: track, index: indexPath.row, isPlaying: isPlaying, colors: parent)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard queue.indices.contains(indexPath.row) else { return }
        let track = queue[indexPath.row]
        onSelect(track, indexPath.row)
    }
}

// MARK: - Sleep timer

private final class SleepTimerViewController: UIViewController {
    var endDate: Date?
    var onStart: ((Double) -> Void)?
    var onCancel: (() -> Void)?
    private let dial = CircularTimerDialView()
    private let finishLabel = UILabel()
    private let statusLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private var statusTimer: Timer?

    deinit { statusTimer?.invalidate() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        let header = UIStackView()
        header.alignment = .center
        let title = UILabel()
        title.text = "Sleep timer"
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header
        header.addArrangedSubview(title)
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 27)), for: .normal)
        close.tintColor = .tertiaryLabel
        close.accessibilityLabel = "Close sleep timer"
        close.widthAnchor.constraint(equalToConstant: 44).isActive = true
        close.heightAnchor.constraint(equalToConstant: 44).isActive = true
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        header.addArrangedSubview(close)
        stack.addArrangedSubview(header)
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(statusLabel)

        let dialContainer = UIView()
        dial.translatesAutoresizingMaskIntoConstraints = false
        dialContainer.addSubview(dial)
        NSLayoutConstraint.activate([
            dial.centerXAnchor.constraint(equalTo: dialContainer.centerXAnchor),
            dial.topAnchor.constraint(equalTo: dialContainer.topAnchor),
            dial.bottomAnchor.constraint(equalTo: dialContainer.bottomAnchor),
            dial.widthAnchor.constraint(equalTo: dial.heightAnchor),
            dial.widthAnchor.constraint(lessThanOrEqualTo: dialContainer.widthAnchor),
            dial.heightAnchor.constraint(equalToConstant: 216)
        ])
        stack.addArrangedSubview(dialContainer)
        if let endDate, endDate > Date() {
            dial.setDuration(minutes: ceil(endDate.timeIntervalSinceNow / 60))
        }
        dial.onDurationChanged = { [weak self] _ in self?.updateFinishTime() }
        finishLabel.textAlignment = .center
        finishLabel.font = .preferredFont(forTextStyle: .subheadline)
        finishLabel.textColor = .secondaryLabel
        finishLabel.numberOfLines = 0
        finishLabel.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(finishLabel)

        let presets = UIStackView()
        presets.spacing = 8
        presets.distribution = .fillEqually
        for minutes in [15, 30, 45, 60] {
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.tinted()
            config.title = "\(minutes)m"
            config.baseForegroundColor = .label
            config.baseBackgroundColor = .secondarySystemFill
            config.cornerStyle = .capsule
            button.configuration = config
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.accessibilityLabel = "\(minutes) minutes"
            button.addAction(UIAction { [weak self] _ in
                self?.dial.setDuration(minutes: Double(minutes))
                self?.updateFinishTime()
                UISelectionFeedbackGenerator().selectionChanged()
            }, for: .touchUpInside)
            presets.addArrangedSubview(button)
        }
        stack.addArrangedSubview(presets)
        var config = UIButton.Configuration.filled()
        config.title = endDate.map { $0 > Date() } == true ? "Update timer" : "Set timer"
        config.image = UIImage(systemName: "moon.zzz.fill")
        config.imagePadding = 10
        config.baseBackgroundColor = UIColor(red: 0.78, green: 0.24, blue: 0.12, alpha: 1)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        startButton.configuration = config
        startButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        startButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let minutes = self.dial.durationMinutes
            self.dismiss(animated: true) { self.onStart?(minutes) }
        }, for: .touchUpInside)
        stack.addArrangedSubview(startButton)
        if endDate.map({ $0 > Date() }) == true {
            let cancel = UIButton(type: .system)
            cancel.setTitle("Cancel timer", for: .normal)
            cancel.tintColor = .systemRed
            cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            cancel.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.dismiss(animated: true) { self.onCancel?() }
            }, for: .touchUpInside)
            stack.addArrangedSubview(cancel)
        }
        updateStatus()
        updateFinishTime()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatus()
            self?.updateFinishTime()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        var ancestor = dial.superview
        while let container = ancestor {
            for case let pan as UIPanGestureRecognizer in container.gestureRecognizers ?? [] {
                pan.require(toFail: dial.rotationGesture)
            }
            ancestor = container.superview
        }
    }

    private func updateStatus() {
        if let endDate, endDate > Date() {
            let seconds = Int(ceil(endDate.timeIntervalSinceNow))
            statusLabel.text = String(format: "Timer active · %d:%02d remaining", seconds / 60, seconds % 60)
        } else {
            statusLabel.text = "Turn the dial to choose a duration."
        }
    }

    private func updateFinishTime() {
        let finish = Date().addingTimeInterval(dial.durationMinutes * 60)
        let time = DateFormatter.localizedString(from: finish, dateStyle: .none, timeStyle: .short)
        finishLabel.text = "Playback fades out at \(time)"
    }
}

final class CircularTimerDialView: UIControl, UIGestureRecognizerDelegate {
    private(set) var durationMinutes: Double = 30
    var onDurationChanged: ((Double) -> Void)?
    private(set) lazy var rotationGesture = UIPanGestureRecognizer(target: self, action: #selector(rotateDial(_:)))
    private let feedback = UISelectionFeedbackGenerator()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let startAngle: CGFloat = .pi * 0.75
    private let sweep: CGFloat = .pi * 1.5
    private var previousTouchAngle: CGFloat?
    private var fraction: CGFloat { CGFloat((durationMinutes - 5) / 115) }

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = "Sleep duration"
        accessibilityTraits = .adjustable
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 46, weight: .light)
        valueLabel.textAlignment = .center
        unitLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        unitLabel.textAlignment = .center
        unitLabel.textColor = .secondaryLabel
        unitLabel.text = "MINUTES"
        for label in [valueLabel, unitLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isAccessibilityElement = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            unitLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            unitLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        rotationGesture.maximumNumberOfTouches = 1
        rotationGesture.delegate = self
        addGestureRecognizer(rotationGesture)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapDial(_:)))
        tap.delegate = self
        tap.require(toFail: rotationGesture)
        addGestureRecognizer(tap)
        setDuration(minutes: 30)
    }

    func setDuration(minutes: Double) {
        durationMinutes = min(120, max(5, minutes))
        valueLabel.text = "\(Int(durationMinutes))"
        accessibilityValue = "\(Int(durationMinutes)) minutes"
        setNeedsDisplay()
    }

    override func accessibilityIncrement() { adjust(to: durationMinutes + 5) }
    override func accessibilityDecrement() { adjust(to: durationMinutes - 5) }

    private func adjust(to minutes: Double) {
        let old = durationMinutes
        setDuration(minutes: minutes)
        if old != durationMinutes {
            feedback.selectionChanged()
            onDurationChanged?(durationMinutes)
            sendActions(for: .valueChanged)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        let radius = min(bounds.width, bounds.height) * 0.5 - 24
        return abs(hypot(point.x - bounds.midX, point.y - bounds.midY) - radius) < 32
    }

    @objc private func rotateDial(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            feedback.prepare()
            previousTouchAngle = nil
            let translation = gesture.translation(in: self)
            handlePoint(CGPoint(x: point.x - translation.x, y: point.y - translation.y))
            handlePoint(point)
        case .changed:
            handlePoint(point)
        case .ended:
            handlePoint(point)
            previousTouchAngle = nil
        default:
            previousTouchAngle = nil
        }
    }

    @objc private func tapDial(_ gesture: UITapGestureRecognizer) {
        previousTouchAngle = nil
        feedback.prepare()
        handlePoint(gesture.location(in: self))
        previousTouchAngle = nil
    }

    private func handlePoint(_ p: CGPoint) {
        let dx = p.x - bounds.midX, dy = p.y - bounds.midY
        guard hypot(dx, dy) > 35 else { return }
        let angle = atan2(dy, dx)
        if let previous = previousTouchAngle {
            var delta = angle - previous
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            // Maintain a continuous angle, including between snapped increments.
            trackingFraction = min(1, max(0, trackingFraction + delta / sweep))
        } else {
            var relative = angle - startAngle
            if relative < 0 { relative += 2 * .pi }
            if relative <= sweep { trackingFraction = relative / sweep }
            else { trackingFraction = relative - sweep < (2 * .pi - sweep) / 2 ? 1 : 0 }
        }
        previousTouchAngle = angle
        adjust(to: (Double(trackingFraction) * 115 / 5).rounded() * 5 + 5)
    }
    private var trackingFraction: CGFloat = 0

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 24
        guard radius > 0 else { return }
        let track = UIBezierPath(arcCenter: center, radius: radius,
            startAngle: startAngle, endAngle: startAngle + sweep, clockwise: true)
        UIColor.tertiarySystemFill.setStroke()
        track.lineWidth = 3
        track.lineCapStyle = .round
        track.stroke()
        for index in 0...46 {
            let progress = CGFloat(index) / 46
            let angle = startAngle + progress * sweep
            let major = index % 2 == 0
            let outer = radius - 12
            let inner = outer - (major ? 9.0 : 4.0)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            (progress <= fraction ? UIColor.systemOrange.withAlphaComponent(0.85) : UIColor.quaternaryLabel).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
        if fraction > 0 {
            for index in 0..<100 {
                let a = CGFloat(index) / 100 * fraction
                let b = CGFloat(index + 1) / 100 * fraction
                let color = UIColor(hue: 0.075 - 0.045 * a, saturation: 0.82, brightness: 1, alpha: 1)
                let arc = UIBezierPath(arcCenter: center, radius: radius,
                    startAngle: startAngle + a * sweep, endAngle: startAngle + b * sweep, clockwise: true)
                color.setStroke()
                arc.lineWidth = 4
                arc.lineCapStyle = .round
                arc.stroke()
            }
        }
        let angle = startAngle + fraction * sweep
        let knob = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        context.saveGState()
        context.setShadow(offset: .zero, blur: 12, color: UIColor.systemOrange.withAlphaComponent(0.5).cgColor)
        UIColor.systemOrange.setFill()
        UIBezierPath(ovalIn: CGRect(x: knob.x - 7, y: knob.y - 7, width: 14, height: 14)).fill()
        context.restoreGState()
        UIColor.systemBackground.setFill()
        UIBezierPath(ovalIn: CGRect(x: knob.x - 2, y: knob.y - 2, width: 4, height: 4)).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: UIColor.tertiaryLabel]
        ("5m" as NSString).draw(at: CGPoint(x: center.x - radius * 0.72 - 8, y: center.y + radius * 0.72 + 15), withAttributes: attrs)
        ("2h" as NSString).draw(at: CGPoint(x: center.x + radius * 0.72 - 7, y: center.y + radius * 0.72 + 15), withAttributes: attrs)
    }
}
