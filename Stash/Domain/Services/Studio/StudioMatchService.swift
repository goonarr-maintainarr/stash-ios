import Foundation
import os

/// A result container for studio matching operations.
struct StudioMatchResult: Sendable {
    /// Mapping of external studio IDs to local Stash studio IDs.
    let ids: [String: String]
}

/// Protocol for providing studio matching functionality.
protocol StudioMatchServiceProtocol: Sendable {
    /// Checks the local Stash database for matches for a list of studio identifiers.
    /// - Parameters:
    ///   - identifiers: An array of tuples containing (externalId, name) for each studio.
    /// - Returns: A `StudioMatchResult` containing all matched studio data.
    func checkLocalStudios(identifiers: [(externalId: String, name: String)]) async -> StudioMatchResult
}

/// Service responsible for matching external studios (StashDB, Whisparr) with local Stash studios.
actor StudioMatchService: StudioMatchServiceProtocol {
    private let logger = Logger(subsystem: "com.stash.app", category: "StudioMatchService")
    private let stashDatabase: StashDatabase
    private let settings: SettingsStore
    
    init(stashDatabase: StashDatabase, settings: SettingsStore = .shared) {
        self.stashDatabase = stashDatabase
        self.settings = settings
    }
    
    /// Checks the local Stash database for matches for a list of studio identifiers.
    func checkLocalStudios(identifiers: [(externalId: String, name: String)]) async -> StudioMatchResult {
        var ids: [String: String] = [:]
        
        // Clean up inputs
        let activeIdentifiers = identifiers.filter { !$0.externalId.isEmpty || !$0.name.isEmpty }
        
        guard !activeIdentifiers.isEmpty else { return StudioMatchResult(ids: [:]) }
        
        logger.debug("🔍 Starting studio match for \(activeIdentifiers.count) identifiers")
        
        do {
            let externalIds = activeIdentifiers.map { $0.externalId }.filter { !$0.isEmpty }
            let names = activeIdentifiers.map { $0.name }.filter { !$0.isEmpty }
            
            let potentialStudios = try await stashDatabase.fetchStudios(identifiers: externalIds, names: names)
            
            for studio in potentialStudios {
                // Match by stash_id
                if let stashIds = studio.stash_ids {
                    for stashId in stashIds {
                        if externalIds.contains(stashId.stash_id) {
                            // Find which external identifier this belongs to
                            for ident in activeIdentifiers where ident.externalId == stashId.stash_id {
                                ids[ident.externalId] = studio.id
                            }
                        }
                    }
                }
                
                // Match by name (fallback)
                for identifier in activeIdentifiers {
                    if ids[identifier.externalId] == nil && 
                       !identifier.name.isEmpty && 
                       identifier.name.lowercased() == studio.name.lowercased() {
                        ids[identifier.externalId] = studio.id
                    }
                }
            }
        } catch {
            logger.error("Failed to check local studios: \(String(describing: error))")
        }
        
        return StudioMatchResult(ids: ids)
    }
}
