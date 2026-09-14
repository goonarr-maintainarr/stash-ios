import Foundation
import GRDB
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StudioCacheService")

/// Service responsible for managing Studio data in the local database.
class StudioCacheService: @unchecked Sendable { // Using @unchecked Sendable because GRDB access is thread-safe within its writer methods
    
    private let database: StashDatabase
    
    init(database: StashDatabase) {
        self.database = database
    }
    
    // MARK: - Save
    
    func cacheStudios(_ studios: [Studio]) async throws {
        try await database.saveStudios(studios)
        logger.debug("💾 Cached \(studios.count) studios")
    }
    
    // MARK: - Fetch
    
    func getCachedStudios() async throws -> [Studio] {
        return try await database.getAllStudios()
    }
    
    func getCachedStudio(id: String) async throws -> Studio? {
        return try await database.getStudio(id: id)
    }
    
    func getCachedStudioCount() async throws -> Int {
         return try await database.getStudioCount()
    }
    
    // MARK: - Sync Helpers
    
    func getLastSyncDate() async throws -> Date? {
        // Assuming we track studio sync date separately or use a global one.
        // For now, mirroring other services (which often use a centralized key or generic method)
        // Note: getLastSyncDate might be in Metadata extension
        return try await database.getLastSyncDate() 
    }
    
    func getLocalTimestamps() async throws -> [String: String] {
        return try await database.getStudioTimestamps()
    }
    
    func getLatestUpdatedAt() async throws -> String? {
        return try await database.getLatestStudioUpdatedAt()
    }
    
    func removeDeleted(keeping idsToKeep: Set<String>) async throws {
        try await database.removeDeletedStudios(keeping: idsToKeep)
    }
}
