import Observation
import os
import Foundation

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBSceneDataManager")

/// Manages StashDB scene data fetching.
@MainActor
@Observable
class StashDBSceneDataManager {
    
    // MARK: - Dependencies
    
    private let stashDBRepository: StashDBRepositoryProtocol
    
    // MARK: - Initialization
    
    init(stashDBRepository: StashDBRepositoryProtocol) {
        self.stashDBRepository = stashDBRepository
        logger.debug("🔧 StashDBSceneDataManager initialized")
    }
    
    // MARK: - Operations
    
    /// Fetches full scene details from StashDB.
    func fetchFullDetails(sceneId: String) async throws -> StashDBScene {
        logger.info("🔍 Fetching full scene details for \(sceneId)")
        
        do {
            let scene = try await stashDBRepository.fetchSceneDetails(id: sceneId)
            logger.info("✅ Fetched scene details")
            return scene
        } catch {
            logger.error("❌ Failed to fetch scene details: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
}
