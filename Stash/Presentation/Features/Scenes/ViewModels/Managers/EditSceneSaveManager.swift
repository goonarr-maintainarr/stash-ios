import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditSceneSaveManager")

/// Manages saving scene edits to the repository.
@MainActor
@Observable
class EditSceneSaveManager: ErrorStateManaging {
    
    // MARK: - Observable Properties
    
    var isSaving = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let sceneId: String
    private let repository: any SceneRepositoryProtocol
    
    // MARK: - Initialization
    
    init(sceneId: String, repository: any SceneRepositoryProtocol) {
        self.sceneId = sceneId
        self.repository = repository
        
        logger.debug("🔧 EditSceneSaveManager initialized for scene: \(sceneId)")
    }
    
    // MARK: - Public Methods
    
    /// Saves all changes to the server.
    func save(
        title: String,
        details: String,
        performerIds: [String],
        tagIds: [String],
        removedOHistory: [String],
        removedPlayHistory: [String],
        director: String?,
        code: String?,
        url: String?
    ) async -> Bool {
        isSaving = true
        clearError()
        
        logger.info("💾 Starting save for scene \(self.sceneId, privacy: .public)")
        
        do {
            // Delete removed O history entries
            if !removedOHistory.isEmpty {
                logger.debug("🗑️ Deleting \(removedOHistory.count) O-counter entries")
                try await repository.deleteOHistory(sceneId: sceneId, times: removedOHistory)
            }
            
            // Delete removed Play history entries
            if !removedPlayHistory.isEmpty {
                logger.debug("🗑️ Deleting \(removedPlayHistory.count) play history entries")
                try await repository.deletePlayHistory(sceneId: sceneId, times: removedPlayHistory)
            }
            
            // Update other scene details
            logger.debug("📝 Updating scene metadata")
            _ = try await repository.updateScene(
                id: sceneId,
                title: title,
                details: details,
                performerIds: performerIds,
                tagIds: tagIds,
                coverImage: nil,
                director: director,
                code: code,
                url: url
            )
            
            // Notify details view
            logger.debug("📢 Posting scene updated notification")
            let sceneId = self.sceneId
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .sceneUpdated,
                    object: nil,
                    userInfo: ["id": sceneId]
                )
            }
            
            // Success
            isSaving = false
            logger.info("✅ Successfully saved scene \(self.sceneId, privacy: .public)")
            return true
            
        } catch {
            setError("Failed to save changes: \(error.localizedDescription)")
            isSaving = false
            logger.error("❌ Save failed: \(error.localizedDescription)")
            return false
        }
    }
}
