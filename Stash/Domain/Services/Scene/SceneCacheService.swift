import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneCacheService")

/// Service responsible for scene caching operations.
///
/// Handles:
/// - Reading/writing from local database
/// - Cache freshness checks
/// - Image prefetching
class SceneCacheService: @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let database: StashDatabase
    private let settings: SettingsStoreProtocol
    private let imagePrefetchManager: ImagePrefetchService
    
    // Default cache expiration (12 hours)
    private let defaultCacheExpirationInterval: TimeInterval = 43200
    
    // MARK: - Initialization
    
    init(
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        imagePrefetchManager: ImagePrefetchService
    ) {
        self.database = database
        self.settings = settings
        self.imagePrefetchManager = imagePrefetchManager
    }
    
    // MARK: - Public Methods
    
    /// Retrieves all scenes from the local cache.
    func getCachedScenes() async throws -> [Scene] {
        do {
            return try await database.fetchAllScenes()
        } catch {
            logger.error("❌ Failed to fetch cached scenes: \(error.localizedDescription)")
            throw AppError.database(.queryFailed("Failed to fetch cached scenes: \(error.localizedDescription)"))
        }
    }
    
    /// Returns the total count of locally cached scenes.
    func getCachedSceneCount() async throws -> Int {
        do {
            return try await database.fetchSceneCount()
        } catch {
            throw AppError.database(.queryFailed("Failed to fetch scene count"))
        }
    }
    
    /// Checks if the local cache is stale.
    func shouldRefreshCache() async throws -> Bool {
        let lastSync = try await getLastSyncDate()
        return shouldRefreshCache(lastSyncDate: lastSync)
    }
    
    /// Gets the date of the last sync.
    func getLastSyncDate() async throws -> Date? {
        do {
            return try await database.getLastSyncDate()
        } catch {
            throw AppError.database(.queryFailed("Failed to fetch last sync date"))
        }
    }
    
    /// Caches a list of scenes to the local database.
    func cacheScenes(_ scenes: [Scene]) async throws {
        logger.info("💾 Saving \(scenes.count) scenes to cache...")
        let startTime = Date()
        for scene in scenes {
            logger.debug("📚 Caching scene: \(scene.title ?? "Untitled") (\(scene.id))")
        }
        do {
            try await database.saveScenes(scenes)
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ Cached scenes in \(String(format: "%.2f", duration))s")
        } catch {
            throw AppError.database(.queryFailed("Failed to cache scenes"))
        }
    }
    
    /// Saves a single scene to both list cache and details cache.
    func saveScene(_ scene: Scene) async throws {
        do {
            // Update the unified scenes table
            try await database.saveScenes([scene])
        } catch {
            throw AppError.database(.queryFailed("Failed to save scene"))
        }
    }
    
    /// Prefetches images for a list of scenes.
    func prefetchImages(for scenes: [Scene], count: Int = 10) {
        let urlsToPrefetch = scenes.prefix(count).compactMap { scene -> URL? in
            settings.createImageUrl(path: scene.paths?.screenshot)
        }
        
        if !urlsToPrefetch.isEmpty {
            logger.debug("🖼️ Prefetching \(urlsToPrefetch.count) images")
            imagePrefetchManager.prefetch(urls: urlsToPrefetch)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Determines if the local cache should be refreshed based on the last sync date.
    private func shouldRefreshCache(lastSyncDate: Date?, interval: TimeInterval? = nil) -> Bool {
        guard let lastSync = lastSyncDate else {
            logger.info("❓ No sync date found, cache needs refresh")
            return true
        }
        
        // Use provided interval or default
        let expiration = interval ?? defaultCacheExpirationInterval
        let cacheAge = Date().timeIntervalSince(lastSync)
        let shouldRefresh = cacheAge > expiration
        
        let ageMinutes = Int(cacheAge / 60)
        if shouldRefresh {
            logger.info("⏰ Cache age: \(ageMinutes)m - STALE")
        } else {
            logger.info("✅ Cache age: \(ageMinutes)m - FRESH")
        }
        
        return shouldRefresh
    }
}
