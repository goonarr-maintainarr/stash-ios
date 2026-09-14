import Foundation
import GRDB
import os

// MARK: - Performer Methods
extension StashDatabase {
    private nonisolated static let performersLogger = Logger(subsystem: "com.stash.app", category: "StashDatabase+Performers")
    
    func savePerformers(_ performers: [Performer]) async throws {
        Self.performersLogger.info("💾 Starting save of \(performers.count, privacy: .public) performers to database...")
        let startTime = Date()
        
        try await dbQueue.write { db in
            for (index, performer) in performers.enumerated() {
                try performer.save(db)
                if (index + 1) % 100 == 0 {
                    Self.performersLogger.debug("💾 Saved \(index + 1, privacy: .public)/\(performers.count, privacy: .public) performers...")
                }
            }
            
            // Update metadata
            let now = Date()
            try db.execute(
                sql: "INSERT OR REPLACE INTO cache_metadata (key, value, updatedAt) VALUES (?, ?, ?)",
                arguments: ["performersLastSync", "\(performers.count)", now]
            )
        }
        
        // Cascade updates to scenes (in case name/image changed)
        try await updateScenesWithPerformers(performers)
        
        let duration = Date().timeIntervalSince(startTime)
        Self.performersLogger.info("✅ Successfully saved \(performers.count, privacy: .public) performers in \(String(format: "%.2f", duration), privacy: .public)s")
    }
    
    func fetchAllPerformers() async throws -> [Performer] {
        Self.performersLogger.debug("🔍 Fetching all performers from database...")
        let startTime = Date()
        
        let performers = try await dbQueue.read { db in
            try Performer.fetchAll(db)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.performersLogger.info("📚 Fetched \(performers.count, privacy: .public) performers from database in \(String(format: "%.3f", duration), privacy: .public)s")
        
        return performers
    }
    
    func fetchPerformerCount() async throws -> Int {
        return try await dbQueue.read { db in
            try Performer.fetchCount(db)
        }
    }
    
    /// Fetches a single performer by ID. Much more efficient than loading all performers.
    func fetchPerformerById(_ id: String) async throws -> Performer? {
        Self.performersLogger.debug("🔍 Fetching performer by ID: \(id, privacy: .public)")
        
        return try await dbQueue.read { db in
            try Performer.fetchOne(db, key: id)
        }
    }
    
    func fetchPerformers(identifiers: [String], names: [String]) async throws -> [Performer] {
        // If nothing to search, return empty
        if identifiers.isEmpty && names.isEmpty {
            return []
        }
        
        Self.performersLogger.debug("🔍 Fetching specific performers: \(identifiers.count, privacy: .public) IDs, \(names.count, privacy: .public) names")
        
        return try await dbQueue.read { db in
            var query = "SELECT * FROM performers WHERE "
            var arguments: [Any] = []
            var clauses: [String] = []
            
            if !names.isEmpty {
                let placeholders = names.map { _ in "?" }.joined(separator: ", ")
                clauses.append("name IN (\(placeholders))")
                arguments.append(contentsOf: names)
            }
            
            if !identifiers.isEmpty {
                let idClauses = identifiers.map { _ in "stash_idsJSON LIKE ?" }
                clauses.append("(\(idClauses.joined(separator: " OR ")))")
                arguments.append(contentsOf: identifiers.map { "%\($0)%" })
            }
            
            query += clauses.joined(separator: " OR ")
            
            return try Performer.fetchAll(db, sql: query, arguments: StatementArguments(arguments) ?? StatementArguments())
        }
    }
    
    func getPerformersLastSyncDate() async throws -> Date? {
        Self.performersLogger.debug("🔍 Checking performers last sync date...")
        
        let lastSync = try await dbQueue.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT updatedAt FROM cache_metadata WHERE key = ?",
                arguments: ["performersLastSync"]
            )
        }
        
