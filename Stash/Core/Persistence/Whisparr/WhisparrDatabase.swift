import Foundation
import GRDB
import os

/// Legacy WhisparrDatabase actor refactored to delegate to the unified AppDatabase.
actor WhisparrDatabase {
    static let shared = WhisparrDatabase()
    
    private nonisolated static let logger = Logger(subsystem: "com.stash.app", category: "WhisparrDatabase")
    
    // Delegates to AppDatabase for shared storage
    nonisolated var dbQueue: DatabaseQueue { AppDatabase.shared.dbQueue }
    
    init() {
        Self.logger.info("✅ WhisparrDatabase initialized (Delegating to AppDatabase)")
    }
}
