import Foundation
import Observation
import SwiftUI // For Animation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBCategoryDetailViewModel")

/// A ViewModel responsible for displaying the details of a specific StashDB scene category.
///
/// `StashDBCategoryDetailViewModel` primarily handles displaying the list of scenes associated with a category
/// (like "Recent Releases" or "Upcoming") and refreshing that data from the StashDB API.
@MainActor
@Observable
final class StashDBCategoryDetailViewModel {
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case refreshing
        case loaded
        case error(String)
    }
    
    /// The current state of the view.
    var state: ViewState = .idle
    
    /// The list of scenes currently displayed in the category.
    var displayedScenes: [StashDBScene] = []
    
    // MARK: - Computed Properties for Compatibility
    
    var isRefreshing: Bool {
        if case .refreshing = state { return true }
        return false
    }
    
    private let category: SceneCategory
    
    // Dependencies
    // Dependencies
    private let settingsStore: SettingsStoreProtocol
    private let whisparrDatabase: WhisparrDatabase
    private let stashDBRepository: StashDBRepositoryProtocol
    
    /// A formatted navigation title including the category name and item count.
    var navigationTitle: String {
        if let count = category.count {
            return "\(category.title) · \(count.formatted())"
        }
        return category.title
    }
    
    /// Initializes the `StashDBCategoryDetailViewModel`.
    ///
    /// - Parameter category: The scene category to display.
    init(category: SceneCategory, 
         stashDBRepository: StashDBRepositoryProtocol,
         settings: SettingsStoreProtocol,
         whisparrDatabase: WhisparrDatabase
    ) {
        self.category = category
        self.displayedScenes = category.stashDBScenes
        self.stashDBRepository = stashDBRepository
        self.settingsStore = settings
        self.whisparrDatabase = whisparrDatabase
    }
    
    /// Loads the initial scenes from the category model.
    func loadScenes() {
        // Initial load from category
        self.displayedScenes = category.stashDBScenes
    }
    
    /// Refreshes the category data from the StashDB API.
    ///
    /// This specific implementation currently re-fetches the "Feed" data (favorite performers and studios),
    /// filters it, and updates the display.
    ///
    /// - Returns: `true` if the refresh was successful, `false` otherwise.
    func refreshData() async -> Bool {
        guard !settingsStore.stashDBApiKey.isEmpty else { return false }
        
        state = .refreshing
        
        do {
            // Re-implementing the favorites fetch logic using Repository which now centralizes it
            let performerdIds = try await stashDBRepository.fetchFavoritePerformersOverview(page: 1, perPage: 1000).performers.map { $0.id }
            let studioIds = try await stashDBRepository.fetchFavoriteStudios().studios.map { $0.id }
            
            if performerdIds.isEmpty && studioIds.isEmpty {
                withAnimation {
                    self.displayedScenes = []
                }
                state = .loaded
                return true
            }
            
            // 3. Fetch scenes
            let scenesData = try await stashDBRepository.fetchScenesByPerformersAndStudiosOverview(
                performerIds: performerdIds,
                studioIds: studioIds,
                excludeVR: settingsStore.excludeVRFromStashDB,
                excludeCompilations: settingsStore.excludeCompilationsFromStashDB
            )
            
            // 4. Filter out scenes already in Whisparr
            let whisparrStashIds = try await whisparrDatabase.fetchAllSceneStashIds()
            let filteredScenes = scenesData.scenes.filter { !whisparrStashIds.contains($0.id) }
            
            withAnimation {
                self.displayedScenes = filteredScenes
            }
            state = .loaded
            return true
            
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                logger.info("StashDB refresh cancelled")
            } else if error is CancellationError {
                logger.info("StashDB refresh cancelled")
            } else {
                logger.error("Failed to refresh StashDB scenes: \(error)")
            }
            state = .error(error.localizedDescription)
            return false
        }
    }
}
