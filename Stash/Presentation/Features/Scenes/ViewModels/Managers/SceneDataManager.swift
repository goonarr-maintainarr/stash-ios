import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneDataManager")

/// Manages scene data fetching, merging, and caching.
@MainActor
class SceneDataManager {
    
    // MARK: - Dependencies
    
    private let sceneRepository: any SceneRepositoryProtocol
    
    // MARK: - Initialization
    
    init(sceneRepository: any SceneRepositoryProtocol) {
        self.sceneRepository = sceneRepository
        logger.debug("🔧 SceneDataManager initialized")
    }
    
    /// Fetches complete scene details using cache-first, background-refresh pattern.
    ///
    /// - Shows cached data immediately if available
    /// - Always fetches fresh data from API in background
    /// - Calls onFreshData when background fetch completes (for silent UI update)
    /// - If no cache exists, shows loading state until API returns
    func fetchSceneDetails(id: String, forceRefresh: Bool = false, onFreshData: ((Scene) -> Void)? = nil) async throws -> Scene {
        logger.debug("🔍 Fetching scene details for ID: \(id) (Force Refresh: \(forceRefresh))")
        
        // If forceRefresh, skip cache and wait for API
        if forceRefresh {
            guard let freshScene = try await sceneRepository.getScene(id: id, forceRefresh: true) else {
                logger.error("❌ Failed to fetch scene from API")
                throw AppError.notFound("Scene not found")
            }
            logger.info("🔄 Fetched fresh scene from API: \(freshScene.title ?? "Unknown")")
            return freshScene
        }
        
        // Try to load from cache first
        if let cachedScene = try await sceneRepository.getScene(id: id, forceRefresh: false) {
            logger.info("⚡️ Showing cached scene: \(cachedScene.title ?? "Unknown")")
            
            // Background refresh - fetch from API and update silently via callback
            Task {
                do {
                    if let freshScene = try await sceneRepository.getScene(id: id, forceRefresh: true) {
                        logger.debug("🔄 Background refresh complete: \(freshScene.title ?? "Unknown")")
                        // Call the closure to update UI silently (no notification to avoid list reload)
                        await MainActor.run {
                            onFreshData?(freshScene)
                        }
                    }
                } catch {
                    logger.warning("⚠️ Background refresh failed: \(error.localizedDescription)")
                    // Silently fail - we already have cached data showing
                }
            }
            
            return cachedScene
        }
        
        // No cache - must wait for API
        logger.info("📡 No cache available, fetching from API...")
        guard let scene = try await sceneRepository.getScene(id: id, forceRefresh: true) else {
            logger.error("❌ Failed to fetch scene from API")
            throw AppError.notFound("Scene not found")
        }
        
        logger.info("✅ Loaded scene from API: \(scene.title ?? "Unknown")")
        return scene
    }
    
}
