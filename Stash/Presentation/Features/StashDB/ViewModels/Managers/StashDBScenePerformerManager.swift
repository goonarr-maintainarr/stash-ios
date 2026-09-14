import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBScenePerformerManager")

/// Manages performer details and local matching for StashDB scenes.
@MainActor
@Observable
class StashDBScenePerformerManager {
    
    // MARK: - State
    
    var performerDetails: [String: StashDBPerformer] = [:]
    var localPerformerIds: [String: String] = [:]
    var localPerformerOCounts: [String: Int] = [:]
    var localImagePaths: [String: String] = [:]
    var localPerformerSceneCounts: [String: Int] = [:]
    
    // MARK: - Dependencies
    
    private let stashDBRepository: StashDBRepositoryProtocol
    private let performerDataProvider: PerformerMatchServiceProtocol
    
    // MARK: - Initialization
    
    init(
        stashDBRepository: StashDBRepositoryProtocol,
        performerDataProvider: PerformerMatchServiceProtocol
    ) {
        self.stashDBRepository = stashDBRepository
        self.performerDataProvider = performerDataProvider
        logger.debug("🔧 StashDBScenePerformerManager initialized")
    }
    
    // MARK: - Operations
    
    /// Loads detailed performer information from StashDB.
    func loadPerformerDetails(for performers: [StashDBPerformerAppearance]) async {
        logger.info("📥 Loading performer details for \(performers.count) performers")
        
        await withTaskGroup(of: (String, StashDBPerformer?).self) { group in
            for appearance in performers {
                group.addTask {
                    do {
                        let performer = try await self.stashDBRepository.fetchPerformerDetails(performerId: appearance.performer.id)
                        return (appearance.performer.id, performer)
                    } catch {
                        if (error as? URLError)?.code == .cancelled || error is CancellationError {
                            // Ignore cancellation
                        } else {
                            logger.error("❌ Failed to fetch performer \(appearance.performer.name): \(error.localizedDescription)")
                        }
                        return (appearance.performer.id, nil)
                    }
                }
            }
            
            for await (performerId, performer) in group {
                if let performer = performer {
                    self.performerDetails[performerId] = performer
                }
            }
        }
        
        logger.info("✅ Loaded \(self.performerDetails.count) performer details")
    }
    
    /// Checks local database for matching performers.
    func checkLocalPerformers(for performers: [StashDBPerformerAppearance]) async {
        logger.info("🔍 Checking local performers")
        
        let identifiers = performers.map { 
            (externalId: $0.performer.id, name: $0.performer.name) 
        }
        
        let result = await performerDataProvider.checkLocalPerformers(identifiers: identifiers)
        
        self.localPerformerIds = result.ids
        self.localPerformerOCounts = result.oCounts
        self.localPerformerSceneCounts = result.sceneCounts
        self.localImagePaths = result.imagePaths
        
        logger.info("✅ Found \(result.ids.count) local performer matches")
    }
}
