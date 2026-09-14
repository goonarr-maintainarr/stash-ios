import Foundation
import GRDB
import os

// MARK: - Scene Methods
extension StashDatabase {
    private nonisolated static let scenesLogger = Logger(subsystem: "com.stash.app", category: "StashDatabase+Scenes")
    
    func saveScenes(_ scenes: [Scene]) async throws {
        Self.scenesLogger.info("💾 Starting save of \(scenes.count, privacy: .public) scenes to database...")
        let startTime = Date()
        
        try await dbQueue.write { db in
            for (index, scene) in scenes.enumerated() {
                try scene.save(db)
                
                if (index + 1) % 100 == 0 {
                    Self.scenesLogger.debug("💾 Saved \(index + 1, privacy: .public)/\(scenes.count, privacy: .public) scenes...")
                }
            }
            
            // Update metadata
            let now = Date()
            try db.execute(
                sql: "INSERT OR REPLACE INTO cache_metadata (key, value, updatedAt) VALUES (?, ?, ?)",
                arguments: ["lastSync", "\(scenes.count)", now]
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.scenesLogger.info("✅ Successfully saved \(scenes.count, privacy: .public) scenes in \(String(format: "%.2f", duration), privacy: .public)s")
    }
    
    func fetchAllScenes() async throws -> [Scene] {
        Self.scenesLogger.debug("🔍 Fetching all scenes from database...")
        let startTime = Date()
        
        let scenes = try await dbQueue.read { db in
            try Scene.fetchAll(db)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.scenesLogger.info("📚 Fetched \(scenes.count, privacy: .public) scenes from database in \(String(format: "%.3f", duration), privacy: .public)s")
        
        return scenes
    }
    
    /// Fetches a single scene by ID. Much more efficient than loading all scenes.
    func fetchSceneById(_ id: String) async throws -> Scene? {
        Self.scenesLogger.debug("🔍 Fetching scene by ID: \(id, privacy: .public)")
        
        return try await dbQueue.read { db in
            try Scene.fetchOne(db, key: id)
        }
    }
    
    /// Fetches scenes that have any of the specified tag IDs.
    /// More efficient than fetching all scenes and filtering in memory.
    /// - Parameters:
    ///   - tagIds: Array of tag IDs to match
    ///   - limit: Optional limit on number of results
    ///   - sortBy: Sort column (created_at, date, rating100, o_counter, updated_at)
    ///   - ascending: Sort direction
    func fetchScenesByTagIds(
        _ tagIds: [String],
        limit: Int? = nil,
        sortBy: String? = nil,
        ascending: Bool = false
    ) async throws -> [Scene] {
        guard !tagIds.isEmpty else {
            Self.scenesLogger.debug("⚠️ No tag IDs provided, returning empty")
            return []
        }
        
        Self.scenesLogger.debug("🔍 Fetching scenes with tags: \(tagIds.joined(separator: ", "), privacy: .public)")
        let startTime = Date()
        
        let scenes = try await dbQueue.read { db in
            // Build OR conditions for each tag ID
            let conditions = tagIds.map { _ in "tagsJSON LIKE ?" }.joined(separator: " OR ")
            let arguments = tagIds.map { "%\"id\":\"\($0)\"%" }
            
            var sql = "SELECT * FROM scenes WHERE \(conditions)"
            
            // Add ORDER BY if sortBy specified
            if let sortBy = sortBy {
                let direction = ascending ? "ASC" : "DESC"
                sql += " ORDER BY \(sortBy) \(direction)"
            }
            
            // Add LIMIT if specified
            if let limit = limit {
                sql += " LIMIT \(limit)"
            }
            
            return try Scene.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.scenesLogger.info("📚 Fetched \(scenes.count, privacy: .public) scenes by tags in \(String(format: "%.3f", duration), privacy: .public)s")
        
        return scenes
    }
    
    /// Fetches scenes with sorting, optionally limited. 
    /// Used for Home screen categories like "Top Rated", "Recently Added", etc.
    func fetchScenesSorted(
        by column: String,
        ascending: Bool = false,
        limit: Int? = nil
    ) async throws -> [Scene] {
        Self.scenesLogger.debug("🔍 Fetching scenes sorted by \(column, privacy: .public), limit: \(limit ?? -1)")
        let startTime = Date()
        
        let scenes = try await dbQueue.read { db in
            let direction = ascending ? "ASC" : "DESC"
            var sql = "SELECT * FROM scenes ORDER BY \(column) \(direction)"
            if let limit = limit {
                sql += " LIMIT \(limit)"
            }
            return try Scene.fetchAll(db, sql: sql)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.scenesLogger.debug("📚 Fetched \(scenes.count, privacy: .public) sorted scenes in \(String(format: "%.3f", duration), privacy: .public)s")
        
        return scenes
    }
    
    /// Fetches random scenes. Used for Home screen "Random" category.
    func fetchRandomScenes(limit: Int) async throws -> [Scene] {
        Self.scenesLogger.debug("🎲 Fetching \(limit) random scenes")
        let startTime = Date()
        
        let scenes = try await dbQueue.read { db in
            let sql = "SELECT * FROM scenes ORDER BY RANDOM() LIMIT \(limit)"
            return try Scene.fetchAll(db, sql: sql)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.scenesLogger.debug("🎲 Fetched \(scenes.count, privacy: .public) random scenes in \(String(format: "%.3f", duration), privacy: .public)s")
        
        return scenes
    }
    
    func fetchSceneCount() async throws -> Int {
        return try await dbQueue.read { db in
            try Scene.fetchCount(db)
        }
    }
    
    func fetchSceneId(byStashId stashId: String) async throws -> String? {
        return try await dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: "SELECT id FROM scenes WHERE stash_idsJSON LIKE ?",
                arguments: ["%\"stash_id\":\"\(stashId)\"%"]
            )
            return row?["id"]
        }
    }
    
    func fetchScenesSortedByDate(limit: Int? = nil) async throws -> [Scene] {
        return try await dbQueue.read { db in
            var request = Scene
                .order(Scene.Columns.date.desc)
            
            if let limit = limit {
                request = request.limit(limit)
            }
            
            return try Scene.fetchAll(db, request)
        }
    }
    
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
    
    func clearDatabase() async throws {
        Self.scenesLogger.info("🗑️ Clearing database...")
        
        try await dbQueue.write { db in
            let sceneCount = try Scene.fetchCount(db)
            try Scene.deleteAll(db)
            try db.execute(sql: "DELETE FROM cache_metadata")
            Self.scenesLogger.debug("🗑️ Deleted \(sceneCount, privacy: .public) scenes and all metadata")
        }
        
        Self.scenesLogger.info("✅ Database cleared successfully")
    }
    
    func deleteSceneById(id: String) async throws {
        Self.scenesLogger.info("🗑️ Deleting scene with ID: \(id, privacy: .public) from database")
        
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM scenes WHERE id = ?", arguments: [id])
        }
        
        Self.scenesLogger.info("✅ Successfully deleted scene from database")
    }
    
    // MARK: - Scene Details Methods
    
    func saveSceneDetails(_ scene: Scene) async throws {
        Self.scenesLogger.debug("💾 Saving scene details for ID: \(scene.id, privacy: .public)")
        
        try await dbQueue.write { db in
            // Save the scene (this updates all columns including JSON blobs)
            try scene.save(db)
            
            // Track when full data was cached
            try db.execute(
                sql: "UPDATE scenes SET full_data_cached_at = ? WHERE id = ?",
                arguments: [Date(), scene.id]
            )
        }
        
        Self.scenesLogger.info("✅ Saved scene details for: \(scene.title ?? "Unknown", privacy: .public)")
    }
    
    func fetchSceneDetails(id: String) async throws -> (scene: Scene, cachedAt: Date)? {
        return try await dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT *, full_data_cached_at FROM scenes WHERE id = ?",
                arguments: [id]
            ), let cachedAt: Date = row["full_data_cached_at"] else {
                return nil
            }
            
            let scene = try Scene(row: row)
            let age = Date().timeIntervalSince(cachedAt)
            Self.scenesLogger.info("✅ Found cached scene details (age: \(Int(age), privacy: .public)s)")
            
            return (scene, cachedAt)
        }
    }
    
    // MARK: - StashDB Helper Methods
    
    func fetchSceneStashIds(endpoint: String = "https://stashdb.org/graphql") async throws -> Set<String> {
        return try await dbQueue.read { db in
            let decoder = JSONDecoder()
            var stashIds = Set<String>()
            
            let rows = try Row.fetchAll(db, sql: "SELECT stash_idsJSON FROM scenes WHERE stash_idsJSON IS NOT NULL")
            
            for row in rows {
                if let stashIdsJSON: String = row["stash_idsJSON"],
                   let ids = try? decoder.decode([Scene.StashID].self, from: Data(stashIdsJSON.utf8)) {
                    let matchingIds = ids.filter { $0.endpoint == endpoint }.map { $0.stash_id }
                    stashIds.formUnion(matchingIds)
                }
            }
            
            return stashIds
        }
    }
    
    // MARK: - Scene Cleanup Methods
    
    func removeDeletedScenes(keeping sceneIds: Set<String>) async throws {
        Self.scenesLogger.info("🗑️ Checking for deleted scenes (keeping \(sceneIds.count, privacy: .public) scene IDs)")
        
        try await dbQueue.write { db in
            let existingIds = try String.fetchAll(db, sql: "SELECT id FROM scenes")
            let existingSet = Set(existingIds)
            let idsToDelete = existingSet.subtracting(sceneIds)
            
            if !idsToDelete.isEmpty {
                Self.scenesLogger.info("🗑️ Deleting \(idsToDelete.count, privacy: .public) removed scenes")
                for id in idsToDelete {
                    try db.execute(sql: "DELETE FROM scenes WHERE id = ?", arguments: [id])
                }
                Self.scenesLogger.info("✅ Deleted \(idsToDelete.count, privacy: .public) scenes from database")
            }
        }
    }
    
    func fetchSceneTimestamps() async throws -> [String: String?] {
        return try await dbQueue.read { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT id, updated_at FROM scenes")
            var result: [String: String?] = [:]
            while let row = try rows.next() {
                let id: String = row["id"]
                let timestamp: String? = row["updated_at"]
                result[id] = timestamp
            }
            return result
        }
    }
    
    func getLatestSceneUpdatedAt() async throws -> String? {
        return try await dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT MAX(updated_at) as latest FROM scenes WHERE updated_at IS NOT NULL")
            return row?["latest"]
        }
    }

