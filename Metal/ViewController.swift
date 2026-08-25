//
//  ViewController.swift
//  Metal
//
//  Created by Mac on 27.06.2026.
//

import UIKit
import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UIDocumentPickerDelegate, AVAudioPlayerDelegate {

    // Category association key for Objective-C runtime
    static var categoryAssociationKey: UInt8 = 0
    static var textAssociationKey: UInt8 = 1

    // Swipable Container
    var scrollView: UIScrollView!
    
    // Page 0 (Settings) & Page 1 (Library) Subviews
    var page0: UIView!
    var page1: UIView!
    var tableView: CylinderTableView!
    var searchBar: UISearchBar!
    var importButton: UIButton!
    
    // Horizontal Playlists/Favorites Pill Scroller
    var filtersScrollView: UIScrollView!
    var filtersStackView: UIStackView!
    
    // Custom Bottom Sheet Active States
    var activeDimmedBg: UIView?
    var activeSheetView: UIView?
    var activeSheetBottomConstraint: NSLayoutConstraint?
    
    // Miniplayer (Page 1 Interface - Floating Pill Card)
    var miniPlayerView: UIView!
    var miniCoverCard: UIView!
    var miniCoverView: UIImageView!
    var miniTitleLabel: UILabel!
    var miniArtistLabel: UILabel!
    var miniPreviousButton: UIButton!
    var miniPlayPauseButton: UIButton!
    var miniNextButton: UIButton!
    
    // Page 2 (Now Playing) Subviews
    var page2: UIView!
    var playerGradientLayer: CAGradientLayer!
    var playerHeaderLabel: UILabel!
    var coverArtCard: UIView!
    var coverImageView: UIImageView!
    var trackTitleLabel: UILabel!
    var artistLabel: UILabel!
    var progressSlider: UISlider!
    var elapsedLabel: UILabel!
    var remainingLabel: UILabel!
    var playPauseButton: UIButton!
    var shuffleButton: UIButton!
    var repeatButton: UIButton!
    var playerFavoriteButton: UIButton!
    var playerDislikeButton: UIButton!
    
    // Playback State & Audio Player
    var tracks: [Track] = []
    var filteredTracks: [Track] = []
    var currentTrackIndex: Int? {
        didSet {
            savePlaybackState()
        }
    }
    var audioPlayer: AVAudioPlayer?
    var updateTimer: Timer?
    var sleepTimer: Timer?
    var persistedSettings = MetalSettingsDocument()
    var isRestoringPersistentState = false
    var lastSavedPlaybackBucket = -1
    var listeningTelemetry = ListeningTelemetryDocument()
    var telemetrySessionFilename: String?
    var telemetryLastPlaybackTime: TimeInterval = 0
    var telemetrySessionListeningSeconds: TimeInterval = 0
    var dailyMixTracks: [Track] = []
    var dailyMixBucket: Int64?
    var dailyMixRefreshTimer: Timer?
    
    // Shuffle Queue State
    var shuffledIndices: [Int] = []
    var shuffledPosition: Int = 0
    
    // Haptics & Drum Centering State
    var lastCenterRow: Int?
    let scrollFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    let aidj = AIDJTransitionCoordinator()
    var didInitialScroll = false
    
    // Favorites & Playlists Local Data Store
    var favoriteTracks: Set<String> = []
    var playlists: [String: [String]] = [:] // mapping Playlist Name -> Track Filenames
    
    enum FilterCategory: Equatable {
        case all
        case dailyMix
        case favorites
        case lovely
        case playlist(String)
    }
    var activeFilter: FilterCategory = .all
    
    var isShuffleEnabled = false {
        didSet {
            UserDefaults.standard.set(isShuffleEnabled, forKey: "Metal_Shuffle")
            updatePlaybackButtons()
            if isShuffleEnabled {
                rebuildShuffleQueue()
            }
            saveSettings()
        }
    }
    
    var isRepeatEnabled = false {
        didSet {
            UserDefaults.standard.set(isRepeatEnabled, forKey: "Metal_Repeat")
            updatePlaybackButtons()
            saveSettings()
        }
    }
    
    deinit {
        dailyMixRefreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadLocalUserData()
        loadListeningTelemetry()
        setupUI()
        setupAudioSession()
        setupRemoteCommands()
        loadLocalTracks()
        loadPlaybackState()
        startDailyMixRefreshTimer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Listen for app foregrounding to refresh UI state
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDailyMixNotificationTap),
            name: .metalDailyMixNotificationTapped,
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCardBorders()
        updateTableGradientMaskFrame()
        applyCylinderEffect()
        updateFilterPillBorders()
        updateOverlayAlphas()
        
        if !didInitialScroll && scrollView.frame.size.width > 0 {
            didInitialScroll = true
            let width = scrollView.frame.size.width
            scrollView.contentOffset = CGPoint(x: width, y: 0)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            guard isViewLoaded else { return }
            view.backgroundColor = primaryBackgroundColor()
            page0?.backgroundColor = primaryBackgroundColor()
            page1?.backgroundColor = primaryBackgroundColor()
            tableView?.reloadData()
            updateCardBorders()
            updateTableGradientMaskFrame()
            updateFilterPillBorders()
        }
    }
    
    @objc func appWillEnterForeground() {
        refreshDailyMixIfNeeded()
        updateMiniPlayerUI()
        publishWidgetRecommendations()
        if let player = audioPlayer {
            let playIcon = player.isPlaying ? "pause.fill" : "play.fill"
            playPauseButton.setImage(UIImage(systemName: playIcon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
        }
    }

    @objc func appWillResignActive() {
        if let player = audioPlayer {
            updateListeningTelemetry(with: player)
        }
        saveListeningTelemetry()
        savePlaybackState()
    }
}
