import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrScenePerformerManager")

/// Manages performer details fetching and local matching for Whisparr scenes.
@MainActor
@Observable
class WhisparrScenePerformerManager {
    
    // MARK: - State
    
    /// Cache of StashDB performer details mapped by foreign ID.
    var performerDetails: [String: StashDBPerformer] = [:]
    
    /// Mapping of Whisparr foreign IDs to local StashDB performer IDs.
    var localPerformerIds: [String: String] = [:]
    
    /// Mapping of Whisparr foreign IDs to local O-Counts.
    var localPerformerOCounts: [String: Int] = [:]
    
    /// Mapping of Whisparr foreign IDs to local Scene Counts.
    var localPerformerSceneCounts: [String: Int] = [:]
    
    /// Mapping of Whisparr foreign IDs to local image paths.
    var localImagePaths: [String: String] = [:]
    
    /// The local StashDB scene ID if available.
    var localSceneId: String?
    
    // MARK: - Dependencies
    
    private let performerService: WhisparrPerformerService
    private let stashDatabase: StashDatabase
    private let performerDataProvider: PerformerMatchServiceProtocol
    
    // MARK: - Initialization
    
    init(
        performerService: WhisparrPerformerService,
        stashDatabase: StashDatabase,
        performerDataProvider: PerformerMatchServiceProtocol
    ) {
        self.performerService = performerService
        self.stashDatabase = stashDatabase
        self.performerDataProvider = performerDataProvider
        logger.debug("🔧 WhisparrScenePerformerManager initialized")
    }
    
    // MARK: - Performer Details
    
    /// Fetches detailed performer information from StashDB.
    func loadPerformerDetails(for performers: [WhisparrCredit]) async {
        logger.info("📥 Loading performer details for \(performers.count) performers")
        let details = await performerService.fetchPerformerDetails(for: performers)
        self.performerDetails = details
        logger.info("✅ Loaded \(details.count) performer details")
    }
    
    // MARK: - Local Matching
    
    /// Checks the local StashDB database for matching performers.
    func checkLocalPerformers(for performers: [WhisparrCredit]) async {
        logger.info("🔍 Checking local performers")
        
        let identifiers = performers.compactMap { credit -> (externalId: String, name: String)? in
            guard let name = credit.performer.name else { return nil }
            return (externalId: credit.performer.foreignId, name: name)
        }
        
        let result = await performerDataProvider.checkLocalPerformers(identifiers: identifiers)
        
        self.localPerformerIds = result.ids
        self.localPerformerOCounts = result.oCounts
        self.localPerformerSceneCounts = result.sceneCounts
        self.localImagePaths = result.imagePaths
        
        logger.info("✅ Found \(result.ids.count) local performer matches")
    }
    
    /// Checks if the scene exists in the local StashDB database.
    func checkLocalScene(foreignId: String?) async {
        guard let foreignId = foreignId else {
            logger.info("⚠️ No foreign ID provided for scene lookup")
            return
        }
        
        logger.info("🔍 Checking local scene with foreign ID: \(foreignId)")
        let stashId = foreignId.replacingOccurrences(of: "stash:", with: "")
        
        do {
            if let id = try await stashDatabase.fetchSceneId(byStashId: stashId) {
                self.localSceneId = id
                logger.info("✅ Found local scene ID: \(id)")
            } else {
                logger.info("ℹ️ Scene not found in local database")
            }
        } catch {
            logger.error("❌ Failed to check local scene: \(error.localizedDescription)")
        }
    }
}
