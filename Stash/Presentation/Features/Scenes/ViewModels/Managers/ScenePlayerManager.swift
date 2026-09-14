import Observation
import Foundation
import AVKit
import Combine
import os

/// Manages video player state and operations for scene playback.
@MainActor
@Observable
final class ScenePlayerManager {
    
    // MARK: - State
    
    /// Represents the player state and stream selection.
    struct PlayerState: Equatable {
        var player: AVPlayer?
        var isLoaded: Bool
        var availableStreams: [SceneStreamEndpoint]
        var selectedStream: SceneStreamEndpoint?
        var isLoadingStreams: Bool
        
        static var initial: PlayerState {
            PlayerState(
                player: nil,
                isLoaded: false,
                availableStreams: [],
                selectedStream: nil,
                isLoadingStreams: false
            )
        }
        
        static func == (lhs: PlayerState, rhs: PlayerState) -> Bool {
            lhs.isLoaded == rhs.isLoaded &&
            lhs.availableStreams == rhs.availableStreams &&
            lhs.selectedStream == rhs.selectedStream &&
            lhs.isLoadingStreams == rhs.isLoadingStreams
        }
    }
    
    private(set) var state: PlayerState = .initial
    
    // MARK: - Dependencies
    
    private let sceneRepository: any SceneRepositoryProtocol
    private let settings: SettingsStoreProtocol
    private var playbackTracker: PlaybackTracker?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Convenience Properties
    
    var player: AVPlayer? { state.player }
    var isLoaded: Bool { state.isLoaded }
    var availableStreams: [SceneStreamEndpoint] { state.availableStreams }
    var selectedStream: SceneStreamEndpoint? { state.selectedStream }
    var isLoadingStreams: Bool { state.isLoadingStreams }
    
    // MARK: - Initialization
    
    init(
        sceneRepository: any SceneRepositoryProtocol,
        settings: SettingsStoreProtocol
    ) {
        self.sceneRepository = sceneRepository
        self.settings = settings
    }
    
    // MARK: - Player Setup
    
    /// Sets up the video player for the given scene.
    func setupPlayer(for scene: Scene) {
        let streamPath: String?
        
        if let selected = state.selectedStream {
            streamPath = selected.url
            Logger.scenes.debug("🎬 Using selected stream: \(selected.displayLabel, privacy: .public)")
        } else {
            streamPath = scene.paths?.stream
            Logger.scenes.debug("🎬 Using default stream path: \(streamPath ?? "none", privacy: .public)")
        }
        
        guard let path = streamPath else {
            Logger.scenes.warning("⚠️ No stream path found for scene")
            return
        }
        
        guard let streamUrl = settings.createImageUrl(path: path) else {
            Logger.scenes.error("❌ Failed to generate stream URL for path: \(path, privacy: .public)")
            return
        }
        
        Logger.scenes.info("🎬 Generated stream URL: \(streamUrl.absoluteString, privacy: .public)")
        
        // Check if we already have a player with the same URL to prevent restarting
        if let currentPlayer = state.player,
           let currentItem = currentPlayer.currentItem,
           let asset = currentItem.asset as? AVURLAsset,
           asset.url == streamUrl {
            Logger.scenes.info("🎬 Player already exists with same URL, skipping recreation")
            return
        }
        
        // Create asset and load it asynchronously to avoid blocking
        let asset = AVURLAsset(url: streamUrl)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        state.player = newPlayer
        state.isLoaded = false
        
        // DEBUG: Log resume time from scene
        Logger.scenes.debug("🎬 Scene resume_time from model: \(scene.resume_time ?? 0) seconds")
        
        // Setup Playback Tracking
        if let stashUrl = settings.url {
            let tracker = PlaybackTracker(
                sceneId: scene.id,
                player: newPlayer,
                url: stashUrl,
                apiKey: settings.apiKey
            )
            
            // Sync resume time to local database when tracker saves activity
            tracker.onSaveActivity = { [weak self] resumeTime in
                guard let self = self else { return }
                let sceneId = scene.id
                
                Task {
                    do {
                        // Fetch latest scene data to avoid overwriting other changes
                        if var latestScene = try await self.sceneRepository.getById(sceneId) {
                            latestScene.resume_time = resumeTime
                            try await self.sceneRepository.saveScene(latestScene)
                            Logger.scenes.debug("💾 Synced resume time to local DB: \(resumeTime)")
                            
                            // Notify observers to update UI (scene list, home screen)
                            NotificationCenter.default.post(
                                name: .sceneUpdated,
                                object: nil,
                                userInfo: ["id": sceneId]
                            )
                        }
                    } catch {
                        Logger.scenes.error("❌ Failed to sync local resume time: \(error.localizedDescription)")
                    }
                }
            }
            
            playbackTracker = tracker
        } else {
            Logger.scenes.error("❌ Cannot start playback tracking: Server URL not configured")
        }
        
        // Seek to resume time if available and greater than 0
        // But only if we are using the default stream (initial load), 
        // to avoid resetting time when switching streams manually.
        // Seek to resume time if available and greater than 0
        // Wait for player to be ready before seeking for reliable behavior
        if state.selectedStream == nil, let resumeTime = scene.resume_time, resumeTime > 0 {
             Logger.scenes.info("🎬 Queueing resume at \(resumeTime) seconds")
             
             newPlayer.publisher(for: \.status)
                 .filter { $0 == .readyToPlay }
                 .first() // Only trigger once
                 .sink { [weak newPlayer] _ in
                     guard let player = newPlayer else { return }
                     Logger.scenes.info("🎬 Player ready, seeking to \(resumeTime) seconds")
                     let seekTime = CMTime(seconds: resumeTime, preferredTimescale: 600)
                     player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                 }
                 .store(in: &cancellables)
        }
    }
    
