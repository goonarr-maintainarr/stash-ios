import Foundation
import SwiftUI
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBPerformerScenes")

/// A ViewModel responsible for fetching and displaying scenes for a specific performer from StashDB.
///
/// `StashDBPerformerScenesViewModel` handles fetching scenes, filtering out scenes already present in the user's
/// Whisparr library, and paginating the results. It also applies user preferences for filtering out VR content
/// and compilations.
@MainActor
@Observable
class StashDBPerformerScenesViewModel {
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    /// The current state of the view.
    var state: ViewState = .idle
    
    /// The list of scenes currently displayed (paginated).
    var scenes: [StashDBScene] = []
    
    /// Indicates if there are more scenes to load from the local filtered set.
    var hasMore = true
    
    /// Indicates if all fetched scenes for the performer are already in the Whisparr library.
    var allScenesOwned = false
    

    
    private let repository: StashDBRepositoryProtocol
    private let whisparrRepository: WhisparrRepositoryProtocol
    private let performerId: String
    private let settings: SettingsStoreProtocol
    
    var excludingVR: Bool { settings.excludeVRFromStashDB }
    var excludingCompilations: Bool { settings.excludeCompilationsFromStashDB }
    var excludingOwned: Bool { settings.excludeOwnedScenesFromStashDB }
    
    /// The total count of scenes found in StashDB that are NOT in the library.
    /// The total count of scenes found in StashDB that are NOT in the library.
    var totalFilteredCount: Int = 0
    
    private var missingStashIds: [String] = []
    private let pageSize = 40
    
    /// Initializes the `StashDBPerformerScenesViewModel`.
    ///
    /// - Parameters:
    ///   - repository: The repository for StashDB API access.
    ///   - whisparrRepository: The repository for checking Whisparr library status.
    ///   - performerId: The StashDB ID of the performer.
    init(repository: StashDBRepositoryProtocol, 
         whisparrRepository: WhisparrRepositoryProtocol,
         performerId: String,
         settings: SettingsStoreProtocol) {
        self.repository = repository
        self.whisparrRepository = whisparrRepository
        self.performerId = performerId
        self.settings = settings
    }
    
    /// Clears the current error state.
    func clearError() {
        if case .error = state {
            state = .idle
        }
    }
    
    /// Loads scenes from StashDB using two-phase fetch (IDs first, then details).
    func loadScenes() async {
        guard state != .loading else { return }
        
        if scenes.isEmpty {
            state = .loading
            
            do {
                // Phase 1: Fetch ALL IDs from StashDB (lightweight)
                let allStashIds = try await repository.fetchPerformerSceneIds(
                    performerId: performerId,
                    excludeVR: settings.excludeVRFromStashDB,
                    excludeCompilations: settings.excludeCompilationsFromStashDB
                )
                
                if settings.excludeOwnedScenesFromStashDB {
                    // Phase 2: Filter against local library
                    let ownedStashIds = Set(try await whisparrRepository.fetchAllSceneStashIds())
                    missingStashIds = allStashIds.filter { !ownedStashIds.contains($0) }
                    
                    totalFilteredCount = missingStashIds.count
                    allScenesOwned = !allStashIds.isEmpty && missingStashIds.isEmpty
                    
                } else {
                    // Start missingStashIds with ALL IDs
                    missingStashIds = allStashIds
                    
                    totalFilteredCount = missingStashIds.count
                    
                    // Logic for allScenesOwned:
                    // If we exclude owned scenes is FALSE (i.e., we show everything),
                    // we should NEVER show the "All scenes owned!" empty state
                    // unless the performer truly has 0 scenes total.
                    allScenesOwned = allStashIds.isEmpty 
                }
                
                if missingStashIds.isEmpty {
                    state = .loaded
                } else {
                    // Phase 3: Load first page of details
                    await fetchNextPageBatch()
                }
                
            } catch {
                if !Task.isCancelled {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    /// Loads the next page of scenes from the missing IDs list.
    func loadNextPage() {
        guard hasMore && state != .loading else { return }
        
        state = .loading
        Task {
            await fetchNextPageBatch()
        }
    }
    
    /// Internal method to fetch details for the next batch of IDs.
    private func fetchNextPageBatch() async {
        let currentCount = scenes.count
        let remainingIds = missingStashIds.dropFirst(currentCount)
        let batchIds = Array(remainingIds.prefix(pageSize))
        
        guard !batchIds.isEmpty else {
            hasMore = false
            state = .loaded
            return
        }
        
        do {
            // Fetch specific scenes by their IDs (filtered list)
            let newScenes = try await repository.fetchScenes(ids: batchIds)
            
            scenes.append(contentsOf: newScenes)
            
            hasMore = scenes.count < missingStashIds.count
            state = .loaded
            
        } catch {
            if !Task.isCancelled {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    /// Clears the current data and reloads from the API.
    func refresh() async {
        scenes = []
        missingStashIds = []
        totalFilteredCount = 0
        allScenesOwned = false
        state = .idle
        await loadScenes()
    }
}
