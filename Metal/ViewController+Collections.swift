import UIKit

extension ViewController {
    var dailyMixContextTitle: String {
        dailyMixMode == .forYou ? "DAILY MIX" : "DAILY MIX · \(dailyMixMode.title.uppercased())"
    }

    private var libraryCollectionItems: [LibraryCollectionItem] {
        tracks.map { track in
            let id = track.url.lastPathComponent
            return LibraryCollectionItem(id: id, title: track.title, duration: track.duration,
                importedAt: trackImportedAt[id] ?? 0, isFavorite: favoriteTracks.contains(id),
                listening: listeningTelemetry.tracks[id] ?? TrackListeningTelemetry())
        }
    }

    func tracksForLibraryCollection() -> [Track] {
        guard libraryCollection != .all else { return tracks }
        let ids = LibraryCollectionEngine.select(from: libraryCollectionItems,
            collection: libraryCollection, now: Date().timeIntervalSince1970)
        let byID = Dictionary(tracks.map { ($0.url.lastPathComponent, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    func configureCollectionPill(_ button: UIButton, menu: UIMenu, accessibilityLabel: String) {
        button.removeTarget(self, action: #selector(filterPillTapped(_:)), for: .touchUpInside)
        button.showsMenuAsPrimaryAction = true
        button.menu = menu
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityHint = "Choose a collection"
        if var config = button.configuration {
            config.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .semibold))
            config.imagePlacement = .trailing
            config.imagePadding = 5
            button.configuration = config
        }
    }

    var libraryCollectionPillTitle: String {
        switch libraryCollection {
        case .all: return "All"
        case .recentlyAdded: return "Recent"
        case .unheard: return "Unplayed"
        case .rediscover: return "Forgotten"
        }
    }

    var dailyMixPillTitle: String {
        dailyMixMode == .forYou ? "Daily Mix" : "Mix · \(dailyMixMode.title)"
    }

    func makeLibraryCollectionMenu() -> UIMenu {
        let items = libraryCollectionItems
        let now = Date().timeIntervalSince1970
        let actions = LibraryCollection.allCases.map { collection -> UIAction in
            let count = LibraryCollectionEngine.select(from: items, collection: collection, now: now).count
            let title = collection == .all ? collection.title : "\(collection.title) · \(count)"
            return UIAction(title: title, image: UIImage(systemName: collection.symbol),
                attributes: collection != .all && count == 0 ? .disabled : [],
                state: collection == libraryCollection ? .on : .off) { [weak self] _ in
                self?.selectLibraryCollection(collection)
            }
        }
        return UIMenu(title: "Your Library", children: actions)
    }

    func makeDailyMixModeMenu() -> UIMenu {
        let candidates = dailyMixCandidates()
        let modes = DailyMixMode.allCases.map { mode -> UIAction in
            let count = DailyMixEngine.candidates(for: mode, from: candidates).count
            return UIAction(title: mode.title, image: UIImage(systemName: mode.symbol),
                attributes: mode != .forYou && count == 0 ? .disabled : [],
                state: mode == dailyMixMode ? .on : .off) { [weak self] _ in
                self?.selectDailyMixMode(mode)
            }
        }
        let reshape = UIAction(title: "Reshape next songs", image: UIImage(systemName: "waveform.path"),
            attributes: tracks.count < 2 ? .disabled : []) { [weak self] _ in
            guard let self else { return }
            self.activeFilter = .dailyMix
            self.filterTracks()
            self.rebuildFiltersRow()
            self.shakeDailyMix()
        }
        return UIMenu(title: "Daily Mix", children: [
            UIMenu(options: .displayInline, children: modes),
            UIMenu(options: .displayInline, children: [reshape])
        ])
    }

    private func animateCollectionChange(_ change: @escaping () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            change()
        } else {
            UIView.transition(with: tableView, duration: 0.22,
                options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState], animations: change)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectLibraryCollection(_ collection: LibraryCollection) {
        animateCollectionChange {
            self.libraryCollection = collection
            self.activeFilter = .all
            self.searchBar.text = ""
            self.filterTracks()
            self.rebuildFiltersRow()
            self.saveSettings()
        }
    }

    private func selectDailyMixMode(_ mode: DailyMixMode) {
        let changed = dailyMixMode != mode
        animateCollectionChange {
            self.dailyMixMode = mode
            self.activeFilter = .dailyMix
            self.searchBar.text = ""
            if changed {
                self.dailyMixBucket = nil
                self.dailyMixRemixHistory = []
                self.lastMixExtensionAttempt = nil
                if self.playbackSource == .dailyMix {
                    self.currentPlaybackContext = self.dailyMixContextTitle
                    self.playerHeaderLabel?.text = self.currentPlaybackContext
                    self.rebuildDailyMixQueue(remix: true)
                } else {
                    self.refreshDailyMixIfNeeded(force: true)
                }
            }
            self.filterTracks()
            self.rebuildFiltersRow()
            self.saveSettings()
        }
    }

    func updateCollectionEmptyState() {
        guard activeFilter == .all, !tracks.isEmpty, filteredTracks.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        let message: String
        if !(searchBar.text ?? "").isEmpty {
            message = "No songs match this search."
        } else {
            switch libraryCollection {
            case .all:
                tableView.backgroundView = nil
                return
            case .recentlyAdded:
                message = "Your next imports will appear here."
            case .unheard:
                message = "You’re all caught up.\nYour next imports will appear here."
            case .rediscover:
                message = "Give your favorites a little time.\nSongs return after two weeks away."
            }
        }
        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = secondaryTextColor()
        tableView.backgroundView = label
    }

    func refreshCollectionMenus() {
        guard isViewLoaded, let stack = filtersStackView else { return }
        for case let button as UIButton in stack.arrangedSubviews {
            guard let category = objc_getAssociatedObject(button, &ViewController.categoryAssociationKey) as? FilterCategory else { continue }
            if category == .all { button.menu = makeLibraryCollectionMenu() }
            if category == .dailyMix { button.menu = makeDailyMixModeMenu() }
        }
    }
}