    func updateScenesWithPerformers(_ performers: [Performer]) async throws {
        if performers.isEmpty { return }
        
        Self.scenesLogger.info("🔄 Checking \(performers.count, privacy: .public) updated performers for cascading scene updates...")
        
        try await dbQueue.write { db in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            var updatedSceneCount = 0
            
            let performerMap = Dictionary(uniqueKeysWithValues: performers.map { ($0.id, $0) })
            
            for performer in performers {
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT id, performersJSON FROM scenes WHERE performersJSON LIKE ?",
                    arguments: ["%\"id\":\"\(performer.id)\"%"]
                )
                
                for row in rows {
                    let sceneId: String = row["id"]
                    if let performersJSON: String = row["performersJSON"],
                       var scenePerformers = try? decoder.decode([Performer].self, from: Data(performersJSON.utf8)) {
                        
                        var sceneNeedsUpdate = false
                        for i in 0..<scenePerformers.count {
                            if let updatedPerformer = performerMap[scenePerformers[i].id] {
                                if scenePerformers[i] != updatedPerformer {
                                    scenePerformers[i] = updatedPerformer
                                    sceneNeedsUpdate = true
                                }
                            }
                        }
                        
                        if sceneNeedsUpdate {
                            let newJSON = try String(data: encoder.encode(scenePerformers), encoding: .utf8)
                            try db.execute(
                                sql: "UPDATE scenes SET performersJSON = ? WHERE id = ?",
                                arguments: [newJSON, sceneId]
                            )
                            updatedSceneCount += 1
                        }
                    }
                }
            }
            
            if updatedSceneCount > 0 {
                Self.scenesLogger.info("✅ Cascaded performer updates to \(updatedSceneCount, privacy: .public) scenes")
            }
        }
    }
}
