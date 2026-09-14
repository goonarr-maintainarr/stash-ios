import Foundation
import Combine
import Nuke
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "BaseRepository")

/// A base repository class providing common dependencies and utility methods for Stash repositories.
class BaseRepository: @unchecked Sendable {
    let apiClient: StashClientProtocol
    let database: StashDatabase
    let settings: SettingsStoreProtocol
    let imagePrefetchManager: ImagePrefetchService
    
    // Default cache expiration (12 hours)
    let defaultCacheExpirationInterval: TimeInterval = 43200
    
    /// Initializes a new instance of `BaseRepository`.
    ///
    /// - Parameters:
    ///   - apiClient: The client used for making GraphQL requests. Defaults to `StashClient.shared`.
    ///   - database: The local database for caching. Defaults to `StashDatabase.shared`.
    ///   - settings: The store for user settings.
    ///   - imagePrefetchManager: Manager for prefetching images. Defaults to new instance.
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        imagePrefetchManager: ImagePrefetchService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.imagePrefetchManager = imagePrefetchManager
    }
    
    /// Validates that the server URL is configured and returns it.
    ///
    /// - Returns: The valid `URL`.
    /// - Throws: `AppError.repository(.invalidConfiguration)` if the URL is missing.
    func validateConfiguration() throws -> URL {
        guard let url = settings.url else {
            throw AppError.repository(.invalidConfiguration)
        }
        return url
    }
    
    /// Determines if the local cache should be refreshed based on the last sync date.
    ///
    /// - Parameters:
    ///   - lastSyncDate: The date of the last successful sync.
    ///   - interval: The expiration interval in seconds. Defaults to 12 hours.
    /// - Returns: `true` if the cache is stale or missing, `false` otherwise.
    func shouldRefreshCache(lastSyncDate: Date?, interval: TimeInterval? = nil) -> Bool {
        guard let lastSync = lastSyncDate else {
            Logger.repository.info("❓ No sync date found, cache needs refresh")
            return true
        }
        
        // Use provided interval or default
        let expiration = interval ?? defaultCacheExpirationInterval
        let cacheAge = Date().timeIntervalSince(lastSync)
        let shouldRefresh = cacheAge > expiration
        
        let ageMinutes = Int(cacheAge / 60)
        if shouldRefresh {
            Logger.repository.info("⏰ Cache age: \(ageMinutes)m - STALE")
        } else {
            Logger.repository.info("✅ Cache age: \(ageMinutes)m - FRESH")
        }
        
        return shouldRefresh
    }
    
    /// Prefetches images for the given URLs.
    ///
    /// - Parameter urls: A list of image URLs to prefetch.
    func prefetchImages(urls: [URL]) {
        if !urls.isEmpty {
            Logger.repository.debug("🖼️ Prefetching \(urls.count) images")
            imagePrefetchManager.prefetch(urls: urls)
        }
    }
}

/// An actor to prevent concurrent fetches of the same data type.
actor FetchGuard {
    private var isFetchingAll = false
    
    /// Attempts to begin a fetch operation.
    ///
    /// - Returns: `true` if the fetch can proceed (lock acquired), `false` if already fetching.
    func beginIfPossible() -> Bool {
        if isFetchingAll { return false }
        isFetchingAll = true
        return true
    }
    
    /// Ends the current fetch operation, releasing the lock.
    func end() {
        isFetchingAll = false
    }
}
