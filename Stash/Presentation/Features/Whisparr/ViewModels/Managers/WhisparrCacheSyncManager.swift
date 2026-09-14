import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrCacheSyncManager")

/// Manages cache loading, API synchronization, and last sync tracking for Whisparr scenes.
@MainActor
@Observable
class WhisparrCacheSyncManager {
    
    // MARK: - State
    
    /// All cached scenes from the repository (unfiltered).
    var allCachedScenes: [WhisparrScene] = []
    
    /// Date of the last successful sync with the Whisparr API.
    var lastSyncDate: Date?
    
    // MARK: - Dependencies
    
    private let repository: WhisparrRepositoryProtocol
    
    // MARK: - Initialization
    
    init(repository: WhisparrRepositoryProtocol) {
        self.repository = repository
        logger.debug("🔧 WhisparrCacheSyncManager initialized")
    }
    
    // MARK: - Cache Loading
    
    /// Loads all scenes from the local cache.
    func loadFromCache() async throws {
        logger.info("📦 Loading scenes from cache...")
        
        do {
            let cachedScenes = try await repository.getCachedScenes()
            self.allCachedScenes = cachedScenes
            self.lastSyncDate = try? await repository.getLastSyncDate()
            
            logger.info("✅ Loaded \(cachedScenes.count) scenes from cache")
        } catch {
            logger.error("❌ Failed to load from cache: \(error.localizedDescription, privacy: .public)")
            throw AppError.repository(.syncFailed("Failed to load cached scenes"))
        }
    }
    
    /// Loads cutoff unmet scenes from the repository.
    func loadCutoffUnmetScenes() async throws -> [WhisparrScene] {
        logger.info("📦 Loading cutoff unmet scenes...")
        
        do {
            let scenes = try await repository.getCutoffUnmetScenes()
            logger.info("✅ Loaded \(scenes.count) cutoff unmet scenes")
            return scenes
        } catch {
            logger.error("❌ Failed to load cutoff unmet scenes: \(error.localizedDescription, privacy: .public)")
            throw AppError.repository(.syncFailed("Failed to load cutoff unmet scenes"))
        }
    }
    
    /// Preloads all scenes in background for fast search.
    func preloadAllScenes() async throws {
        logger.info("⚡️ Preloading all scenes for fast search...")
        
        do {
            let cachedScenes = try await repository.getCachedScenes()
            self.allCachedScenes = cachedScenes
            logger.info("✅ Preloaded \(cachedScenes.count) scenes for search")
        } catch {
            logger.error("❌ Failed to preload scenes: \(error.localizedDescription, privacy: .public)")
            throw AppError.repository(.syncFailed("Failed to preload scenes"))
        }
    }
    
    /// Fetches a single scene from the remote API.
    func fetchScene(id: Int) async throws -> WhisparrScene {
        return try await repository.fetchRemoteScene(id: id)
    }
    
    // MARK: - API Sync
    
    /// Syncs scenes from the Whisparr API with progress tracking.
    ///
    /// - Parameter onProgress: Callback that reports sync progress (0.0 to 1.0) and status message.
    func syncFromAPI(onProgress: @escaping (Double, String) -> Void) async throws {
        logger.info("🔄 Starting API sync from Whisparr...")
        
        do {
            _ = try await repository.syncScenes { progress, message in
                logger.debug("📊 Sync progress: \(Int(progress * 100))% - \(message, privacy: .public)")
                Task { @MainActor in
                    onProgress(progress, message)
                }
            }
            
            // Clear cache to force reload
            allCachedScenes = []
            
            // Update last sync date
            self.lastSyncDate = try? await repository.getLastSyncDate()
            
            logger.info("✅ API sync completed successfully")
        } catch is CancellationError {
            logger.info("⚠️ API sync was cancelled")
            throw CancellationError()
        } catch let appError as AppError {
            logger.error("❌ API sync failed: \(appError.localizedDescription, privacy: .public)")
            throw appError
        } catch {
            logger.error("❌ API sync failed: \(error.localizedDescription, privacy: .public)")
            throw error.toAppError()
        }
    }
    
    /// Checks if the cache needs refresh based on age.
    ///
    /// - Returns: True if cache is stale (older than 5 minutes), false otherwise.
    func shouldRefreshCache() async -> Bool {
        do {
            if let lastSync = try await repository.getLastSyncDate() {
                let age = Date().timeIntervalSince(lastSync)
                let ageMinutes = Int(age / 60)
                
                if age > 300 {
                    logger.info("⏰ Cache is \(ageMinutes)m old, refresh recommended")
                    return true
                } else {
                    logger.info("✅ Using fresh cached data (\(ageMinutes)m old)")
                    return false
                }
            } else {
                logger.info("⚠️ No sync date found, refresh required")
                return true
            }
        } catch {
            logger.error("❌ Failed to check cache age: \(error.localizedDescription, privacy: .public)")
            return true
        }
    }
    
    /// Clears all cached scenes.
    func clearCache() {
        logger.info("🗑️ Clearing cached scenes")
        allCachedScenes = []
    }
}
