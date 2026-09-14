import Foundation
import GRDB
import os

// MARK: - Shared Database Infrastructure

/// Container for database helper functions to ensure they are seen as non-isolated and Sendable.
struct DatabaseHelperContainer: Sendable {
    
    /// Adds a column to a table if it doesn't already exist.
    nonisolated static func addColumnIfMissing(
        _ db: Database,
        table: String,
        column: String,
        type: Database.ColumnType,
        logger: Logger
    ) throws {
        if try db.columns(in: table).contains(where: { $0.name == column }) == false {
            try db.alter(table: table) { t in
                t.add(column: column, type)
            }
            logger.debug("✅ Added \(column, privacy: .public) to \(table, privacy: .public)")
        }
    }

    /// Adds multiple columns to a table if they don't exist.
    nonisolated static func addColumnsIfMissing(
        _ db: Database,
        table: String,
        columns: [String: Database.ColumnType],
        logger: Logger
    ) throws {
        let existingColumns = try db.columns(in: table).map { $0.name }
        let missingColumns = columns.filter { !existingColumns.contains($0.key) }
        
        if !missingColumns.isEmpty {
            try db.alter(table: table) { t in
                for (name, type) in missingColumns {
                    t.add(column: name, type)
                }
            }
            let columnNames = missingColumns.keys.sorted().joined(separator: ", ")
            logger.debug("✅ Added columns to \(table, privacy: .public): \(columnNames, privacy: .public)")
        }
    }

    /// Creates a configured database queue.
    nonisolated static func createDatabaseQueue(
        name: String,
        logger: Logger,
        enableTracing: Bool = false
    ) throws -> DatabaseQueue {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        let dbFile = documentsDirectory.appendingPathComponent(name)
        let dbPath = dbFile.path
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: documentsDirectory.path) {
            try FileManager.default.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true
            )
        }
        
        logger.debug("📂 Database path: \(dbPath, privacy: .public)")
        
        var configuration = Configuration()
        if enableTracing {
            configuration.prepareDatabase { db in
                db.trace { event in
                    logger.debug("🔍 SQL: \(String(describing: event), privacy: .public)")
                }
            }
        }
        
        return try DatabaseQueue(path: dbPath, configuration: configuration)
    }

    /// Creates an index if it doesn't exist.
    nonisolated static func createIndexIfMissing(
        _ db: Database,
        name: String,
        on table: String,
        columns: [String],
        logger: Logger
    ) throws {
        try db.create(index: name, on: table, columns: columns, ifNotExists: true)
        logger.debug("📊 Index \(name, privacy: .public) on \(table, privacy: .public)")
    }
}

// Keep legacy global functions as wrappers to minimize changes in other files
// but mark them clearly as nonisolated.
@Sendable nonisolated func db_addColumnIfMissing(_ db: Database, table: String, column: String, type: Database.ColumnType, logger: Logger) throws {
    try DatabaseHelperContainer.addColumnIfMissing(db, table: table, column: column, type: type, logger: logger)
}

@Sendable nonisolated func db_addColumnsIfMissing(_ db: Database, table: String, columns: [String: Database.ColumnType], logger: Logger) throws {
    try DatabaseHelperContainer.addColumnsIfMissing(db, table: table, columns: columns, logger: logger)
}

@Sendable nonisolated func db_createDatabaseQueue(name: String, logger: Logger, enableTracing: Bool = false) throws -> DatabaseQueue {
    try DatabaseHelperContainer.createDatabaseQueue(name: name, logger: logger, enableTracing: enableTracing)
}

@Sendable nonisolated func db_createIndexIfMissing(_ db: Database, name: String, on table: String, columns: [String], logger: Logger) throws {
    try DatabaseHelperContainer.createIndexIfMissing(db, name: name, on: table, columns: columns, logger: logger)
}

// MARK: - Database Migration Versioning

@preconcurrency struct DatabaseMigration: Sendable {
    let version: Int
    let description: String
    let migrate: @Sendable (Database, Logger) throws -> Void
    
    nonisolated init(version: Int, description: String, migrate: @escaping @Sendable (Database, Logger) throws -> Void) {
        self.version = version
        self.description = description
        self.migrate = migrate
    }
}

@preconcurrency struct MigrationManager: Sendable {
    private let metadataTable = "schema_migrations"
    
    nonisolated init() {}
    
    nonisolated func runMigrations(_ db: Database, migrations: [DatabaseMigration], logger: Logger) throws {
        try db.create(table: metadataTable, ifNotExists: true) { t in
            t.column("version", .integer).primaryKey()
            t.column("description", .text).notNull()
            t.column("applied_at", .datetime).notNull()
        }
        
        let appliedVersions = try Int.fetchAll(db, sql: "SELECT version FROM \(metadataTable)")
        
        for migration in migrations.sorted(by: { $0.version < $1.version }) {
            if !appliedVersions.contains(migration.version) {
                logger.info("🔄 Migration v\(migration.version, privacy: .public): \(migration.description, privacy: .public)")
                try migration.migrate(db, logger)
                
                try db.execute(
                    sql: "INSERT INTO \(metadataTable) (version, description, applied_at) VALUES (?, ?, ?)",
                    arguments: [migration.version, migration.description, Date()]
                )
                
                logger.info("✅ Migration v\(migration.version, privacy: .public) complete")
            }
        }
    }
}
