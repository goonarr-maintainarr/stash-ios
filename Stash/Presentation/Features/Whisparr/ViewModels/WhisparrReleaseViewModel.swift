import Foundation
import SwiftUI
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrReleaseViewModel")

/// A ViewModel responsible for searching, filtering, sorting, and downloading releases from Whisparr.
///
/// `WhisparrReleaseViewModel` manages the state of the release search results screen, allowing users
/// to find and grab releases for a specific movie.
@MainActor
@Observable
class WhisparrReleaseViewModel {
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    /// The current state of the view.
    var state: ViewState = .idle
    
    /// The list of releases currently displayed after applying filters and sorting.
    var displayedReleases: [WhisparrRelease] = []
    
    // MARK: - Managers
    
    private let dataManager: WhisparrReleaseDataManager
    private let filterManager: WhisparrReleaseFilterManager
    private let sortManager: WhisparrReleaseSortManager
    
    // MARK: - Computed Properties
    
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
    
    var error: Error? {
        if case .error(let message) = state { 
            return NSError(domain: "WhisparrRelease", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return nil
    }
    
    // Forward manager properties
    var releases: [WhisparrRelease] {
        dataManager.releases
    }
    
    var filters: WhisparrReleaseFilters {
        get { filterManager.filters }
        set { 
            filterManager.filters = newValue
            applyFiltersAndSort()
        }
    }
    
    var availableProtocols: [String] {
        filterManager.availableProtocols
    }
    
    var availableIndexers: [String] {
        filterManager.availableIndexers
    }
    
    var sort: WhisparrReleaseSort {
        get { sortManager.sort }
        set { 
            sortManager.sort = newValue
            applyFiltersAndSort()
        }
    }
    
    var sortAscending: Bool {
        get { sortManager.sortAscending }
        set { 
            sortManager.sortAscending = newValue
            applyFiltersAndSort()
        }
    }
    
    // MARK: - Initialization
    
    /// Initializes the `WhisparrReleaseViewModel`.
    /// - Parameter repository: The repository to use for data access. Defaults to `WhisparrRepository`.
    init(repository: WhisparrRepositoryProtocol? = nil) {
        let repo = repository ?? WhisparrRepository()
        
        // Initialize managers
        self.dataManager = WhisparrReleaseDataManager(repository: repo)
        self.filterManager = WhisparrReleaseFilterManager()
        self.sortManager = WhisparrReleaseSortManager()
        
        logger.info("🎬 WhisparrReleaseViewModel initialized")
    }
    
    // MARK: - Public Methods
    
    /// Performs a search for releases associated with a specific movie ID.
    ///
    /// - Parameter movieId: The Whisparr ID of the movie.
    /// - Parameter term: Optional search term to filter results.
    func search(movieId: Int, term: String? = nil) async {
        logger.info("🔍 ViewModel.search called - movieId: \(movieId)")
        state = .loading
        
        do {
            let fetchedReleases = try await dataManager.search(movieId: movieId, term: term)
            logger.info("✅ fetchedReleases: \(fetchedReleases.count)")
            
            filterManager.extractFilterOptions(from: fetchedReleases)
            applyFiltersAndSort()
            
            logger.info("📊 after filtering: \(self.displayedReleases.count) / \(self.releases.count)")
            state = .loaded
        } catch {
            logger.error("❌ Search failed: \(error.localizedDescription, privacy: .public)")
            state = .error(error.localizedDescription)
        }
    }
    
    /// Triggers a remote search command to Whisparr to scan indexers for this movie.
    ///
    /// - Parameter movieId: The Whisparr ID of the movie.
    /// - Returns: `true` if command started successfully.
    func triggerRemoteSearch(movieId: Int) async -> Bool {
        do {
             try await dataManager.triggerRemoteSearch(movieId: movieId)
             return true
        } catch {
             logger.error("❌ Remote search trigger failed: \(error.localizedDescription)")
             return false
        }
    }
    
    /// Triggers a download for a specific release.
    ///
    /// - Parameter release: The release to download.
    /// - Returns: `true` if the download was successfully initiated, `false` otherwise.
    func download(release: WhisparrRelease) async -> Bool {
        do {
            try await dataManager.download(release: release)
            return true
        } catch {
            state = .error(error.localizedDescription)
            return false
        }
    }
    
    /// Updates the "Show Rejected" filter preference and reapplies filters.
    ///
    /// - Parameter show: Whether to show rejected releases.
    func updateFilterShowRejected(_ show: Bool) {
        filterManager.updateShowRejected(show)
        applyFiltersAndSort()
    }
    
    // MARK: - Private Methods
    
    /// Applies current filters and sorting logic and updates `displayedReleases`.
    private func applyFiltersAndSort() {
        let releases = dataManager.releases
        
        // Apply filters
        let filtered = filterManager.applyFilters(to: releases)
        
        // Apply sort
        let sorted = sortManager.applySort(to: filtered)
        
        displayedReleases = sorted
    }
}

