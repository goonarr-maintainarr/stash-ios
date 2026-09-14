import Foundation
import os

/// Service responsible for caching and local database operations for Whisparr scenes.
///
/// This service handles all interactions with the local WhisparrDatabase, including
/// fetching cached scenes, filtering, and cache freshness checks.
class WhisparrCacheService: @unchecked Sendable {
    private let database: WhisparrDatabase
    
    /// The interval after which the cache is considered stale (12 hours).
    private let cacheExpirationInterval: TimeInterval = 43200 // 12 hours
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrCacheService")
    
    init(database: WhisparrDatabase) {
        self.database = database
    }
    
    // MARK: - Cache Operations
    
    /// Retrieves all scenes currently stored in the local cache.
    ///
    /// - Returns: An array of `WhisparrScene` objects from the local database.
    /// - Throws: An error if the database retrieval fails.
    func getCachedScenes() async throws -> [WhisparrScene] {
        
        do {
            let scenes = try await database.fetchAllScenes()
            return scenes
        } catch {
            throw error
        }
    }
    
    /// Retrieves scenes, optionally filtering by file status and monitored status.
    ///
    /// If no filters are provided, it returns all valid scenes from the cache.
    ///
    /// - Parameters:
    ///   - hasFile: Filter by presence of a file. Pass `nil` to ignore this filter.
    ///   - monitored: Filter by monitored status. Pass `nil` to ignore this filter.
    /// - Returns: An array of `WhisparrScene` objects matching the criteria.
    /// - Throws: An error if database access fails.
    func getScenes(hasFile: Bool? = nil, monitored: Bool? = nil) async throws -> [WhisparrScene] {
        
        // If no filters, return all cached
        guard hasFile != nil || monitored != nil else {
            return try await getCachedScenes()
        }
        
        // Apply filters
        if let hasFile = hasFile, let monitored = monitored {
            let scenes = try await database.fetchFilteredScenes(hasFile: hasFile, monitored: monitored)
            return scenes
        }
        
        // Filter in memory if only one filter specified
        let all = try await getCachedScenes()
        let filtered = all.filter { movie in
            if let hasFile = hasFile, movie.hasFile != hasFile { return false }
            if let monitored = monitored, movie.monitored != monitored { return false }
            return true
        }
        return filtered
    }
    
    /// Fetches all Stash IDs associated with scenes in the cache.
    ///
    /// - Returns: A set of strings representing Stash IDs.
    /// - Throws: An error if database access fails.
    func fetchAllSceneStashIds() async throws -> Set<String> {
        
        do {
            let ids = try await database.fetchAllSceneStashIds()
            return ids
        } catch {
            throw error
        }
    }
    
    /// Checks if the local cache is considered stale based on the last sync date.
    ///
    /// - Returns: `true` if the cache is older than the expiration interval, otherwise `false`.
    /// - Throws: An error if accessing the last sync date fails.
    func shouldRefreshCache() async throws -> Bool {
        
        guard let lastSync = try await database.getLastSyncDate() else {
            logger.info("❓ No Whisparr sync date found, cache needs refresh")
            return true
        }
        
        let cacheAge = Date().timeIntervalSince(lastSync)
        let shouldRefresh = cacheAge > cacheExpirationInterval
        
        let ageMinutes = Int(cacheAge / 60)
        
        if shouldRefresh {
            logger.info("⏰ Whisparr cache age: \(ageMinutes)m - STALE")
        } else {
            logger.info("✅ Whisparr cache age: \(ageMinutes)m - FRESH")
        }
        
        return shouldRefresh
    }
    
    /// Retrieves the date of the last successful sync.
    ///
    /// - Returns: The `Date` of the last sync, or `nil` if never synced.
    /// - Throws: An error if database access fails.
    func getLastSyncDate() async throws -> Date? {
        return try await database.getLastSyncDate()
    }
    
    // MARK: - Database Write Operations
    
    /// Saves scenes to the database.
    ///
    /// - Parameter scenes: The scenes to save.
    /// - Throws: An error if the save operation fails.
    func saveScenes(_ scenes: [WhisparrScene]) async throws {
        
        do {
            try await database.saveScenes(scenes)
        } catch {
            throw error
        }
    }
    
    /// Deletes a scene from the database.
    ///
    /// - Parameter id: The ID of the scene to delete.
    /// - Throws: An error if the delete operation fails.
    func deleteScene(id: Int) async throws {
        
        do {
            try await database.deleteScene(id: id)
        } catch {
            throw error
        }
    }
    
    /// Removes scenes not in the provided set from the database.
    ///
    /// - Parameter keeping: Set of scene IDs to keep.
    /// - Throws: An error if the operation fails.
    func removeDeletedScenes(keeping: Set<Int>) async throws {
        
        do {
            try await database.removeDeletedScenes(keeping: keeping)
        } catch {
            throw error
        }
    }
    
    /// Updates the last sync date in the database.
    ///
    /// - Parameter date: The new sync date.
    /// - Throws: An error if the update fails.
    func updateLastSyncDate(_ date: Date) async throws {
        
        do {
            try await database.updateLastSyncDate(date)
        } catch {
            throw error
        }
    }
}
