import Foundation
import GRDB
import os

// MARK: - Scene Methods
extension WhisparrDatabase {
    private nonisolated static let scenesLogger = Logger(subsystem: "com.stash.app", category: "WhisparrDatabase+Scenes")
    
    func saveScenes(_ movies: [WhisparrScene]) async throws {
        Self.scenesLogger.info("💾 Saving \(movies.count, privacy: .public) scenes to database...")
        
        try await dbQueue.write { db in
            for movie in movies {
                try movie.save(db)
            }
            
            // Update metadata
            let now = Date()
            try db.execute(
                sql: "INSERT OR REPLACE INTO cache_metadata (key, value, updatedAt) VALUES (?, ?, ?)",
                arguments: ["lastSync", "\(movies.count)", now]
            )
        }
        
        Self.scenesLogger.info("✅ Successfully saved \(movies.count, privacy: .public) scenes")
    }
    
    func fetchAllScenes() async throws -> [WhisparrScene] {
        Self.scenesLogger.debug("🔍 Fetching all scenes from database...")
        
        let scenes = try await dbQueue.read { db in
            try WhisparrScene.fetchAll(db)
        }
        
        Self.scenesLogger.info("📚 Fetched \(scenes.count, privacy: .public) scenes from database")
        
        return scenes
    }
    
    func fetchSceneCount() async throws -> Int {
        return try await dbQueue.read { db in
            try WhisparrScene.fetchCount(db)
        }
    }
    
    func fetchFilteredScenes(hasFile: Bool, monitored: Bool) async throws -> [WhisparrScene] {
        Self.scenesLogger.debug("🔍 Fetching filtered scenes (hasFile: \(hasFile, privacy: .public), monitored: \(monitored, privacy: .public))...")
        
        let scenes = try await dbQueue.read { db in
            try WhisparrScene
                .filter(WhisparrScene.Columns.hasFile == hasFile)
                .filter(WhisparrScene.Columns.monitored == monitored)
                .order(WhisparrScene.Columns.releaseDate.desc)
                .fetchAll(db)
        }
        
        Self.scenesLogger.info("📚 Fetched \(scenes.count, privacy: .public) filtered scenes")
        
        return scenes
    }
    
    func fetchScene(id: Int) async throws -> WhisparrScene? {
        return try await dbQueue.read { db in
            try WhisparrScene.fetchOne(db, key: id)
        }
    }
    
    func deleteScene(id: Int) async throws {
        Self.scenesLogger.info("🗑️ Deleting scene \(id, privacy: .public) from database")
        
        try await dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM whisparr_scenes WHERE id = ?",
                arguments: [id]
            )
        }
        
        Self.scenesLogger.info("✅ Successfully deleted scene \(id, privacy: .public)")
    }
    
    func clearDatabase() async throws {
        Self.scenesLogger.info("🗑️ Clearing database")
        
        try await dbQueue.write { db in
            try WhisparrScene.deleteAll(db)
            try db.execute(sql: "DELETE FROM cache_metadata")
        }
        
        Self.scenesLogger.info("✅ Database cleared")
    }
    
    func fetchAllSceneStashIds() async throws -> Set<String> {
        return try await dbQueue.read { db in
            let foreignIds = try String.fetchAll(
                db,
                sql: "SELECT foreignId FROM whisparr_scenes WHERE foreignId IS NOT NULL"
            )
            
            let stashIds = foreignIds.compactMap { foreignId -> String? in
                if foreignId.hasPrefix("stash:") {
                    return String(foreignId.dropFirst(6))
                }
                return foreignId
            }
            
            return Set(stashIds)
        }
    }
    
    func removeDeletedScenes(keeping sceneIds: Set<Int>) async throws {
        Self.scenesLogger.info("🔍 Checking for deleted scenes (keeping \(sceneIds.count, privacy: .public) IDs)")
        
        try await dbQueue.write { db in
            let existingIds = try Int.fetchAll(db, sql: "SELECT id FROM whisparr_scenes")
            let existingSet = Set(existingIds)
            let idsToDelete = existingSet.subtracting(sceneIds)
            
            if !idsToDelete.isEmpty {
                Self.scenesLogger.info("🗑️ Deleting \(idsToDelete.count, privacy: .public) removed scenes")
                for id in idsToDelete {
                    try db.execute(sql: "DELETE FROM whisparr_scenes WHERE id = ?", arguments: [id])
                }
                Self.scenesLogger.info("✅ Deleted \(idsToDelete.count, privacy: .public) scenes from database")
            } else {
                Self.scenesLogger.info("✅ No scenes to delete")
            }
        }
    }
    
    // MARK: - Metadata Methods
    
    func getLastSyncDate() async throws -> Date? {
        Self.scenesLogger.debug("🔍 Checking last sync date...")
        
        let lastSync = try await dbQueue.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT updatedAt FROM cache_metadata WHERE key = ?",
                arguments: ["lastSync"]
            )
        }
        
        if let date = lastSync {
            let age = Date().timeIntervalSince(date)
            Self.scenesLogger.debug("📅 Last sync: \(date.description, privacy: .public) (\(Int(age), privacy: .public)s ago)")
        } else {
            Self.scenesLogger.debug("📅 No sync date found in database")
        }
        
        return lastSync
    }
    
    func updateLastSyncDate(_ date: Date) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO cache_metadata (key, value, updatedAt) VALUES (?, ?, ?)",
                arguments: ["lastSync", "updated", date]
            )
        }
    }
}
