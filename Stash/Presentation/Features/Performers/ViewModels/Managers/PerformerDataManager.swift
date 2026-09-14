import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerDataManager")

/// Manages performer and scene data fetching with caching.
@MainActor
@Observable
class PerformerDataManager {
    
    // MARK: - Observable State
    
    /// The loading state of the scenes section (for lazy loading).
    var scenesLoadState: PerformerScenesLoadState = .idle
    
    // MARK: - Dependencies
    
    private let repository: any PerformerRepositoryProtocol
    private let database: StashDatabase
    private let settings: SettingsStoreProtocol
    
    // MARK: - Private State
    
    var allFetchedScenes: [Scene] = []
    
    // MARK: - Initialization
    
    init(repository: any PerformerRepositoryProtocol, database: StashDatabase, settings: SettingsStoreProtocol) {
        self.repository = repository
        self.database = database
        self.settings = settings
        logger.debug("🔧 PerformerDataManager initialized")
    }
    
    /// Fetches performer details with stale-while-revalidate support.
    func fetchPerformerDetails(
        id: String,
        forceRefresh: Bool = false,
        onFreshData: ((Performer, [Scene]) -> Void)? = nil
    ) async throws -> (Performer, [Scene]) {
        logger.debug("🔍 Fetching performer details for ID: \(id) (Force Refresh: \(forceRefresh))")

        // If forceRefresh, skip cache and wait for API
        if forceRefresh {
            guard let fresh = try await repository.getPerformer(id: id, forceRefresh: true) else {
                logger.error("❌ Failed to fetch performer from API")
                throw AppError.notFound("Performer not found")
            }
            logger.info("🔄 Fetched fresh performer from API: \(fresh.performer.name ?? "Unknown")")
            allFetchedScenes = fresh.scenes
            return fresh
        }

        // Try to load from repository (which handles cache vs API logic)
        // Pass forceRefresh: false to get cached version first
        if let cached = try await repository.getPerformer(id: id, forceRefresh: false) {
            logger.info("⚡️ Showing cached performer: \(cached.performer.name ?? "Unknown")")
            allFetchedScenes = cached.scenes
            scenesLoadState = .loaded
            
            // Launch background fetch for fresh data
            Task {
                do {
                    if let fresh = try await repository.getPerformer(id: id, forceRefresh: true) {
                        logger.debug("🔄 Background refresh complete: \(fresh.performer.name ?? "Unknown")")
                        self.allFetchedScenes = fresh.scenes
                        await MainActor.run {
                            onFreshData?(fresh.performer, fresh.scenes)
                        }
                    }
                } catch {
                    logger.warning("⚠️ Background refresh failed: \(error.localizedDescription)")
                    // Silently fail - we already have cached data showing
                }
            }
            return cached
        }
        
        // No cache, wait for API
        logger.info("📡 No cache available, fetching from API...")
        scenesLoadState = .loading
        do {
            guard let fresh = try await repository.getPerformer(id: id, forceRefresh: true) else {
                logger.error("❌ Failed to fetch performer from API")
                throw AppError.notFound("Performer not found")
            }
            logger.info("✅ Loaded performer from API: \(fresh.performer.name ?? "Unknown")")
            allFetchedScenes = fresh.scenes
            scenesLoadState = .loaded
            return fresh
        } catch {
            logger.error("❌ Failed to fetch performer: \(error.localizedDescription)")
            scenesLoadState = .error("Failed to load performer")
            throw error
        }
    }
    
    /// Deletes performer from server and cache.
    func deletePerformer(id: String) async throws {
        guard settings.url != nil else {
            throw AppError.validation(.custom("Invalid Server URL"))
        }
        
        logger.info("🗑️ Deleting performer: \(id, privacy: .public)")
        let success = try await repository.deletePerformer(id: id)
        if !success {
            throw AppError.repository(.syncFailed("Failed to delete performer"))
        }
        logger.info("✅ Performer deleted successfully")
    }
    
    /// Updates a specific scene in the fetched list.
    func updateScene(_ scene: Scene) {
        if let index = allFetchedScenes.firstIndex(where: { $0.id == scene.id }) {
            allFetchedScenes[index] = scene
            logger.info("🔄 Updated scene in list: \(scene.id, privacy: .public)")
        }
    }
}
