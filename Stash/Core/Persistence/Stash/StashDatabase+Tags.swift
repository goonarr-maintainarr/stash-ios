import Foundation
import GRDB
import os



// MARK: - Tag Methods
extension StashDatabase {
    private nonisolated static let tagsLogger = Logger(subsystem: "com.stash.app", category: "StashDatabase+Tags")
    
    func saveTags(_ tags: [Tag]) async throws {
        Self.tagsLogger.info("💾 Starting save of \(tags.count, privacy: .public) tags to database...")
        let startTime = Date()
        
        try await dbQueue.write { db in
            // Save all tags
            for (index, tag) in tags.enumerated() {
                try tag.save(db)
                if (index + 1) % 50 == 0 {
                    Self.tagsLogger.debug("💾 Saved \(index + 1, privacy: .public)/\(tags.count, privacy: .public) tags...")
                }
            }
            
            // Update metadata
            let now = Date()
            try db.execute(
                sql: "INSERT OR REPLACE INTO cache_metadata (key, value, updatedAt) VALUES (?, ?, ?)",
                arguments: ["tagsLastSync", "\(tags.count)", now]
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.tagsLogger.info("✅ Successfully saved \(tags.count, privacy: .public) tags in \(String(format: "%.2f", duration), privacy: .public)s")
    }
    
    func fetchAllTags() async throws -> [Tag] {
        Self.tagsLogger.debug("🔍 Fetching all tags from database...")
        let startTime = Date()
        
        let tags = try await dbQueue.read { db in
            try Tag.order(Tag.Columns.name).fetchAll(db)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.tagsLogger.info("📚 Fetched \(tags.count, privacy: .public) tags from database in \(String(format: "%.3f", duration), privacy: .public)s")
        
        return tags
    }
    
    func fetchTagCount() async throws -> Int {
        return try await dbQueue.read { db in
            try Tag.fetchCount(db)
        }
    }
    
    func getTagsLastSyncDate() async throws -> Date? {
        return try await dbQueue.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT updatedAt FROM cache_metadata WHERE key = ?",
                arguments: ["tagsLastSync"]
            )
        }
    }
    
    // MARK: - Tag Cleanup Methods
    
    func removeDeletedTags(keeping tagIds: Set<String>) async throws {
        Self.tagsLogger.info("🗑️ Checking for deleted tags (keeping \(tagIds.count, privacy: .public) tag IDs)")
        
        try await dbQueue.write { db in
            // Fetch all existing tag IDs from database
            let existingIds = try String.fetchAll(db, sql: "SELECT id FROM tags")
            let existingSet = Set(existingIds)
            
            // Find IDs that exist in DB but not in the keep set
            let idsToDelete = existingSet.subtracting(tagIds)
            
            if !idsToDelete.isEmpty {
                Self.tagsLogger.info("🗑️ Deleting \(idsToDelete.count, privacy: .public) removed tags")
                
                for id in idsToDelete {
                    try db.execute(sql: "DELETE FROM tags WHERE id = ?", arguments: [id])
                }
                
                Self.tagsLogger.info("✅ Deleted \(idsToDelete.count, privacy: .public) tags from database")
            } else {
                Self.tagsLogger.info("✅ No tags to delete")
            }
        }
    }
    
    /// Deletes a single tag by ID from the database.
    func deleteTagById(_ id: String) async throws {
        Self.tagsLogger.info("🗑️ Deleting tag with ID: \(id, privacy: .public)")
        
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM tags WHERE id = ?", arguments: [id])
        }
        
        Self.tagsLogger.info("✅ Tag deleted successfully")
    }
}
