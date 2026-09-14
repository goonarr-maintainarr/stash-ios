import SwiftUI
import AVKit

/// A standard card view for displaying a scene.
///
/// Uses the callback pattern - parent views provide action handlers for navigation.
///
/// **Used by:**
/// - `SceneListView`
/// - `PerformerDetailView` (Scene Grid)
/// - `StudioDetailView` (Scene Grid)
struct SceneCard: View {
    private enum Source {
        case manual(SceneCardConfiguration)
        case scene(Scene, Bool)
        case whisparr(WhisparrScene, Bool, String?)
        case stashDB(StashDBScene, Bool)
    }
    
    private let source: Source
    let forceTitleHeight: Bool
    let isCompact: Bool
    let actions: SceneCardActions
    @EnvironmentObject var settings: SettingsStore
    @State private var isPlayingPreview = false
    @State private var player: AVPlayer?
    @State private var scrubTime: Double? = nil
    @State private var playerObserver: NSObjectProtocol?
    @State private var isPressed = false  // For bounce animation
    
    // Computed configuration using environment settings
    private var config: SceneCardConfiguration {
        switch source {
        case .manual(let config):
            return config
        case .scene(let scene, let showDescription):
            return SceneCardConfiguration(scene: scene, settings: settings, showDescription: showDescription)
        case .whisparr(let movie, let isInQueue, let qualityProfileName):
            return SceneCardConfiguration(whisparrScene: movie, isInQueue: isInQueue, qualityProfileName: qualityProfileName) // Whisparr cards don't use description toggle yet
        case .stashDB(let scene, let showDescription):
            return SceneCardConfiguration(stashDBScene: scene, showDescription: showDescription)
        }
    }
    
    // MARK: - Initializers
    
    init(scene: Scene, forceTitleHeight: Bool = false, showDescription: Bool = true, isCompact: Bool = false, actions: SceneCardActions = .none) {
        self.forceTitleHeight = forceTitleHeight
        self.isCompact = isCompact
        self.source = .scene(scene, showDescription)
        self.actions = actions
    }
    
    init(whisparrScene: WhisparrScene, isInQueue: Bool, qualityProfileName: String? = nil, forceTitleHeight: Bool = false, isCompact: Bool = false, actions: SceneCardActions = .none) {
        self.forceTitleHeight = forceTitleHeight
        self.isCompact = isCompact
        self.source = .whisparr(whisparrScene, isInQueue, qualityProfileName)
        self.actions = actions
    }
    
    init(stashDBScene: StashDBScene, forceTitleHeight: Bool = false, showDescription: Bool = true, isCompact: Bool = false, actions: SceneCardActions = .none) {
        self.forceTitleHeight = forceTitleHeight
        self.isCompact = isCompact
        self.source = .stashDB(stashDBScene, showDescription)
        self.actions = actions
    }
    
    init(config: SceneCardConfiguration, forceTitleHeight: Bool = false, isCompact: Bool = false, actions: SceneCardActions = .none) {
        self.source = .manual(config)
        self.forceTitleHeight = forceTitleHeight
        self.isCompact = isCompact
        self.actions = actions
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SceneCardThumbnail(
                config: config,
                isPlayingPreview: $isPlayingPreview,
                player: player,
                scrubTime: $scrubTime,
                actions: actions,
                isPressed: $isPressed
            )
            .aspectRatio(16/9, contentMode: .fit)
            
            SceneCardInfo(
                config: config,
                forceTitleHeight: forceTitleHeight,
                isCompact: isCompact,
                actions: actions,
                scrubTime: scrubTime,
                isPressed: $isPressed
            )
        }
        .background(Color.stashCardBackground)
        .cornerRadius(12)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onChange(of: isPlayingPreview) { _, playing in
            if playing {
                if player == nil {
                    startPreview()
                }
            } else {
                stopPreview()
            }
        }
        .onDisappear {
            scrubTime = nil
            if isPlayingPreview {
                isPlayingPreview = false
            }
        }
    }
    
    // MARK: - Preview Player
    
    private func startPreview() {
        guard let url = config.videoPreviewUrl else { return }
        
        // Only create player if needed
        if player == nil {
            let playerItem = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.isMuted = true
            newPlayer.actionAtItemEnd = .none // Loop
            
            // Loop logic - store observer for cleanup
            let observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak newPlayer] _ in
                newPlayer?.seek(to: .zero)
                newPlayer?.play()
            }
            
            self.playerObserver = observer
            self.player = newPlayer
            newPlayer.play()
        } else {
            player?.play()
        }
    }
    
    private func stopPreview() {
        player?.pause()
        player = nil // Release player
        
        // Remove notification observer to prevent memory leak
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
    }
}
