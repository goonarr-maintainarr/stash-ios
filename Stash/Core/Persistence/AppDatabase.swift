import Foundation
import GRDB
import os

/// Unified database actor providing persistent storage for all app data (Stash & Whisparr).
/// Consolidates previous separate sqlite files and merges partial/full cache tables.
actor AppDatabase {
    static var shared = AppDatabase()
    
    private nonisolated static let logger = Logger(subsystem: "com.stash.app", category: "AppDatabase")
    
    // Internal access for extensions - nonisolated for synchronous access in repositories
    nonisolated let dbQueue: DatabaseQueue
    
    /// Indicates if the database was recovered from corruption (user should be notified)
    nonisolated let wasRecovered: Bool
    
    /// Creates a new AppDatabase instance.
    /// - Parameter inMemory: If true, creates an in-memory database (useful for testing).
    init(inMemory: Bool = false) {
        if inMemory {
            do {
                self.dbQueue = try DatabaseQueue()
                self.wasRecovered = false
                Self.logger.info("🧪 Created in-memory AppDatabase")
                
                try dbQueue.write { db in
                    try AppDatabaseMigrations.run(db, logger: Self.logger)
                }
            } catch {
                // For testing, still use fatalError since this should never fail
                fatalError("❌ Failed to create in-memory database: \(error.localizedDescription)")
            }
            return
        }
        
        // Production path: try to open existing database with recovery
        var queue: DatabaseQueue?
        var recovered = false
        
        // Attempt 1: Open existing database
        do {
            Self.cleanupOldDatabases()
            
            queue = try db_createDatabaseQueue(
                name: "app.sqlite",
                logger: Self.logger,
                enableTracing: false
            )
            
            // Run migrations
            try queue!.write { db in
                try AppDatabaseMigrations.run(db, logger: Self.logger)
            }
            
            Self.logger.info("✅ AppDatabase setup complete")
        } catch {
            Self.logger.error("⚠️ Database open failed: \(error.localizedDescription, privacy: .public)")
            Self.logger.error("🔧 Attempting database recovery...")
            
            // Attempt 2: Delete corrupted database and create fresh
            do {
                Self.deleteCurrentDatabase()
                
                queue = try db_createDatabaseQueue(
                    name: "app.sqlite",
                    logger: Self.logger,
                    enableTracing: false
                )
                
                try queue!.write { db in
                    try AppDatabaseMigrations.run(db, logger: Self.logger)
                }
                
                recovered = true
                Self.logger.info("✅ Database recovered - created fresh database")
            } catch {
                Self.logger.error("❌ Database recovery failed: \(error.localizedDescription, privacy: .public)")
                Self.logger.error("🆘 Falling back to in-memory database")
                
                // Attempt 3: Use in-memory database as last resort
                do {
                    queue = try DatabaseQueue()
                    try queue!.write { db in
                        try AppDatabaseMigrations.run(db, logger: Self.logger)
                    }
                    recovered = true
                    Self.logger.warning("⚠️ Using in-memory database - data will not persist!")
                } catch {
                    // This should never happen, but if it does, we truly have no choice
                    Self.logger.fault("💀 FATAL: Cannot create any database: \(error.localizedDescription, privacy: .public)")
                    fatalError("Cannot create any database: \(error.localizedDescription)")
                }
            }
        }
        
        self.dbQueue = queue!
        self.wasRecovered = recovered
    }
    
    /// Factory method for testing that returns a fresh in-memory database.
    static func testing() -> AppDatabase {
        return AppDatabase(inMemory: true)
    }
    
    /// Deletes the current database files (used during recovery from corruption).
    private static func deleteCurrentDatabase() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbFiles = ["app.sqlite", "app.sqlite-shm", "app.sqlite-wal"]
        
        for file in dbFiles {
            let path = docs.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    try FileManager.default.removeItem(at: path)
                    logger.info("🗑️ Deleted database file: \(file, privacy: .public)")
                } catch {
                    logger.error("⚠️ Failed to delete \(file, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    private static func cleanupOldDatabases() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldFiles = ["stash.sqlite", "stash.sqlite-shm", "stash.sqlite-wal", 
                        "whisparr.sqlite", "whisparr.sqlite-shm", "whisparr.sqlite-wal"]
        
        for file in oldFiles {
            let path = docs.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    try FileManager.default.removeItem(at: path)
                    logger.info("🗑️ Deleted old database file: \(file)")
                } catch {
                    logger.error("⚠️ Failed to delete \(file): \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Migrations

private enum AppDatabaseMigrations {
    static func run(_ db: Database, logger: Logger) throws {
        let migrations: [DatabaseMigration] = [
            // V1: Unified schema with merged core/detail tables
            DatabaseMigration(version: 1, description: "Unified initial schema") { db, logger in
                try createUnifiedSchema(db, logger: logger)
            },
            
            // V2: Add description to tags
            DatabaseMigration(version: 2, description: "Add tag description") { db, logger in
                if try db.columns(in: "tags").contains(where: { $0.name == "description" }) {
                    return
                }
                try db.alter(table: "tags") { t in
                    t.add(column: "description", .text)
                }
            },
            
            // V3: Add urls to scenes
            DatabaseMigration(version: 3, description: "Add urls to scenes") { db, logger in
                try db.alter(table: "scenes") { t in
                    t.add(column: "urlsJSON", .text)
                }
            }
        ]
        
        let migrationManager = MigrationManager()
        try migrationManager.runMigrations(db, migrations: migrations, logger: logger)
    }
    
    private static func createUnifiedSchema(_ db: Database, logger: Logger) throws {
        // 1. Scenes Table (Merged scenes + scene_details)
        try db.create(table: "scenes", ifNotExists: true) { t in
            t.column("id", .text).primaryKey(onConflict: .replace)
            t.column("title", .text)
            t.column("details", .text)
            t.column("date", .text)
            t.column("created_at", .text)
            t.column("updated_at", .text)
            t.column("rating100", .integer)
            t.column("o_counter", .integer)
            t.column("resume_time", .double)
            t.column("pathsJSON", .text)
            t.column("filesJSON", .text)
            t.column("performersJSON", .text)
            t.column("tagsJSON", .text)
            t.column("studioJSON", .text)
            t.column("sceneMarkersJSON", .text)
            t.column("oHistoryJSON", .text)
            t.column("playHistoryJSON", .text)
            t.column("stash_idsJSON", .text)
            t.column("director", .text)
            t.column("code", .text)
            t.column("url", .text)
            t.column("full_data_cached_at", .datetime) // Tracks when full metadata was last fetched
        }
        
        try db_createIndexIfMissing(db, name: "idx_scene_date", on: "scenes", columns: ["date"], logger: logger)
        try db_createIndexIfMissing(db, name: "idx_scene_updated_at", on: "scenes", columns: ["updated_at"], logger: logger)
        
        // 2. Performers Table (Merged performers + performer_details)
        try db.create(table: "performers", ifNotExists: true) { t in
            t.column("id", .text).primaryKey(onConflict: .replace)
            t.column("name", .text)
            t.column("gender", .text)
            t.column("url", .text)
            t.column("twitter", .text)
            t.column("instagram", .text)
            t.column("birthdate", .text)
            t.column("ethnicity", .text)
            t.column("country", .text)
            t.column("eye_color", .text)
            t.column("height_cm", .integer)
            t.column("measurements", .text)
            t.column("fake_tits", .text)
            t.column("career_length", .text)
            t.column("tattoos", .text)
            t.column("piercings", .text)
            t.column("alias_listJSON", .text)
            t.column("favorite", .boolean)
            t.column("image_path", .text)
            t.column("details", .text)
            t.column("scene_count", .integer)
            t.column("o_counter", .integer)
            t.column("created_at", .text)
            t.column("updated_at", .text)
            t.column("stash_idsJSON", .text)
            t.column("disambiguation", .text)
            t.column("death_date", .text)
            t.column("hair_color", .text)
            t.column("weight", .integer)
            t.column("image_count", .integer)
            t.column("gallery_count", .integer)
            t.column("group_count", .integer)
            t.column("rating100", .integer)
            t.column("tagsJSON", .text)
            t.column("urlsJSON", .text)
            t.column("penis_length", .double)
            t.column("circumcised", .text)
            t.column("scenesJSON", .text) // From performer_details
            t.column("full_data_cached_at", .datetime)
        }
        
        try db_createIndexIfMissing(db, name: "idx_performer_name", on: "performers", columns: ["name"], logger: logger)
        
        // 3. Tags Table
        try db.create(table: "tags", ifNotExists: true) { t in
            t.column("id", .text).primaryKey(onConflict: .replace)
            t.column("name", .text).notNull()
            t.column("scene_count", .integer)
            t.column("description", .text)
        }
        
        // 4. Studios Table
        try db.create(table: "studios", ifNotExists: true) { t in
            t.column("id", .text).primaryKey(onConflict: .replace)
            t.column("name", .text)
            t.column("image_path", .text)
            t.column("urlsJSON", .text)
            t.column("parentStudioJSON", .text)
            t.column("aliasesJSON", .text)
            t.column("tagsJSON", .text)
            t.column("ignore_auto_tag", .boolean)
            t.column("scene_count", .integer)
            t.column("image_count", .integer)
            t.column("gallery_count", .integer)
            t.column("performer_count", .integer)
            t.column("group_count", .integer)
            t.column("stashIdsJSON", .text)
            t.column("rating100", .integer)
            t.column("favorite", .boolean)
            t.column("details", .text)
            t.column("created_at", .text)
            t.column("updated_at", .text)
            t.column("o_counter", .integer)
        }
        
        // 5. Whisparr Scenes Table
        try db.create(table: "whisparr_scenes", ifNotExists: true) { t in
            t.column("id", .integer).primaryKey(onConflict: .replace)
            t.column("title", .text).notNull()
            t.column("code", .text)
            t.column("overview", .text)
            t.column("releaseDate", .datetime)
            t.column("year", .integer).notNull()
            t.column("runtime", .integer).notNull()
            t.column("studioTitle", .text)
            t.column("studioForeignId", .text)
            t.column("foreignId", .text)
            t.column("hasFile", .boolean).notNull()
            t.column("monitored", .boolean).notNull()
            t.column("sizeOnDisk", .integer).notNull()
            t.column("genresJSON", .text).notNull()
            t.column("imagesJSON", .text).notNull()
            t.column("creditsJSON", .text).notNull()
            t.column("movieFileJSON", .text)
            t.column("statisticsJSON", .text)
            t.column("itemType", .text).notNull()
            t.column("added", .datetime).notNull()
            t.column("rootFolderPath", .text)
            t.column("qualityProfileId", .integer)
            t.column("path", .text)
        }
        
        try db_createIndexIfMissing(db, name: "idx_whisparr_hasFile", on: "whisparr_scenes", columns: ["hasFile"], logger: logger)
        
        // 6. Cache Metadata (Shared)
        try db.create(table: "cache_metadata", ifNotExists: true) { t in
            t.column("key", .text).primaryKey(onConflict: .replace)
            t.column("value", .text).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
        
        logger.debug("✅ Unified schema created")
    }
}