        if let date = lastSync {
            let age = Date().timeIntervalSince(date)
            Self.performersLogger.debug("📅 Performers last sync: \(date.description, privacy: .public) (\(Int(age), privacy: .public)s ago)")
        } else {
            Self.performersLogger.debug("📅 No performers sync date found in database")
        }
        
        return lastSync
    }
    
    // MARK: - Performer Details Methods
    
    func savePerformerDetails(_ performer: Performer, scenes: [Scene]) async throws {
        Self.performersLogger.debug("💾 Saving performer details for ID: \(performer.id, privacy: .public) with \(scenes.count, privacy: .public) scenes")
        
        try await dbQueue.write { db in
            // Save the performer (updates all standard columns)
            try performer.save(db)
            
            // Encode scenes to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let scenesJSON = try String(data: encoder.encode(scenes), encoding: .utf8)
            
            // Update the unified performers table with detail fields
            try db.execute(
                sql: "UPDATE performers SET scenesJSON = ?, full_data_cached_at = ? WHERE id = ?",
                arguments: [scenesJSON, Date(), performer.id]
            )
        }
        
        Self.performersLogger.info("✅ Saved performer details for: \(performer.name ?? "Unknown", privacy: .public) with \(scenes.count, privacy: .public) scenes")
    }
    
    func fetchPerformerDetails(id: String) async throws -> (performer: Performer, scenes: [Scene], cachedAt: Date)? {
        Self.performersLogger.debug("🔍 Fetching performer details for ID: \(id, privacy: .public)")
        
        return try await dbQueue.read { (db) -> (Performer, [Scene], Date)? in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT *, full_data_cached_at FROM performers WHERE id = ?",
                arguments: [id]
            ), let cachedAt: Date = row["full_data_cached_at"] else {
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let performer = try Performer(row: row)
            
            let scenes: [Scene]
            if let scenesJSON: String = row["scenesJSON"] {
                scenes = (try? decoder.decode([Scene].self, from: Data(scenesJSON.utf8))) ?? []
            } else {
                scenes = []
            }
            
            let age = Date().timeIntervalSince(cachedAt)
            Self.performersLogger.info("✅ Found cached performer details with \(scenes.count, privacy: .public) scenes (age: \(Int(age), privacy: .public)s)")
            
            return (performer, scenes, cachedAt)
        }
    }
    
    // MARK: - Performer Cleanup Methods
    
    func removeDeletedPerformers(keeping performerIds: Set<String>) async throws {
        Self.performersLogger.info("🗑️ Checking for deleted performers (keeping \(performerIds.count, privacy: .public) performer IDs)")
        
        try await dbQueue.write { db in
            let existingIds = try String.fetchAll(db, sql: "SELECT id FROM performers")
            let existingSet = Set(existingIds)
            let idsToDelete = existingSet.subtracting(performerIds)
            
            if !idsToDelete.isEmpty {
                Self.performersLogger.info("🗑️ Deleting \(idsToDelete.count, privacy: .public) removed performers")
                for id in idsToDelete {
                    try db.execute(sql: "DELETE FROM performers WHERE id = ?", arguments: [id])
                }
                Self.performersLogger.info("✅ Deleted \(idsToDelete.count, privacy: .public) performers from database")
            }
        }
    }
    
    func fetchPerformerTimestamps() async throws -> [String: String?] {
        return try await dbQueue.read { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT id, updated_at FROM performers")
            var result: [String: String?] = [:]
            while let row = try rows.next() {
                let id: String = row["id"]
                let timestamp: String? = row["updated_at"]
                result[id] = timestamp
            }
            return result
        }
    }
    
    func getLatestPerformerUpdatedAt() async throws -> String? {
        return try await dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT MAX(updated_at) as latest FROM performers WHERE updated_at IS NOT NULL")
            return row?["latest"]
        }
    }
    
    func deletePerformerById(id: String) async throws {
        Self.performersLogger.info("🗑️ Deleting performer \(id, privacy: .public) from database...")
        
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM performers WHERE id = ?", arguments: [id])
        }
        
        Self.performersLogger.info("✅ Deleted performer \(id, privacy: .public)")
    }
}
