import Foundation
import os

/// Service responsible for write and mutation operations on Whisparr scenes.
///
/// This service handles all operations that modify scenes on the Whisparr server,
/// including updates, deletions, additions, and file management.
class WhisparrMutationService: @unchecked Sendable {
    private let apiClient: WhisparrClientProtocol
    private let cacheService: WhisparrCacheService
    private let settings: any SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrMutationService")
    
    init(apiClient: WhisparrClientProtocol, cacheService: WhisparrCacheService, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.cacheService = cacheService
        self.settings = settings
    }
    
    
    // MARK: - Configuration Validation
    
    // MARK: - Scene Mutations
    
    /// Updates a scene's monitoring status, quality profile, and root folder.
    ///
    /// - Parameters:
    ///   - scene: The `WhisparrScene` object to update.
    ///   - monitored: The new monitored status.
    ///   - qualityProfileId: The ID of the new quality profile.
    ///   - rootFolderPath: The path of the new root folder.
    /// - Returns: The updated `WhisparrScene`.
    /// - Throws: `RepositoryError` if configuration is invalid or update fails.
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let updatedScene = try await apiClient.updateScene(
                scene: scene,
                monitored: monitored,
                qualityProfileId: qualityProfileId,
                rootFolderPath: rootFolderPath,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            
            // Save to database to ensure consistency
            try await cacheService.saveScenes([updatedScene])
            
            NotificationCenter.default.post(
                name: .whisparrMovieUpdated,
                object: nil,
                userInfo: ["movieId": scene.id, "movie": updatedScene]
            )
            
            return updatedScene
        } catch {
            throw error
        }
    }
    
    /// Updates a scene using the editor endpoint (supports moving files for root folder changes).
    ///
    /// - Parameters:
    ///   - scene: The `WhisparrScene` object to update.
    ///   - monitored: The new monitored status.
    ///   - qualityProfileId: The ID of the new quality profile.
    ///   - rootFolderPath: The path of the new root folder.
    ///   - moveFiles: Whether to move files when changing root folder (nil = don't move).
    /// - Returns: The updated `WhisparrScene`.
    /// - Throws: `RepositoryError` if configuration is invalid or update fails.
    func updateSceneUsingEditor(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, moveFiles: Bool?) async throws -> WhisparrScene {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let updatedScene = try await apiClient.updateSceneUsingEditor(
                scene: scene,
                monitored: monitored,
                qualityProfileId: qualityProfileId,
                rootFolderPath: rootFolderPath,
                moveFiles: moveFiles,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            
            // Save to database to ensure consistency
            try await cacheService.saveScenes([updatedScene])
            
            NotificationCenter.default.post(
                name: .whisparrMovieUpdated,
                object: nil,
                userInfo: ["movieId": scene.id, "movie": updatedScene]
            )
            
            return updatedScene
        } catch {
            throw error
        }
    }
    
    /// Toggles the monitoring status of a scene in Whisparr.
    ///
    /// - Parameter scene: The `WhisparrScene` object to update.
    /// - Returns: The updated `WhisparrScene`.
    /// - Throws: `RepositoryError` if configuration is invalid or update fails.
    func toggleMonitorStatus(scene: WhisparrScene) async throws -> WhisparrScene {
        
        // Ensure defaults if missing
        let profileId = scene.qualityProfileId ?? 1
        let rootPath = scene.rootFolderPath ?? ""
        
        
        // Use updateScene to handle logic and persistence
        return try await updateScene(
            scene: scene,
            monitored: !scene.monitored,
            qualityProfileId: profileId,
            rootFolderPath: rootPath
        )
    }
    
    /// Deletes a scene from Whisparr and optionally the associated files.
    ///
    /// Performs an optimistic delete from the local database first, then attempts the API call.
    /// If the API call fails, it restores the local data using the provided backup copy.
    ///
    /// - Parameters:
    ///   - scene: The `WhisparrScene` object to delete.
    ///   - deleteFiles: Whether to delete the video files on disk.
    ///   - addImportExclusion: Whether to prevent this scene from being re-imported.
    /// - Throws: An error if the API call fails (and restoration fails).
    func deleteScene(scene: WhisparrScene, deleteFiles: Bool, addImportExclusion: Bool) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        let sceneId = scene.id
        
        // Optimistic local delete
        do {
            try await cacheService.deleteScene(id: sceneId)
            logger.info("Optimistically deleted movie \(sceneId) from local database")
        } catch {
            logger.error("Failed to delete from local database: \(error)")
        }
        
        NotificationCenter.default.post(
            name: .whisparrMovieDeleted,
            object: nil,
            userInfo: ["movieId": sceneId]
        )
        
        do {
            try await apiClient.deleteScene(
                sceneId: sceneId,
                deleteFiles: deleteFiles,
                addImportExclusion: addImportExclusion,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            logger.info("Successfully removed movie \(sceneId) from Whisparr")
        } catch {
            logger.error("Failed to remove from Whisparr: \(error)")
            
            // Restore
            do {
                try await cacheService.saveScenes([scene])
                logger.info("Restored movie \(sceneId) to local database after API error")
                
                NotificationCenter.default.post(
                    name: .whisparrMovieUpdated,
                    object: nil,
                    userInfo: ["movieId": sceneId, "movie": scene]
                )
            } catch {
                logger.error("Failed to restore movie to database: \(error)")
            }
            
            throw error
        }
    }
    
    /// Deletes a scene file from Whisparr.
    ///
    /// - Parameter fileId: The ID of the file to delete.
    /// - Throws: `RepositoryError` if configuration is invalid or delete fails.
    func deleteSceneFile(fileId: Int) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            try await apiClient.deleteSceneFile(
                fileId: fileId,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
        } catch {
            throw error
        }
    }
    
    /// Adds a movie to Whisparr.
    ///
    /// - Parameters:
    ///   - lookupScene: The lookup result to add.
    ///   - qualityProfileId: The ID of the quality profile to use.
    ///   - rootFolderPath: The path of the root folder to use.
    /// - Returns: The newly created `WhisparrScene`.
    /// - Throws: `RepositoryError` if configuration is invalid or request fails.
    func addScene(lookupScene: WhisparrLookupScene, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            // Use default empty tags
            let addedScene = try await apiClient.addScene(
                lookupScene: lookupScene,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey,
                qualityProfileId: qualityProfileId,
                rootFolderPath: rootFolderPath,
                tags: []
            )
            
            
            // Save to database
            try await cacheService.saveScenes([addedScene])
            
            // Notify
            NotificationCenter.default.post(
                name: .whisparrMovieUpdated,
                object: nil,
                userInfo: ["movieId": addedScene.id, "movie": addedScene]
            )
            
            return addedScene
        } catch {
            throw error
        }
    }
    
    /// Refreshes the metadata for a specific scene in Whisparr.
    ///
    /// - Parameter sceneId: The ID of the scene to refresh.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func refreshScene(sceneId: Int) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            try await apiClient.refreshScene(
                sceneId: sceneId,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
        } catch {
            throw error
        }
    }
    
    /// Triggers a refresh of all monitored downloads.
    ///
    /// - Throws: `RepositoryError` if configuration is invalid.
    func refreshDownloads() async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            try await apiClient.refreshDownloads(
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
        } catch {
            throw error
        }
    }
}
