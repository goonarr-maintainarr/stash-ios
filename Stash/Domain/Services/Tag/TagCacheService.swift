import Foundation
import os

/// Service responsible for caching and local database operations for tags.
///
/// This service handles all interactions with the local StashDatabase for tags,
/// including retrieving cached tags and saving tags to cache.
class TagCacheService: @unchecked Sendable {
    private let database: StashDatabase
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "TagCacheService")
    
    init(database: StashDatabase) {
        self.database = database
    }
    

    // MARK: - Cache Operations
    
    /// Retrieves all tags currently stored in the local database.
    func getCachedTags() async throws -> [Tag] {
        
        do {
            let tags = try await database.fetchAllTags()
            return tags
        } catch {
            throw error
        }
    }
    
    /// Returns the number of tags in the local database.
    func getCachedTagCount() async throws -> Int {
        
        do {
            let count = try await database.fetchTagCount()
            return count
        } catch {
            throw error
        }
    }
    
    /// Saves the provided tags to the local database.
    func cacheTags(_ tags: [Tag]) async throws {
        Logger.repository.info("💾 Saving \(tags.count) tags to cache...")
        
        let startTime = Date()
        
        do {
            try await database.saveTags(tags)
            let duration = Date().timeIntervalSince(startTime)
            Logger.repository.info("✅ Cached tags in \(String(format: "%.2f", duration))s")
        } catch {
            throw error
        }
    }
    
    /// Retrieves the date of the last successful tag sync.
    func getLastSyncDate() async throws -> Date? {
        do {
            return try await database.getTagsLastSyncDate()
        } catch {
            throw error
        }
    }
    
    /// Removes tags not in the provided set from the database.
    func removeDeletedTags(keeping: Set<String>) async throws {
        
        do {
            try await database.removeDeletedTags(keeping: keeping)
        } catch {
            throw error
        }
    }
    
    /// Deletes a single tag from the local cache.
    func deleteTag(id: String) async throws {
        try await database.deleteTagById(id)
    }
}
