import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSearchResultPerformerManager")

/// Manages performer data for Whisparr search results.
@MainActor
@Observable
class WhisparrSearchResultPerformerManager {
    
    // MARK: - State
    
    /// StashDB details for performers in the scene.
    var performerDetails: [String: StashDBPerformer] = [:]
    
    /// Local performer IDs mapped by foreign ID.
    var localPerformerIds: [String: String] = [:]
    
    /// Local performer O-Counts mapped by foreign ID.
    var localPerformerOCounts: [String: Int] = [:]
    
    /// Local performer Scene Counts mapped by foreign ID.
    var localPerformerSceneCounts: [String: Int] = [:]
    
    /// Local image paths mapped by foreign ID.
    var localImagePaths: [String: String] = [:]
    
    // MARK: - Dependencies
    
    private let performerService: WhisparrPerformerService
    private let performerDataProvider: PerformerMatchServiceProtocol
    
    // MARK: - Initialization
    
    init(
        performerService: WhisparrPerformerService,
        performerDataProvider: PerformerMatchServiceProtocol
    ) {
        self.performerService = performerService
        self.performerDataProvider = performerDataProvider
        logger.debug("🔧 WhisparrSearchResultPerformerManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetches detailed performer information from StashDB for female performers.
    func loadPerformerDetails(for credits: [WhisparrCredit]) async {
        let femalePerformers = credits.filter { $0.performer.gender?.uppercased() != "MALE" }
        
        logger.info("👥 Loading performer details for \(femalePerformers.count, privacy: .public) female performers")
        
        let details = await performerService.fetchPerformerDetails(for: femalePerformers)
        self.performerDetails = details
        
        logger.info("✅ Loaded details for \(details.count, privacy: .public) performers")
    }
    
    /// Checks the local StashDB database for matching performers.
    func checkLocalPerformers(for credits: [WhisparrCredit]) async {
        let femalePerformers = credits.filter { $0.performer.gender?.uppercased() != "MALE" }
        
        let identifiers = femalePerformers.compactMap { credit -> (externalId: String, name: String)? in
            guard let name = credit.performer.name else { return nil }
            return (externalId: credit.performer.foreignId, name: name)
        }
        
        logger.info("🔍 Checking local performers for \(identifiers.count, privacy: .public) matches")
        
        let result = await performerDataProvider.checkLocalPerformers(identifiers: identifiers)
        
        self.localPerformerIds = result.ids
        self.localPerformerOCounts = result.oCounts
        self.localPerformerSceneCounts = result.sceneCounts
        self.localImagePaths = result.imagePaths
        
        logger.info("✅ Found \(result.ids.count, privacy: .public) local performer matches")
    }
    
    /// Returns female performers from credits.
    func getFemalePerformers(from credits: [WhisparrCredit]) -> [WhisparrCredit] {
        return credits.filter { $0.performer.gender?.uppercased() != "MALE" }
    }
}
