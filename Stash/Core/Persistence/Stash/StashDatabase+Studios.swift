import Foundation
import GRDB
import os

extension StashDatabase {
    
    // MARK: - Save
    
    func saveStudios(_ studios: [Studio]) async throws {
        try await dbQueue.write { db in
            for studio in studios {
                try studio.save(db)
            }
        }
    }
    
    // MARK: - Fetch
    
    func getAllStudios() async throws -> [Studio] {
        return try await dbQueue.read { db in
            try Studio.order(Studio.Columns.name.asc).fetchAll(db)
        }
    }
    
    func getStudio(id: String) async throws -> Studio? {
        return try await dbQueue.read { db in
            try Studio.fetchOne(db, key: id)
        }
    }
    
    func getStudioCount() async throws -> Int {
        return try await dbQueue.read { db in
            try Studio.fetchCount(db)
        }
    }
    
    func fetchStudios(identifiers: [String], names: [String]) async throws -> [Studio] {
        // If nothing to search, return empty
        if identifiers.isEmpty && names.isEmpty {
            return []
        }
        
        return try await dbQueue.read { db in
            var query = "SELECT * FROM studios WHERE "
            var arguments: [Any] = []
            var clauses: [String] = []
            
            if !names.isEmpty {
                let placeholders = names.map { _ in "?" }.joined(separator: ", ")
                clauses.append("name IN (\(placeholders))")
                arguments.append(contentsOf: names)
            }
            
            if !identifiers.isEmpty {
                let idClauses = identifiers.map { _ in "stashIdsJSON LIKE ?" }
                clauses.append("(\(idClauses.joined(separator: " OR ")))")
                arguments.append(contentsOf: identifiers.map { "%\($0)%" })
            }
            
            query += clauses.joined(separator: " OR ")
            
            return try Studio.fetchAll(db, sql: query, arguments: StatementArguments(arguments) ?? StatementArguments())
        }
    }
    
    // MARK: - Sync Helpers
    
    func getStudioTimestamps() async throws -> [String: String] {
        return try await dbQueue.read { db in
            let studios = try Studio.select(Studio.Columns.id, Studio.Columns.updated_at).fetchAll(db)
            var dict: [String: String] = [:]
            for studio in studios {
                if let updated = studio.updated_at {
                    dict[studio.id] = updated
                }
            }
            return dict
        }
    }
    
    func getLatestStudioUpdatedAt() async throws -> String? {
        return try await dbQueue.read { db in
             try String.fetchOne(db, sql: "SELECT updated_at FROM studios ORDER BY updated_at DESC LIMIT 1")
        }
    }
    
    func removeDeletedStudios(keeping idsToKeep: Set<String>) async throws {
        try await dbQueue.write { db in
            let allIds = try String.fetchAll(db, sql: "SELECT id FROM studios")
            let idsToDelete = Set(allIds).subtracting(idsToKeep)
            
            guard !idsToDelete.isEmpty else { return }
            
            try Studio.filter(idsToDelete.contains(Studio.Columns.id)).deleteAll(db)
        }
    }
}
