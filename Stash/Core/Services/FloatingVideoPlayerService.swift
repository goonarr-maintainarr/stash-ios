import Observation
import SwiftUI
import AVKit
import Combine
import os

// Global logger for playback tracking
nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "FloatingVideoPlayerService")

/// Manages the state and positioning of a "Picture-in-Picture" style floating video player.
/// This service ensures that only one scene is being previewed or played at a time.
@MainActor
@Observable
class FloatingVideoPlayerService {
    
    /// The singleton instance for global access
    public static let shared = FloatingVideoPlayerService()
    
    private let settings: any SettingsStoreProtocol
    
    // MARK: - Observable State
    
    /// Whether the floating player is currently visible and active
    var isPlaying = false
    
    /// The underlying AVPlayer instance
    var currentPlayer: AVPlayer?
    
    /// The scene metadata currently being played
    var currentScene: Scene?
    
    /// The current position of the floating window
    var playerPosition: CGPoint = .zero
    
    /// Whether the user is currently dragging the player window
    var isDragging = false
    
    // MARK: - Initialization
    
    private init(settings: any SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        // Initialize player position to bottom-right corner
        playerPosition = calculateInitialPosition()
        logger.debug("🎬 FloatingVideoPlayerService initialized")
    }
    
    
    // MARK: - Public API
    
    /// Starts playback for a specific scene.
    /// - Parameters:
    ///   - player: The player to manage
    ///   - scene: The scene metadata associated with the video
    func startPlaying(player: AVPlayer, scene: Scene) {
        logger.info("▶️ Starting playback for scene: \(scene.title ?? "Unknown", privacy: .public)")
        
        self.currentPlayer = player
        self.currentScene = scene
        self.isPlaying = true
        player.play()
        
        setupPlayerObservers(player)
    }
    
    /// Stops playback and cleans up resources.
    func stopPlaying() {
        if let title = currentScene?.title {
            logger.info("⏹️ Stopping playback for scene: \(title, privacy: .public)")
        }
        
        currentPlayer?.pause()
        currentPlayer?.replaceCurrentItem(with: nil)
        currentPlayer = nil
        currentScene = nil
        isPlaying = false
    }
    
    /// Explicitly sets the playing state to true (used when returning from full screen)
    func minimize() {
        isPlaying = true
    }
    
    /// Toggles between play and pause states
    func togglePlayback() {
        guard let player = currentPlayer else {
            return
        }
        if player.rate > 0 {
            player.pause()
            logger.debug("⏸️ Playback paused")
        } else {
            player.play()
            logger.debug("▶️ Playback resumed")
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupPlayerObservers(_ player: AVPlayer) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            logger.info("🏁 Video reached end of playback")
            player.seek(to: .zero)
            player.pause()
        }
    }
    
    private func calculateInitialPosition() -> CGPoint {
        let screenSize: CGSize
        
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            screenSize = windowScene.screen.bounds.size
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenSize = windowScene.screen.bounds.size
        } else {
            screenSize = CGSize(width: 393, height: 852) // iPhone 15 size
        }
        
        let playerWidth: CGFloat = 224
        let playerHeight: CGFloat = 126
        let padding: CGFloat = 4
        
        return CGPoint(
            x: screenSize.width - playerWidth - padding,
            y: screenSize.height - playerHeight - padding - 100 // Account for tab bar
        )
    }
}
