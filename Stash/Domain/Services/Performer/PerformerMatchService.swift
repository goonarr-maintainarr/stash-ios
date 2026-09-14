import Foundation
import os

/// A result container for performer matching operations.
struct PerformerMatchResult: Sendable {
    /// Mapping of external performer IDs to local Stash performer IDs.
    let ids: [String: String]
    /// Mapping of external performer IDs to local O-Counts.
    let oCounts: [String: Int]
    /// Mapping of external performer IDs to local scene counts.
    let sceneCounts: [String: Int]
    /// Mapping of external performer IDs to local image paths.
    let imagePaths: [String: String]
}

/// Protocol for providing performer matching functionality.
protocol PerformerMatchServiceProtocol: Sendable {
    /// Checks the local Stash database for matches for a list of performer identifiers.
    /// - Parameters:
    ///   - identifiers: An array of tuples containing (externalId, name) for each performer.
    /// - Returns: A `PerformerMatchResult` containing all matched performer data.
    func checkLocalPerformers(identifiers: [(externalId: String, name: String)]) async -> PerformerMatchResult
}

/// Service responsible for matching external performers (StashDB, Whisparr) with local Stash performers.
///
/// This service handles performer matching via stash_id or name matching,
/// providing comprehensive data about local performer matches.
actor PerformerMatchService: PerformerMatchServiceProtocol {
    private let logger = Logger(subsystem: "com.stash.app", category: "PerformerMatchService")
    private let stashDatabase: StashDatabase
    private let settings: SettingsStore
    
    init(stashDatabase: StashDatabase, settings: SettingsStore = .shared) {
        self.stashDatabase = stashDatabase
        self.settings = settings
    }
    
    // MARK: - Performer Matching
    
    /// Checks the local Stash database for matches for a list of performer identifiers.
    ///
    /// Matching is done via:
    /// 1. `stash_id` matching (preferred) - checks if any local performer has a stash_id matching the external ID
    /// 2. Name matching (fallback) - checks if any local performer has a matching name
    ///
    /// Only performers with at least one scene are included in results.
    ///
    /// - Parameters:
    ///   - identifiers: An array of tuples containing (externalId, name: String) for each performer.
    /// - Returns: A `PerformerMatchResult` containing all matched performer data.
    func checkLocalPerformers(identifiers: [(externalId: String, name: String)]) async -> PerformerMatchResult {
        var ids: [String: String] = [:]
        var oCounts: [String: Int] = [:]
        var sceneCounts: [String: Int] = [:]
        var imagePaths: [String: String] = [:]
        
        // Clean up inputs
        let activeIdentifiers = identifiers.filter { !$0.externalId.isEmpty || !$0.name.isEmpty }
        
        logger.debug("🔍 Starting performer match for \(activeIdentifiers.count) identifiers")
        for ident in activeIdentifiers {
            logger.debug("   - ID: \(ident.externalId, privacy: .public), Name: '\(ident.name, privacy: .public)'")
        }
        
        do {
            // Extract potential identifiers and names to fetch
            let externalIds = activeIdentifiers.map { $0.externalId }.filter { !$0.isEmpty }
            let names = activeIdentifiers.map { $0.name }.filter { !$0.isEmpty }
            
            // Fetch only potentially matching performers
            let potentialPerformers = try await stashDatabase.fetchPerformers(identifiers: externalIds, names: names)
            
            logger.debug("🔍 Database returned \(potentialPerformers.count) potential performers to check")
            
            var stashIdMatches = 0
            var nameMatches = 0
            
            for performer in potentialPerformers {
                logger.debug("   - Checking local performer: \(performer.name ?? "unnamed", privacy: .public) (ID: \(performer.id, privacy: .public))")
                
                // Method 1: Match by stash_id (preferred)
                if let stashIds = performer.stash_ids {
                    for stashId in stashIds {
                        if externalIds.contains(stashId.stash_id) {
                            ids[stashId.stash_id] = performer.id
                            oCounts[stashId.stash_id] = performer.o_counter
                            sceneCounts[stashId.stash_id] = performer.scene_count
                            if let imagePath = performer.image_path {
                                imagePaths[stashId.stash_id] = imagePath
                            }
                            stashIdMatches += 1
                            logger.debug("     ✅ Matched by StashID: \(stashId.stash_id, privacy: .public)")
                        }
                    }
                }
                
                // Method 2: Match by name (fallback if no stash_ids match)
                if let performerName = performer.name {
                    for identifier in activeIdentifiers {
                        if !identifier.name.isEmpty && identifier.name.lowercased() == performerName.lowercased() {
                            // Only add if not already added by stash_id match
                            if ids[identifier.externalId] == nil {
                                ids[identifier.externalId] = performer.id
                                oCounts[identifier.externalId] = performer.o_counter
                                sceneCounts[identifier.externalId] = performer.scene_count
                                if let imagePath = performer.image_path {
                                    imagePaths[identifier.externalId] = imagePath
                                }
                                nameMatches += 1
                                logger.debug("     ✅ Matched by Name: \(performerName, privacy: .public)")
                            }
                        }
                    }
                }
            }
            
            logger.info("🎯 Performer matching finished. StashID matches: \(stashIdMatches), name matches: \(nameMatches)")
        } catch {
            if (error as? URLError)?.code == .cancelled || error is CancellationError {
                // Ignore cancellation
            } else {
                logger.error("Failed to check local performers: \(String(describing: error))")
            }
        }
        
        return PerformerMatchResult(
            ids: ids,
            oCounts: oCounts,
            sceneCounts: sceneCounts,
            imagePaths: imagePaths
        )
    }
}
