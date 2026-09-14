import Foundation
import Combine
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrLiveUpdatesManager")

/// Manages live updates for Whisparr scenes via NotificationCenter.
@MainActor
@Observable
class WhisparrLiveUpdatesManager {
    
    // MARK: - State
    
    /// Indicates if a live update triggered a refresh request.
    var shouldRefresh = false
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onSceneUpdated: ((WhisparrScene) -> Void)?
    var onSceneRefreshNeeded: ((Int) -> Void)?
    var onSceneDeleted: ((Int) -> Void)?
    var onLibraryChanged: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 WhisparrLiveUpdatesManager initialized")
        setupNotificationObservers()
    }
    
    // MARK: - Setup
    
    /// Sets up callback handlers for live updates.
    ///
    /// - Parameters:
    ///   - onSceneUpdated: Called when a single scene is updated.
    ///   - onSceneDeleted: Called when a scene is deleted.
    ///   - onSceneRefreshNeeded: Called when a scene needs to be refreshed from API.
    ///   - onSceneDeleted: Called when a scene is deleted.
    ///   - onLibraryChanged: Called when the entire library should be refreshed.
    func setupCallbacks(
        onSceneUpdated: @escaping (WhisparrScene) -> Void,
        onSceneRefreshNeeded: @escaping (Int) -> Void,
        onSceneDeleted: @escaping (Int) -> Void,
        onLibraryChanged: @escaping () -> Void
    ) {
        logger.debug("🔗 Setting up live update callbacks")
        self.onSceneUpdated = onSceneUpdated
        self.onSceneRefreshNeeded = onSceneRefreshNeeded
        self.onSceneDeleted = onSceneDeleted
        self.onLibraryChanged = onLibraryChanged
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        logger.debug("📡 Setting up notification observers")
        
        // Listen for Whisparr library changes to auto-refresh
        NotificationCenter.default.publisher(for: .whisparrLibraryChanged)
            .sink { [weak self] _ in
                logger.info("📢 Whisparr library changed notification received")
                Task { @MainActor [weak self] in
                    self?.handleLibraryChanged()
                }
            }
            .store(in: &cancellables)
        
        // Listen for individual scene updates (e.g., download completed)
        NotificationCenter.default.publisher(for: .whisparrMovieUpdated)
            .sink { [weak self] notification in
                guard let self = self,
                      let sceneId = notification.userInfo?["movieId"] as? Int else {
                    logger.warning("⚠️ Received scene updated notification with invalid data")
                    return
                }
                
                if let updatedScene = notification.userInfo?["movie"] as? WhisparrScene {
                    logger.info("📢 Scene \(sceneId) updated notification received with object")
                    Task { @MainActor [weak self] in
                        self?.handleSceneUpdated(updatedScene)
                    }
                } else {
                    logger.info("📢 Scene \(sceneId) updated notification received (ID only)")
                    Task { @MainActor [weak self] in
                        self?.onSceneRefreshNeeded?(sceneId)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for scene deletions
        NotificationCenter.default.publisher(for: .whisparrMovieDeleted)
            .sink { [weak self] notification in
                guard let self = self,
                      let sceneId = notification.userInfo?["movieId"] as? Int else {
                    logger.warning("⚠️ Received scene deleted notification with invalid data")
                    return
                }
                logger.info("📢 Scene \(sceneId) deleted notification received")
                Task { @MainActor [weak self] in
                    self?.handleSceneDeleted(sceneId)
                }
            }
            .store(in: &cancellables)
        
        logger.info("✅ Notification observers set up successfully")
    }
    
    // MARK: - Handlers
    
    private func handleLibraryChanged() {
        logger.info("🔄 Handling library changed - triggering full refresh")
        onLibraryChanged?()
    }
    
    private func handleSceneUpdated(_ scene: WhisparrScene) {
        logger.info("🔄 Handling scene updated - ID: \(scene.id), Title: \"\(scene.title, privacy: .public)\", hasFile: \(scene.hasFile)")
        onSceneUpdated?(scene)
    }
    
    private func handleSceneDeleted(_ sceneId: Int) {
        logger.info("🗑️ Handling scene deleted - ID: \(sceneId)")
        onSceneDeleted?(sceneId)
    }
    
    // MARK: - List Updates
    
    /// Updates a single scene in provided lists (displayed, cached, filtered).
    ///
    /// - Parameters:
    ///   - scene: The updated scene.
    ///   - displayedScenes: Inout array of displayed scenes.
    ///   - cachedScenes: Inout array of all cached scenes.
    ///   - filteredScenes: Inout array of filtered scenes.
    func updateSceneInLists(
        _ scene: WhisparrScene,
        displayedScenes: inout [WhisparrScene],
        cachedScenes: inout [WhisparrScene],
        filteredScenes: inout [WhisparrScene]
    ) {
        // Update in displayed scenes
        if let index = displayedScenes.firstIndex(where: { $0.id == scene.id }) {
            let oldHasFile = displayedScenes[index].hasFile
            displayedScenes[index] = scene
            logger.info("✅ Updated scene in displayed list at index \(index) - hasFile: \(oldHasFile) → \(scene.hasFile)")
        } else {
            // Scene doesn't exist yet - add it to the beginning
            displayedScenes.insert(scene, at: 0)
            logger.info("✅ Added new scene to displayed list")
        }
        
        // Update in cached scenes
        if let cacheIndex = cachedScenes.firstIndex(where: { $0.id == scene.id }) {
            cachedScenes[cacheIndex] = scene
            logger.debug("✅ Updated scene in cached list")
        } else {
            cachedScenes.insert(scene, at: 0)
            logger.debug("✅ Added new scene to cached list")
        }
        
        // Update in filtered scenes
        if let filterIndex = filteredScenes.firstIndex(where: { $0.id == scene.id }) {
            filteredScenes[filterIndex] = scene
            logger.debug("✅ Updated scene in filtered list")
        } else {
            filteredScenes.insert(scene, at: 0)
            logger.debug("✅ Added new scene to filtered list")
        }
    }
    
    /// Removes a scene from provided lists (displayed, cached, filtered).
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the scene to remove.
    ///   - displayedScenes: Inout array of displayed scenes.
    ///   - cachedScenes: Inout array of all cached scenes.
    ///   - filteredScenes: Inout array of filtered scenes.
    func removeSceneFromLists(
        sceneId: Int,
        displayedScenes: inout [WhisparrScene],
        cachedScenes: inout [WhisparrScene],
        filteredScenes: inout [WhisparrScene]
    ) {
        // Remove from displayed scenes
        if let index = displayedScenes.firstIndex(where: { $0.id == sceneId }) {
            displayedScenes.remove(at: index)
            logger.info("✅ Removed scene from displayed list at index \(index)")
        }
        
        // Remove from cached scenes
        if let cacheIndex = cachedScenes.firstIndex(where: { $0.id == sceneId }) {
            cachedScenes.remove(at: cacheIndex)
            logger.debug("✅ Removed scene from cached list")
        }
        
        // Remove from filtered scenes
        if let filterIndex = filteredScenes.firstIndex(where: { $0.id == sceneId }) {
            filteredScenes.remove(at: filterIndex)
            logger.debug("✅ Removed scene from filtered list")
        }
    }
}
