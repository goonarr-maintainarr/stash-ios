import Foundation
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSearchResultDetailViewModel")

/// A ViewModel responsible for managing the details and interactions for a Whisparr search result.
///
/// `WhisparrSearchResultDetailViewModel` handles the "Add Movie" flow, allowing users to configure
/// root folders and quality profiles before adding a scene to their Whisparr library.
@MainActor
@Observable
final class WhisparrSearchResultDetailViewModel {
    
    // MARK: - OperationState
    
    enum OperationState: Equatable {
        case idle
        case loadingSettings
        case adding
        case searching
        case success(String)
        case error(String)
    }
    
    /// The current operation state.
    var operationState: OperationState = .idle
    
    /// The search result being displayed.
    var searchResult: WhisparrSearchResult
    
    /// Trigger to show the releases sheet.
    var showReleasesSheet = false
    
    // MARK: - Managers
    
    private let settingsManager: WhisparrSearchResultSettingsManager
    private let addManager: WhisparrSearchResultAddManager
    private let performerManager: WhisparrSearchResultPerformerManager
    private let studioMatchService: StudioMatchServiceProtocol
    
    // MARK: - Computed Properties
    
    var isAddingToWhisparr: Bool {
        if case .adding = operationState { return true }
        return addManager.isAdding
    }
    
    var showSuccessToast: Bool {
        if case .success = operationState { return true }
        return addManager.successMessage != nil
    }
    
    var showErrorAlert: Bool {
        if case .error = operationState { return true }
        return !errorMessage.isEmpty
    }
    
    var errorMessage: String {
        if case .error(let message) = operationState { return message }
        return addManager.errorMessage ?? settingsManager.errorMessage ?? ""
    }
    
    var isSearching: Bool {
        if case .searching = operationState { return true }
        return addManager.isSearching
    }
    
    var searchError: String? {
        if case .error(let message) = operationState { return message }
        return addManager.errorMessage
    }
    
    var isLoadingSettings: Bool {
        if case .loadingSettings = operationState { return true }
        return settingsManager.isLoading
    }
    
    // Forward manager properties
    var selectedRootFolder: WhisparrRootFolder? {
        get { settingsManager.selectedRootFolder }
        set { settingsManager.selectedRootFolder = newValue }
    }
    
    var selectedQualityProfile: WhisparrQualityProfile? {
        get { settingsManager.selectedQualityProfile }
        set { settingsManager.selectedQualityProfile = newValue }
    }
    
    var addedMovie: WhisparrScene? {
        addManager.addedMovie
    }
    
    var performerDetails: [String: StashDBPerformer] {
        performerManager.performerDetails
    }
    
    var localPerformerIds: [String: String] {
        performerManager.localPerformerIds
    }
    
    var localPerformerOCounts: [String: Int] {
        performerManager.localPerformerOCounts
    }
    
    var localPerformerSceneCounts: [String: Int] {
        performerManager.localPerformerSceneCounts
    }
    
    var localImagePaths: [String: String] {
        performerManager.localImagePaths
    }
    
    /// Returns a list of 'female' performers from the search result credits.
    var femalePerformers: [WhisparrCredit] {
        performerManager.getFemalePerformers(from: searchResult.credits)
    }
    
    // MARK: - Initialization
    
    init(
        searchResult: WhisparrSearchResult,
        settings: SettingsStoreProtocol? = nil,
        stashDatabase: StashDatabase? = nil,
        whisparrDatabase: WhisparrDatabase? = nil,
        metadataStore: WhisparrMetadataService? = nil,
        performerService: WhisparrPerformerService? = nil,
        repository: WhisparrRepositoryProtocol? = nil,
        performerDataProvider: PerformerMatchServiceProtocol? = nil,
        studioMatchService: StudioMatchServiceProtocol? = nil
    ) {
        self.searchResult = searchResult
        let database = stashDatabase ?? .shared
        let metadata = metadataStore ?? .shared
        let perfService = performerService ?? .shared
        let repo = repository ?? WhisparrRepository()
        let perfDataProvider = performerDataProvider ?? PerformerMatchService(stashDatabase: database)
        
        // Initialize managers
        self.settingsManager = WhisparrSearchResultSettingsManager(metadataStore: metadata)
        self.addManager = WhisparrSearchResultAddManager(repository: repo)
        self.performerManager = WhisparrSearchResultPerformerManager(
            performerService: perfService,
            performerDataProvider: perfDataProvider
        )
        self.studioMatchService = studioMatchService ?? StudioMatchService(stashDatabase: database)
        
        logger.debug("🔧 WhisparrSearchResultDetailViewModel initialized")
    }
    
    // MARK: - Navigation Helpers
    
    /// Attempts to resolve a local studio match for a Whisparr search result.
    func resolveLocalStudio(studioForeignId: String?, studioTitle: String?) async -> Studio? {
        let result = await studioMatchService.checkLocalStudios(identifiers: [
            (externalId: studioForeignId ?? "", name: studioTitle ?? "")
        ])
        
        if let localId = result.ids.values.first {
            return Studio(id: localId, name: studioTitle ?? "Unknown Studio")
        }
        
        return nil
    }
    

    
    // MARK: - Public Methods
    
    /// Clears any active error message.
    func clearError() {
        operationState = .idle
        settingsManager.clearError()
        addManager.clearMessages()
    }
    
    /// Fetches root folders and quality profiles from the Whisparr API via the store.
    func loadWhisparrSettings() async {
        operationState = .loadingSettings
        await settingsManager.loadSettings()
        
        if let error = settingsManager.errorMessage {
             operationState = .error(error)
        } else {
             operationState = .idle
        }
    }
    
    /// Adds the movie to the user's Whisparr library.
    @discardableResult
    func addToWhisparr() async -> Bool {
        guard let rootFolder = settingsManager.selectedRootFolder,
              let qualityProfile = settingsManager.selectedQualityProfile else {
            logger.error("❌ Cannot add - missing root folder or quality profile")
            return false
        }
        
        operationState = .adding
        
        let success = await addManager.addToWhisparr(
            searchResult: searchResult,
            rootFolder: rootFolder,
            qualityProfile: qualityProfile
        )
        
        if success {
            operationState = .success("Added to Whisparr!")
        } else if let error = addManager.errorMessage {
            operationState = .error(error)
        }
        
        return success
    }
    
    /// Triggers an automatic search for the newly added movie.
    func performAutomaticSearch(for movie: WhisparrScene) async -> Bool {
        operationState = .searching
        
        let success = await addManager.performAutomaticSearch(for: movie)
        
        if success {
            operationState = .success("Search started!")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            operationState = .idle
        } else if let error = addManager.errorMessage {
            operationState = .error(error)
        }
        
        return success
    }
    
    /// Fetches detailed performer information from StashDB for all female performers.
    func loadPerformerDetails() async {
        await performerManager.loadPerformerDetails(for: searchResult.credits)
    }
    
    /// Checks the local StashDB database for matching performers.
    func checkLocalPerformers() async {
        await performerManager.checkLocalPerformers(for: searchResult.credits)
    }
}
