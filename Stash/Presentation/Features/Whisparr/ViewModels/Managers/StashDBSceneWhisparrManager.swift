import Observation
import os
import Foundation

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBSceneWhisparrManager")

/// Manages adding StashDB scenes to Whisparr.
@MainActor
@Observable
class StashDBSceneWhisparrManager {
    
    // MARK: - State
    
    var operationState: StashDBSceneOperationState = .idle
    
    // MARK: - Dependencies
    
    private let whisparrRepository: WhisparrRepositoryProtocol
    private let whisparrDatabase: WhisparrDatabase
    private let settings: SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(
        whisparrRepository: WhisparrRepositoryProtocol,
        whisparrDatabase: WhisparrDatabase,
        settings: SettingsStoreProtocol
    ) {
        self.whisparrRepository = whisparrRepository
        self.whisparrDatabase = whisparrDatabase
        self.settings = settings
        logger.debug("🔧 StashDBSceneWhisparrManager initialized")
    }
    
    // MARK: - Operations
    
    /// Adds scene to Whisparr.
    func addToWhisparr(sceneId: String) async -> Bool {
        logger.info("➕ Adding scene \(sceneId) to Whisparr")
        operationState = .adding
        
        do {
            // Lookup scene in Whisparr
            guard let lookedUpScene = try await whisparrRepository.lookupScene(stashId: sceneId) else {
                logger.error("❌ Scene not found in Whisparr's StashDB")
                operationState = .error("Scene not found in Whisparr's StashDB. Make sure Whisparr has StashDB configured.")
                return false
            }
            
            // Add to Whisparr
            let addedMovie = try await whisparrRepository.addScene(
                lookupScene: lookedUpScene,
                qualityProfileId: settings.whisparrQualityProfileId,
                rootFolderPath: settings.whisparrRootFolderPath
            )
            
            // Save to local database
            try await whisparrDatabase.saveScenes([addedMovie])
            logger.info("✅ Scene added to Whisparr successfully")
            
            // Notify
            NotificationCenter.default.post(name: .whisparrLibraryChanged, object: nil)
            
            operationState = .success("Added to Whisparr")
            
            // Background refresh
            Task.detached(priority: .background) {
                do {
                    try await self.whisparrRepository.refreshScene(sceneId: addedMovie.id)
                } catch {
                    logger.error("⚠️ Failed to trigger background refresh: \(error.localizedDescription)")
                }
            }
            
            // Hide toast
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            operationState = .idle
            return true
            
        } catch {
            logger.error("❌ Failed to add to Whisparr: \(error.localizedDescription)")
            operationState = .error("Failed to add to Whisparr: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Operation State

enum StashDBSceneOperationState: Equatable {
    case idle
    case adding
    case success(String)
    case error(String)
}
