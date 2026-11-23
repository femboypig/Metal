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
import CoreText

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UIDocumentPickerDelegate, AVAudioPlayerDelegate {

    // Category association key for Objective-C runtime
    static var categoryAssociationKey: UInt8 = 0
    static var textAssociationKey: UInt8 = 1

    // Library and independently presented player
    var page1: UIView!
    var tableView: CylinderTableView!
    var searchBar: UISearchBar!
    var importButton: UIButton!
    
    // Page 1 Bottom Underlay Panel, Pure Visual Wave & Floating Filters
    var bottomPanel: UIView!
    var myWaveView: YandexWaveView!
    var floatingFiltersContainer: UIView!
    var currentDominantColor: UIColor?

    var libraryViewport: UIView!
    var libraryTopConstraint: NSLayoutConstraint!
    var libraryPan: UIPanGestureRecognizer!
    var libraryCollapse: CGFloat = 0
    var libraryPanStart: CGFloat = 0
    var libraryDisplayLink: CADisplayLink?
    var libraryMotionTarget: CGFloat = 0
    var libraryMotionVelocity: CGFloat = 0
    var libraryMotionTime: CFTimeInterval = 0
    var libraryTableHeightConstraint: NSLayoutConstraint!
    var pulseHero: UIStackView!
    var pulsePlayButton: UIButton!
    var pulseCustomizeButton: UIButton!
    var pulseHeroCenterConstraint: NSLayoutConstraint!
    var isLayingOutLibrary = false
    var pulseTitleLabel: UILabel!
    var pulseReadabilityView: UIView!
    var pulsePreviousUpcoming: [String] = []
    var pulseVibe: PulseVibe = PulseVibe(rawValue: UserDefaults.standard.string(forKey: "Metal_PulseVibe") ?? "") ?? .forYou
    let pulseAudioSampler = PulseAudioSampler()
    var pulseSamplePending = false
    var pulseArtworkColors: [URL: UIColor] = [:]

    
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
    var miniCoverView: GlassArtworkImageView!
    var miniTitleLabel: UILabel!
    var miniArtistLabel: UILabel!
    var miniFavoriteButton: UIButton!
    var miniPlayPauseButton: UIButton!
    
    // Page 2 (Now Playing) Subviews
    var page2: UIView!
    var playerGradientLayer: CAGradientLayer!
    var playerHeaderLabel: UILabel!
    var coverCarouselContainer: UIView!
    var leftCoverCard: UIView!
    var leftCoverImageView: GlassArtworkImageView!
    var leftCoverDimOverlay: UIView!
    var coverArtCard: UIView!
    var coverImageView: GlassArtworkImageView!
    var coverDimOverlay: UIView!
    var rightCoverCard: UIView!
    var rightCoverImageView: GlassArtworkImageView!
    var rightCoverDimOverlay: UIView!
    var isCarouselAnimating: Bool = false

    var playerPresentation: CGFloat = 0
    var playerPresentationTarget: CGFloat = 0
    var playerPresentationAnimator: UIViewPropertyAnimator?
    var pendingPlayerPresentation: Bool?
    var playerDismissPan: UIPanGestureRecognizer!
    var playerDismissCommitted = false
    var playerSlidingSurface: UIView!
    var playerArtworkMotionView: UIView!
    var playerMainControls: UIView!
    var playerTransitionHeader: UIView!
    var playerTransitionFooter: UIView!
    let playerViewportMask = UIView()
    var isPreparingPlayerTransition = false
    var playerMotionElements: [(view: UIView, collapsed: CGAffineTransform)] = []
    var coverPan: UIPanGestureRecognizer!
    var isCoverDragging = false
    var coverDragTransforms: [CGAffineTransform] = []
    var coverReleaseVelocity: CGFloat = 0
    var isCommittingCoverSwipe = false

    var isPlayerPageVisible: Bool { playerPresentation > 0.5 }
    var trackTitleLabel: UILabel!
    var artistLabel: UILabel!
    var progressSlider: UISlider!
    var elapsedLabel: UILabel!
    var remainingLabel: UILabel!
    var playPauseButton: UIButton!
    var playerPrevButton: UIButton!
    var playerNextButton: UIButton!
    var playerDismissButton: UIButton!
    var playerOptionsButton: UIButton!
    var playerDeviceButton: UIButton!
    var playerShareButton: UIButton!
    var playerQueueButton: UIButton!
    var shuffleButton: UIButton!
    var repeatButton: UIButton!
    var playerFavoriteButton: UIButton!
    var playerDislikeButton: UIButton!
    
    // Playback State & Audio Player
    var tracks: [Track] = []
    var filteredTracks: [Track] = []
    var playbackQueue: [Track] = []
    var currentPlaybackContext: String = "ALL SONGS"
    var currentTrackIndex: Int? {
        didSet {
            savePlaybackState()
        }
    }
    var audioPlayer: AVAudioPlayer?
    var updateTimer: Timer?
    var sleepTimer: Timer?
    var sleepFadeTimer: Timer?
    weak var sleepFadePlayer: AVAudioPlayer?
    var sleepFadeVolume: Float = 1
    var sleepTimerEndDate: Date?
    var persistedSettings = MetalSettingsDocument()
    var isRestoringPersistentState = false
    var lastSavedPlaybackBucket = -1
    var listeningTelemetry = ListeningTelemetryDocument()
    var playbackSource: ListeningSource = .library {
        didSet {
            if oldValue != playbackSource {
                mixSessionRecentIDs = []
                lastMixExtensionAttempt = nil
            }
            if playbackSource != .trackVibe { vibeSeedFilename = nil }
        }
    }
    var isUpdatingMixQueue = false
    var lastMixExtensionAttempt: String?
    weak var queueSheetTable: UITableView?
    weak var queueSheetCountLabel: UILabel?
    var vibeSeedFilename: String?
    var mixSessionRecentIDs: [String] = []
    var pendingListeningEndReason: ListeningEndReason = .selection
    var pendingManualSelection: String?
    var telemetrySessionSource: ListeningSource = .library
    var telemetrySessionStartedAt = Date()
    var telemetrySessionDuration: TimeInterval = 0
    var telemetrySessionWasManual = false
    var telemetrySessionFavoriteAtStart = false
    var telemetrySessionMixID: String?
    var telemetryLastUptime: TimeInterval = 0
    var dailyMixRevision: Int64 = 0
    var dailyMixRemixHistory: [[String]] = []
    var dailyMixID = UUID().uuidString
    var lastMixShakeTime: TimeInterval = 0
    var telemetrySessionFilename: String?
    var telemetryLastPlaybackTime: TimeInterval = 0
    var telemetrySessionListeningSeconds: TimeInterval = 0
    var dailyMixTracks: [Track] = []
    var dailyMixBucket: Int64?
    var dailyMixRefreshTimer: Timer?
    var dailyMixVibeCache: [String: CachedAudioVibe] = [:]
    let dailyMixVibeAnalyzer = AudioVibeAnalyzer()
    var trackMetadataCache: [String: TrackMetadataSnapshot] = [:]
    var libraryLoadGeneration = 0
    var widgetPublishWorkItem: DispatchWorkItem?
    var preparedPlayer: AVAudioPlayer?
    var preparedPlayerURL: URL?
    var playbackPreparationGeneration = 0
    let playbackPreparationQueue = DispatchQueue(label: "net.femboypig.Metal.playback-preparation", qos: .userInitiated)
    var isAudioSessionActive = false
    
    // Shuffle Queue State
    var shuffledIndices: [Int] = []
    var shuffledPosition: Int = 0
    
    // Haptics & Drum Centering State
    var lastCenterRow: Int?
    let scrollFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    let aidj = AIDJTransitionCoordinator()
    
    // Favorites & Playlists Local Data Store
    var favoriteTracks: Set<String> = []
    var playlists: [String: [String]] = [:] // mapping Playlist Name -> Track Filenames
    
    enum FilterCategory: Equatable {
        case all
        case dailyMix
        case favorites
        case playlist(String)
    }
    var activeFilter: FilterCategory = .all
    var libraryCollection: LibraryCollection = .all
    var dailyMixMode: DailyMixMode = .forYou
    var trackImportedAt: [String: TimeInterval] = [:]
    
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
        playerPresentationAnimator?.stopAnimation(true)
        libraryDisplayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        updatePulseVisibility()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if !shakePulseVibeIfVisible() { shakeDailyMix() }
        }
        else { super.motionEnded(motion, with: event) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        registerCustomFonts()
        
        loadLocalUserData()
        loadListeningTelemetry()
        loadDailyMixVibeCache()
        setupUI()
        configureAudioSession()
        setupRemoteCommands()
        isRestoringPersistentState = true
        loadLocalTracks()
        loadPlaybackState()
        startDailyMixRefreshTimer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(pulseDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)

        // Listen for app foregrounding to refresh UI state
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDailyMixNotificationTap),
            name: .metalDailyMixNotificationTapped,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackArtworkDidLoad(_:)),
            name: .metalTrackArtworkDidLoad,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLibraryPresentationForLayout()
        updateCardBorders()
        updateTableGradientMaskFrame()
        applyCylinderEffect()
        updateFilterPillBorders()
        if !isCarouselAnimating {
            applyCarouselLayout(isPlaying: audioPlayer?.isPlaying == true, animated: false)
        }
        
        renderPlayerPresentation()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            guard isViewLoaded else { return }
            view.backgroundColor = primaryBackgroundColor()
            page1?.backgroundColor = primaryBackgroundColor()
            tableView?.reloadData()
            updateCardBorders()
            updateTableGradientMaskFrame()
            updateFilterPillBorders()
            updatePlayerControlsTheme(isDark: traitCollection.userInterfaceStyle == .dark)
            if let index = currentTrackIndex, index < tracks.count {
                updatePlayerTheme(with: tracks[index].artwork)
            } else {
                updatePlayerTheme(with: nil)
            }
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    @objc func appWillEnterForeground() {
        if let deadline = sleepTimerEndDate, deadline <= Date() { stopPlaybackDueToSleepTimer() }
        refreshDailyMixIfNeeded()
        startDailyMixRefreshTimer()
        updateMiniPlayerUI()
        scheduleWidgetRecommendationsPublish()
        updatePulseVisibility()
        if audioPlayer?.isPlaying == true { startTimer() }
        if let player = audioPlayer {
            let playIcon: PlaybackIcon = player.isPlaying ? .pause : .play
            playPauseButton.setImage(playIcon.image(size: 24), for: .normal)
        }
    }

    @objc func appWillResignActive() {
        if libraryDisplayLink != nil { setLibraryCollapsed(libraryMotionTarget > 0.5, animated: false) }
        myWaveView?.setRenderingActive(false)
        if let player = audioPlayer {
            updateListeningTelemetry(with: player)
        }
        saveListeningTelemetry()
        savePlaybackState()
        if audioPlayer?.isPlaying == true { startTimer() }
    }

    @objc func powerStateDidChange() {
        if audioPlayer?.isPlaying == true { startTimer() }
        prepareDailyMixVibes()
        prepareUpcomingTrack()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    func registerCustomFonts() {
        for (name, directory) in [("DrukWideBold", nil as String?), ("Fraunces72pt-Bold", "Fonts")] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: directory) else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    func updateWavePlayingState() {
        let isPlaying = audioPlayer?.isPlaying == true
        myWaveView?.setPlaying(isPlaying)
        updatePulsePlayButton()
        applyCarouselLayout(isPlaying: isPlaying, animated: true)
    }
}
