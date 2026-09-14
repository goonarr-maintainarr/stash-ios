import Foundation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerNotificationManager")

/// Manages NotificationCenter observers for performer and scene updates.
@MainActor
class PerformerNotificationManager {
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    private var onPerformerUpdated: ((String) -> Void)?
    private var onSceneUpdated: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 PerformerNotificationManager initialized")
        setupNotificationObservers()
    }
    
    // MARK: - Setup
    
    /// Sets up callback handlers for notifications.
    func setupCallbacks(
        onPerformerUpdated: @escaping (String) -> Void,
        onSceneUpdated: @escaping (String) -> Void
    ) {
        logger.debug("🔗 Setting up notification callbacks")
        self.onPerformerUpdated = onPerformerUpdated
        self.onSceneUpdated = onSceneUpdated
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        logger.debug("📡 Setting up notification observers")
        
        // Listen for performer updates
        NotificationCenter.default.publisher(for: .performerUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let performerId = notification.userInfo?["performerId"] as? String {
                    logger.info("📢 Performer updated: \(performerId, privacy: .public)")
                    self?.onPerformerUpdated?(performerId)
                }
            }
            .store(in: &cancellables)
        
        // Listen for scene updates
        NotificationCenter.default.publisher(for: .sceneUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let sceneId = notification.userInfo?["id"] as? String {
                    logger.info("📢 Scene updated: \(sceneId, privacy: .public)")
                    self?.onSceneUpdated?(sceneId)
                }
            }
            .store(in: &cancellables)
        
        logger.info("✅ Notification observers set up successfully")
    }
}