    /// Recreates the video player if it was cleaned up.
    func recreatePlayerIfNeeded(for scene: Scene) {
        guard player == nil else { return }
        Logger.scenes.info("🎬 Recreating player after navigation")
        setupPlayer(for: scene)
    }
    
    /// Sets the player loaded state.
    func setPlayerLoaded(_ isLoaded: Bool) {
        state.isLoaded = isLoaded
    }
    
    // MARK: - Stream Management
    
    /// Fetches all available streaming endpoints for the current scene.
    func fetchAvailableStreams(sceneId: String, currentStreamPath: String?) async {
        state.isLoadingStreams = true
        
        defer {
            state.isLoadingStreams = false
        }
        
        do {
            let streams = try await sceneRepository.getSceneStreams(id: sceneId)
            
            state.availableStreams = streams
            
            // If we don't have a selected stream yet, try to find the best match for the current player
            if state.selectedStream == nil, let currentStream = currentStreamPath {
                state.selectedStream = streams.first(where: { $0.url == currentStream })
            }
            
            Logger.scenes.info("🎬 Found \(streams.count) available streams")
        } catch {
            Logger.scenes.error("❌ Failed to fetch available streams: \(error.localizedDescription)")
        }
    }
    
    /// Switches the player to a specific stream endpoint.
    func selectStream(_ endpoint: SceneStreamEndpoint, scene: Scene) {
        Logger.scenes.info("🎬 Switching to stream: \(endpoint.displayLabel)")
        
        // Save current time if playing
        let currentTime = state.player?.currentTime()
        
        // Update selected stream
        state.selectedStream = endpoint
        
        // Re-setup player
        setupPlayer(for: scene)
        
        // Restore time and playback state
        if let time = currentTime {
            state.player?.seek(to: time)
        }
        
        if state.isLoaded {
            state.player?.play()
        }
        
        HapticManager.selection()
    }
    
    // MARK: - Cleanup
    
    /// Cleans up resources, such as pausing and releasing the video player.
    func cleanup() {
        cancellables.removeAll()
        playbackTracker = nil // Tracking stops on deinit
        state.player?.pause()
        state.player?.replaceCurrentItem(with: nil)
        state.player = nil
        state.isLoaded = false
    }
}
