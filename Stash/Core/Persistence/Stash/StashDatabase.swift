import Foundation
import GRDB
import os

/// Legacy StashDatabase actor refactored to delegate to the unified AppDatabase.
actor StashDatabase {
    static let shared = StashDatabase()
    
    private nonisolated static let logger = Logger(subsystem: "com.stash.app", category: "StashDatabase")
    
    // Delegates to AppDatabase for shared storage
    nonisolated var dbQueue: DatabaseQueue { AppDatabase.shared.dbQueue }
    
    init() {
        Self.logger.info("✅ StashDatabase initialized (Delegating to AppDatabase)")
    }
}
