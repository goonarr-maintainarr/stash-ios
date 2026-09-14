import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerCacheService")

/// Service responsible for performer caching operations.
///
/// Handles:
/// - Retrieving cached performers
/// - Saving performers to cache
/// - Cache freshness checks
/// - Image prefetching
class PerformerCacheService: @unchecked Sendable {
    
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
    
    /// Retrieves all performers from the local cache.
    func getCachedPerformers() async throws -> [Performer] {
        do {
            return try await database.fetchAllPerformers()
        } catch {
            throw AppError.database(.queryFailed("Failed to fetch cached performers"))
        }
    }
    
    /// Returns the total count of locally cached performers.
    func getCachedPerformerCount() async throws -> Int {
        do {
            return try await database.fetchPerformerCount()
        } catch {
            throw AppError.database(.queryFailed("Failed to fetch performer count"))
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
    
    /// Caches a list of performers to the local database.
    func cachePerformers(_ performers: [Performer]) async throws {
        logger.info("💾 Saving \(performers.count) performers to cache...")
        let startTime = Date()
        
        do {
            try await database.savePerformers(performers)
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ Cached performers in \(String(format: "%.2f", duration))s")
        } catch {
            throw AppError.database(.queryFailed("Failed to cache performers"))
        }
    }
    
    /// Prefetches images for a list of performers.
    func prefetchImages(for performers: [Performer], count: Int = 10) {
        let urlsToPrefetch = performers.prefix(count).compactMap { performer -> URL? in
            settings.createImageUrl(path: performer.image_path)
        }
        
        if !urlsToPrefetch.isEmpty {
            logger.debug("🖼️ Prefetching \(urlsToPrefetch.count) performer images")
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

