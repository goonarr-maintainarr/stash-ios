import Foundation
import GRDB
import os

extension StashDatabase {
    private nonisolated static let metadataLogger = Logger(subsystem: "com.stash.app", category: "StashDatabase+Metadata")
    
    /// Save a generic string value to the cache_metadata table
    func saveCacheMetadata(key: String, value: String) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO cache_metadata (key, value, updatedAt) VALUES (?, ?, ?)",
                arguments: [key, value, Date()]
            )
        }
    }
    
    /// Fetch a generic string value from the cache_metadata table
    func fetchCacheMetadata(key: String) async throws -> String? {
        return try await dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM cache_metadata WHERE key = ?", arguments: [key])
        }
    }
}
