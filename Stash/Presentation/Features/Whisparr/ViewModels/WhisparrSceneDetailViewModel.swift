import Foundation
import Observation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSceneDetailViewModel")

@MainActor
@Observable
/// A ViewModel responsible for managing the details and interactions for a specific Whisparr scene.
///
/// Coordinates scene operations and performer data using composition pattern.
final class WhisparrSceneDetailViewModel {
    
    // MARK: - Managers
    
    private let operationsManager: WhisparrSceneOperationsManager
    private let performerManager: WhisparrScenePerformerManager
    private let studioMatchService: StudioMatchServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    /// The current view state.
    var state: ViewState<WhisparrScene>
    
    var scene: WhisparrScene? { state.content }
    
    // MARK: - Forwarded Properties
    
    var operationState: WhisparrSceneOperationState {
        operationsManager.operationState
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
    
    var localSceneId: String? {
        performerManager.localSceneId
    }
    
    // MARK: - Computed Properties for Compatibility
    
    var isSearching: Bool {
        if case .searching = operationState { return true }
        return false
    }
    
    var searchError: String? {
        if case .error(let message) = operationState { return message }
        return nil
    }
    
    var isDeletingAndUnmonitoring: Bool {
        if case .deleting = operationState { return true }
        return false
    }
    
    var showSuccessToast: Bool {
        if case .success = operationState { return true }
        return false
    }
    
    var toastMessage: String {
        if case .success(let message) = operationState { return message }
        return ""
    }
    
    // MARK: - Dependencies
    
    private let repository: WhisparrRepositoryProtocol

    
    /// Returns a list of 'female' performers from the scene credits.
    ///
    /// This implementation assumes any performer not marked as 'MALE' is relevant for display priority.
    var femalePerformers: [WhisparrCredit] {
        guard let scene = self.scene else { return [] }
        return scene.credits.filter { credit in
            guard credit.performer.name != nil else { return false }
            return credit.performer.gender?.uppercased() != "MALE"
        }
    }
    
    /// Initializes the `WhisparrSceneDetailViewModel`.
    init(
        scene: WhisparrScene,
        operationsManager: WhisparrSceneOperationsManager,
        performerManager: WhisparrScenePerformerManager,
        studioMatchService: StudioMatchServiceProtocol? = nil,
        repository: WhisparrRepositoryProtocol? = nil
    ) {
        self.state = .content(scene)
        self.repository = repository ?? WhisparrRepository()
        
        // Injected managers
        self.operationsManager = operationsManager
        self.performerManager = performerManager
        self.studioMatchService = studioMatchService ?? StudioMatchService(stashDatabase: StashDatabase.shared)
        
        logger.debug("🔧 WhisparrSceneDetailViewModel initialized")
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        NotificationCenter.default.publisher(for: .whisparrMovieUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let movieId = notification.userInfo?["movieId"] as? Int,
                      self.scene?.id == movieId else {
                    return
                }
                
                logger.debug("📥 Received update for movie \(movieId), refreshing...")
                Task {
                    await self.refreshMovieData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation Helpers
    
    /// Attempts to resolve a local studio match for a Whisparr scene.
    func resolveLocalStudio(studioForeignId: String?, studioTitle: String?) async -> Studio? {
        let result = await studioMatchService.checkLocalStudios(identifiers: [
            (externalId: studioForeignId ?? "", name: studioTitle ?? "")
        ])
        
        if let localId = result.ids.values.first {
            return Studio(id: localId, name: studioTitle ?? "Unknown Studio")
        }
        
        return nil
    }
    
    /// Refreshes the movie data from the Whisparr API.
    func refreshMovieData() async {
        guard let currentScene = self.scene else { return }
        logger.debug("↻ Refreshing movie data for Scene ID: \(currentScene.id)")
        
        do {
            let refreshedScene = try await repository.fetchRemoteScene(id: currentScene.id)
            self.state = .content(refreshedScene)
            logger.info("✅ Successfully refreshed movie data")
        } catch {
            logger.error("❌ Failed to refresh movie data: \(error.localizedDescription)")
        }
    }
    
    /// Fetches detailed performer information from StashDB for all female performers in the scene.
    func loadPerformerDetails() async {
        await performerManager.loadPerformerDetails(for: femalePerformers)
    }
    
    /// Checks the local StashDB database for matching performers.
    func checkLocalPerformers() async {
        await performerManager.checkLocalPerformers(for: femalePerformers)
    }
    
    /// Checks if the scene exists in the local StashDB database.
    func checkLocalScene() async {
        await performerManager.checkLocalScene(foreignId: scene?.foreignId)
    }
    

    
    /// Triggers interactive search (POLLING) for this scene.
    /// - Returns: True if releases found, False otherwise.
    func performInteractiveSearch() async -> Bool {
        guard let scene = self.scene else { return false }
        return await operationsManager.performInteractiveSearch(sceneId: scene.id)
    }
    
    /// Triggers automatic search for this scene.
    func performAutomaticSearch() async -> Bool {
        guard let scene = self.scene else {
            logger.error("❌ No scene loaded")
            return false
        }
        return await operationsManager.performAutomaticSearch(sceneId: scene.id)
    }
    
    /// Toggles the monitoring status of the scene in Whisparr.
    /// Uses optimistic update: immediately updates UI, then confirms with API.
    func toggleMonitorStatus() async -> Bool {
        guard let currentScene = self.scene else { return false }
        let newMonitoredStatus = !currentScene.monitored
        
        // 1. Optimistically update UI immediately
        let optimisticScene = currentScene.with(monitored: newMonitoredStatus)
        self.state = .content(optimisticScene)
        logger.info("📊 Optimistic update: monitored = \(newMonitoredStatus)")
        
        do {
            // 2. Call API via manager and update with confirmed data
            let confirmedScene = try await operationsManager.toggleMonitorStatus(scene: currentScene)
            self.state = .content(confirmedScene)
            return true
        } catch {
            // 3. Rollback on failure
            logger.error("❌ Toggle failed, rolling back")
            self.state = .content(currentScene)
            return false
        }
    }
    
    /// Queues a refresh command to update metadata from foreign sources.
    func refreshSceneCommand() async -> Bool {
        guard let scene = self.scene else { return false }
        let success = await operationsManager.refreshScene(sceneId: scene.id)
        
        if success {
            await refreshMovieData()
        }
        
        return success
    }
    
    /// Deletes the scene from Whisparr and optionally the associated files.
    func deleteFileAndUnmonitor(deleteFiles: Bool, addImportExclusion: Bool) async -> Bool {
        guard let scene = self.scene else {
            logger.error("❌ No scene loaded")
            return false
        }
        return await operationsManager.deleteScene(
            scene: scene,
            deleteFiles: deleteFiles,
            addImportExclusion: addImportExclusion
        )
    }
}
