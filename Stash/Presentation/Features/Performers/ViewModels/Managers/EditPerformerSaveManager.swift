import Observation
import Foundation
import Nuke
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditPerformerSaveManager")

/// Manages save operations for performer edits.
@MainActor
@Observable
class EditPerformerSaveManager {
    
    // MARK: - Dependencies
    
    private let performerRepository: any PerformerRepositoryProtocol
    
    // MARK: - Initialization
    
    init(performerRepository: any PerformerRepositoryProtocol) {
        self.performerRepository = performerRepository
        logger.debug("🔧 EditPerformerSaveManager initialized")
    }
    
    // MARK: - Save
    
    func savePerformer(input: PerformerUpdateInput) async throws {
        logger.info("💾 Saving performer: \(input.name)")
        
        do {
            _ = try await performerRepository.updatePerformer(input: input)
            logger.info("✅ Performer saved successfully")
            
            invalidateCache(for: input.id)
            postUpdateNotification(for: input.id)
            
        } catch {
            logger.error("❌ Failed to save performer: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
    
    // MARK: - Cache Invalidation
    
    private func invalidateCache(for performerId: String) {
        logger.info("🗑️ Invalidating image cache for performer \(performerId)")
        
        let pipeline = ImagePipeline.shared
        pipeline.cache.removeAll()
        
        logger.debug("✅ Cache invalidated")
    }
    
    // MARK: - Notifications
    
    private func postUpdateNotification(for performerId: String) {
        logger.info("📢 Posting performer updated notification")
        NotificationCenter.default.post(
            name: .performerUpdated,
            object: nil,
            userInfo: [
                "id": performerId,
                "performerId": performerId
            ]
        )
    }
}
