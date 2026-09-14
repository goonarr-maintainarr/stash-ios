import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneOperationsManager")

/// Manages scene operations like delete, rating, O-counter, and title updates.
@MainActor
class SceneOperationsManager {
    
    // MARK: - Dependencies
    
    private let sceneRepository: any SceneRepositoryProtocol
    private let settings: SettingsStoreProtocol
    private let whisparrIntegration: SceneWhisparrIntegration
    
    // MARK: - Initialization
    
    init(
        sceneRepository: any SceneRepositoryProtocol,
        settings: SettingsStoreProtocol,
        whisparrIntegration: SceneWhisparrIntegration
    ) {
        self.sceneRepository = sceneRepository
        self.settings = settings
        self.whisparrIntegration = whisparrIntegration
        logger.debug("🔧 SceneOperationsManager initialized")
    }
    
    // MARK: - Delete
    
    /// Deletes a scene and optionally its files.
    func deleteScene(
        id: String,
        stashId: String?,
        deleteFile: Bool,
        deleteGenerated: Bool
    ) async throws -> Bool {
        logger.info("🗑️ Deleting scene \(id), deleteFile: \(deleteFile), deleteGenerated: \(deleteGenerated)")
        
        do {
            let success = try await sceneRepository.deleteScene(
                id: id,
                deleteFile: deleteFile,
                deleteGenerated: deleteGenerated
            )
            
            if success {
                logger.info("✅ Scene deleted successfully")
                NotificationCenter.default.post(name: .stashDatabaseChanged, object: nil)
                
                // Refresh Whisparr if the scene exists there
                if let stashId = stashId, !settings.whisparrUrl.isEmpty {
                    Task.detached(priority: .background) {
                        await self.whisparrIntegration.refreshWhisparrScene(stashId: stashId)
                    }
                }
            }
            
            return success
        } catch {
            logger.error("❌ Failed to delete scene: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
    
    // MARK: - O-Counter
    
    /// Increments the O-Counter for a scene with optimistic update.
    func incrementOCounter(for scene: Scene) async throws -> Scene {
        logger.info("➕ Incrementing O-Counter for scene \(scene.id)")
        
        let previousValue = scene.o_counter
        
        do {
            let updated = try await sceneRepository.incrementOCounter(
                for: scene.id,
                currentCount: previousValue
            )
            logger.info("✅ O-Counter incremented to \(updated.o_counter ?? 0)")
            return updated
        } catch {
            logger.error("❌ Failed to increment O-Counter: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
    
    // MARK: - Rating
    
    /// Updates the rating for a scene with optimistic update.
    func updateRating(for scene: Scene, rating: Int) async throws -> Scene {
        logger.info("⭐️ Updating rating for scene \(scene.id) to \(rating)")
        
        do {
            let updated = try await sceneRepository.updateRating(
                for: scene.id,
                rating: rating
            )
            logger.info("✅ Rating updated successfully")
            return updated
        } catch {
            logger.error("❌ Failed to update rating: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
    
    // MARK: - Title
    
    /// Updates the title for a scene.
    func updateTitle(for sceneId: String, title: String) async throws -> Scene {
        logger.info("✏️ Updating title for scene \(sceneId)")
        
        do {
            let updated = try await sceneRepository.updateTitle(
                for: sceneId,
                title: title
            )
            logger.info("✅ Title updated successfully")
            return updated
        } catch {
            logger.error("❌ Failed to update title: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
}
