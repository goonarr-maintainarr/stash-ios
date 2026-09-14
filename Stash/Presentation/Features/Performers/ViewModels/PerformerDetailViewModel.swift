import Foundation
import Observation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerDetail")

/// Represents the loading state of the scenes section (for lazy loading).
enum PerformerScenesLoadState: Equatable {
    /// Scenes haven't been loaded yet
    case idle
    /// Scenes are loading
    case loading
    /// Scenes have been loaded
    case loaded
    /// Error loading scenes
    case error(String)
}

/// A ViewModel responsible for managing the details and scenes of a specific Performer.
@MainActor
@Observable
final class PerformerDetailViewModel {
    /// Represents the state of the performer detail view.
    enum State: Equatable {
        /// Data is loading.
        case loading
        /// Data is available for display.
        case content(Performer, [Scene])
        /// An error occurred.
        case error(String)
    }
    
    // MARK: - Observable State
    
    /// The current state of the view model.
    var state: State = .loading
    
    // MARK: - Managers
    
    private let dataManager: PerformerDataManager
    private let sceneSorter: PerformerSceneSorter
    private let stashIDManager: PerformerStashIDManager
    private let notificationManager: PerformerNotificationManager
    
    // MARK: - Dependencies
    
    let stashDBRepository: StashDBRepositoryProtocol
    private let database: StashDatabase
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    private var performerUpdateTask: Task<Void, Never>?
    private var sceneUpdateTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var performer: Performer? {
        if case .content(let p, _) = state { return p }
        return nil
    }
    
    var scenes: [Scene] {
        if case .content(_, let s) = state { return s }
        return []
    }
    
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
    
    var errorMessage: String? {
        get {
            if case .error(let m) = state { return m }
            return nil
        }
        set {
            if let message = newValue {
                state = .error(message)
            } else if case .error = state {
                state = .loading
            }
        }
    }
    
    var sortType: SceneSortType {
        get { sceneSorter.sortType }
        set { 
            if sceneSorter.sortType != newValue {
                sceneSorter.sortType = newValue
                if case .content(let p, _) = state {
                    sortAndUpdateState(for: p)
                }
            }
        }
    }
    
    var sortDirection: String {
        get { sceneSorter.sortDirection }
        set { 
            if sceneSorter.sortDirection != newValue {
                sceneSorter.sortDirection = newValue
                if case .content(let p, _) = state {
                    sortAndUpdateState(for: p)
                }
            }
        }
    }
    
    var scenesLoadState: PerformerScenesLoadState {
        dataManager.scenesLoadState
    }
    
    var selectedStashID: Performer.StashID? {
        get { stashIDManager.selectedStashID }
        set { stashIDManager.selectedStashID = newValue }
    }
    
    // MARK: - Initialization
    
    init(
        dataManager: PerformerDataManager,
        sceneSorter: PerformerSceneSorter,
        stashIDManager: PerformerStashIDManager,
        notificationManager: PerformerNotificationManager,
        stashDBRepository: StashDBRepositoryProtocol,
        database: StashDatabase
    ) {
        self.stashDBRepository = stashDBRepository
        self.database = database
        
        // Injected managers
        self.dataManager = dataManager
        self.sceneSorter = sceneSorter
        self.stashIDManager = stashIDManager
        self.notificationManager = notificationManager
        
        logger.info("🏗️ PerformerDetailViewModel initialized")
        
        setupManagers()
    }
    
    // MARK: - Setup
    
    private func setupManagers() {
        logger.debug("🔧 Setting up manager callbacks")
        
        // Setup notification callbacks
        notificationManager.setupCallbacks(
            onPerformerUpdated: { [weak self] performerId in
                guard let self = self,
                      case .content(let current, _) = self.state,
                      current.id == performerId else { return }
                self.performerUpdateTask?.cancel()
                self.performerUpdateTask = Task {
                    await self.fetchPerformerDetails(id: performerId, forceRefresh: true)
                }
            },
            onSceneUpdated: { [weak self] sceneId in
                guard let self = self else { return }
                self.sceneUpdateTask?.cancel()
                self.sceneUpdateTask = Task {
                    if let updatedScene = try? await self.database.fetchSceneDetails(id: sceneId)?.scene {
                        await MainActor.run {
                            self.dataManager.updateScene(updatedScene)
                            if case .content(let p, _) = self.state {
                                self.sortAndUpdateState(for: p)
                            }
                        }
                    }
                }
            }
        )
        
        logger.info("✅ Manager callbacks set up successfully")
    }
    
    // MARK: - Data Loading
    
    func fetchPerformerDetails(id: String, forceRefresh: Bool = false) async {
        if !forceRefresh {
            if case .loading = state, case .error = state {
                state = .loading
            } else if case .content = state {
                // Keep content while refreshing
            } else {
                state = .loading
            }
        }
        
        do {
            let (performer, scenes) = try await dataManager.fetchPerformerDetails(
                id: id,
                forceRefresh: forceRefresh,
                onFreshData: { [weak self] freshPerformer, freshScenes in
                    guard let self = self else { return }
                    self.sortAndUpdateState(for: freshPerformer, from: freshScenes)
                }
            )
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                self.sortAndUpdateState(for: performer, from: scenes)
            }
        } catch is CancellationError {
            logger.info("🚫 fetchPerformerDetails cancelled")
        } catch {
            if Task.isCancelled { return }
            await MainActor.run {
                self.state = .error("Failed to load performer: \(error.localizedDescription)")
            }
        }
    }
    
    func deletePerformer(id: String) async throws {
        try await dataManager.deletePerformer(id: id)
    }
    
    // MARK: - Helper Methods
    
    private func sortAndUpdateState(for performer: Performer, from sourceScenes: [Scene]? = nil) {
        let scenesToSort = sourceScenes ?? dataManager.allFetchedScenes
        let sortedScenes = sceneSorter.sortScenes(scenesToSort)
        state = .content(performer, sortedScenes)
    }
    
    // MARK: - StashID Management
    
    func selectStashID(_ stashID: Performer.StashID) {
        stashIDManager.selectStashID(stashID)
    }
    
    func clearStashSelection() {
        stashIDManager.clearSelection()
    }
}
