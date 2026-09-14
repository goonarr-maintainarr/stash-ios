import Foundation
import SwiftUI
import os
import Observation

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSceneListViewModel")

/// A ViewModel responsible for managing and displaying lists of Whisparr scenes.
///
/// `WhisparrSceneListViewModel` handles fetching, caching, filtering, sorting, and pagination of Whisparr scenes.
/// It delegates functionality to specialized managers for better separation of concerns.
///
/// Refactored to use composition via `WhisparrSceneListState`.
@MainActor
@Observable
class WhisparrSceneListViewModel {
    
    // MARK: - State
    
    /// The container for all observable state.
    private(set) var listState = ListState<WhisparrScene>()
    
    // MARK: - Specific State
    var syncState: SyncState = .idle
    private var _filterType: WhisparrFilterType = .all
    private var _sortType: WhisparrSortType = .dateAdded
    private var _sortDirection: String = "DESC"
    
    enum SyncState: Equatable {
        case idle
        case syncing(progress: Double, message: String)
    }
    
    // MARK: - Convenience Accessors
    
    var items: [WhisparrScene] { listState.displayedItems }
    var scenes: [WhisparrScene] { listState.displayedItems }
    var state: ListViewState<WhisparrScene> {
        if listState.isLoading { return .loading }
        if let error = listState.errorMessage { return .error(error) }
        if listState.displayedItems.isEmpty {
             return .empty
        }
        return .content(listState.displayedItems)
    }
    var isFetching: Bool { listState.isFetching }
    var isRefreshing: Bool { listState.isRefreshing }
    var hasMore: Bool { listState.hasMore }
    var totalCount: Int { listState.allItems.count }
    
    // var syncState handled by local property
    
    var syncProgress: Double {
        switch syncState {
        case .syncing(let progress, _): return progress
        case .idle: return 0.0
        }
    }
    
    var syncMessage: String {
        switch syncState {
        case .syncing(_, let message): return message
        case .idle: return ""
        }
    }
    
    var searchText: String {
        get { listState.searchText }
        set {
            if listState.searchText != newValue {
                listState.searchText = newValue
                // Debounce search
                scheduleSearch(query: newValue)
            }
        }
    }
    
    var sortType: WhisparrSortType {
        get { _sortType }
        set {
            if _sortType != newValue {
                _sortType = newValue
                logger.info("📋 sortType changed to: \(newValue.displayName, privacy: .public)")
                observers.filterTask?.cancel()
                observers.filterTask = Task { await handleFilterChange() }
            }
        }
    }
    
    var sortDirection: String {
        get { _sortDirection }
        set {
            if _sortDirection != newValue {
                _sortDirection = newValue
                logger.info("⬆️⬇️ sortDirection changed to: \(newValue, privacy: .public)")
                observers.filterTask?.cancel()
                observers.filterTask = Task { await handleFilterChange() }
            }
        }
    }
    
    var filterType: WhisparrFilterType {
        get { _filterType }
        set {
            if _filterType != newValue {
                _filterType = newValue
                logger.info("📍 filterType changed to: \(newValue.displayName, privacy: .public)")
                observers.filterTask?.cancel()
                observers.filterTask = Task { await handleFilterChange() }
            }
        }
    }
    
    // MARK: - Managers
    
    private let cacheSyncManager: WhisparrCacheSyncManager
    private let imagePrefetchManager: WhisparrImagePrefetchManager
    private let liveUpdatesManager: WhisparrLiveUpdatesManager
    private let studioMatchService: StudioMatchServiceProtocol
    
    // MARK: - Computed Properties
    
    /// Date of the last successful sync.
    var lastSyncDate: Date? {
        cacheSyncManager.lastSyncDate
    }
    
    // MARK: - Initialization
    
    init(repository: WhisparrRepositoryProtocol? = nil, studioMatchService: StudioMatchServiceProtocol? = nil) {
        let repo = repository ?? WhisparrRepository()
        
        self.cacheSyncManager = WhisparrCacheSyncManager(repository: repo)
        self.imagePrefetchManager = WhisparrImagePrefetchManager()
        self.liveUpdatesManager = WhisparrLiveUpdatesManager()
        self.studioMatchService = studioMatchService ?? StudioMatchService(stashDatabase: StashDatabase.shared)
        
        logger.info("🏭️ WhisparrSceneListViewModel initialized")
        
        setupLiveUpdates()
    }
    
    deinit {
        let obs = observers
        obs.searchTask?.cancel()
        obs.filterTask?.cancel()
        obs.refreshTask?.cancel()
    }
    
    // MARK: - Observer Storage
    
    private nonisolated let observers = WhisparrObserversContainer()
    
    private func scheduleSearch(query: String) {
        observers.searchTask?.cancel()
        observers.searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if !Task.isCancelled {
                await handleFilterChange()
            }
        }
    }
    
    // MARK: - Data Loading
    
    func fetchItems(reset: Bool = false) async {
        // Prevent concurrent refreshes
        guard !isRefreshing else {
            logger.info("⚠️ Refresh already in progress, skipping")
            return
        }
        
        await MainActor.run {
            listState.errorMessage = nil
            listState.isRefreshing = true
            self.syncState = .syncing(progress: 0.0, message: "Starting sync...")
        }
        
        do {
            try await cacheSyncManager.syncFromAPI { progress, message in
                Task { @MainActor in
                    self.syncState = .syncing(progress: progress, message: message)
                }
            }
            
            logger.info("✅ Refresh complete")
        } catch is CancellationError {
            logger.info("⚠️ Refresh task was cancelled")
            await MainActor.run {
                if !self.listState.displayedItems.isEmpty {
                     // Keep content
                }
            }
            return
        } catch {
            logger.error("❌ Failed to refresh: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                if self.listState.displayedItems.isEmpty {
                    self.listState.errorMessage = error.localizedDescription
                } else {
                    // Content remains
                }
                self.listState.isRefreshing = false // Ensure we reset this on error
                self.syncState = .idle
            }
            return
        }
        
        // Reload data after refresh completes
        await loadFromCache()
        
        await MainActor.run {
            let count = cacheSyncManager.allCachedScenes.count
            self.syncState = .syncing(progress: 1.0, message: "Synced \(count) scenes")
        }
        
        // Brief delay to show completion
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        await MainActor.run {
            self.syncState = .idle
            listState.isRefreshing = false
        }
    }
    
    /// Loads scenes from local cache and checks if refresh is needed.
    func loadScenes() async {
        logger.info("🚀 Loading scenes...")
        
        // Load from cache immediately
        await loadFromCache()
        
        // Preload all scenes in background for fast search
        if cacheSyncManager.allCachedScenes.isEmpty {
            do {
                try await cacheSyncManager.preloadAllScenes()
                // Update UI after preload
                await handleFilterChange()
            } catch {
                logger.error("❌ Failed to preload scenes: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        // Check if cache needs refresh
        if await cacheSyncManager.shouldRefreshCache() {
            await fetchItems(reset: true)
        }
    }
    
    func loadFromCache() async {
        do {
            // Load scenes from cache
            if cacheSyncManager.allCachedScenes.isEmpty {
                try await cacheSyncManager.loadFromCache()
            }
            
            // Apply filters and sorting
            await handleFilterChange()
            
            listState.hasLoadedFromCache = true
            listState.isFetching = false  // Enable pagination
            listState.isLoading = false
        } catch {
            logger.error("❌ Failed to load from cache: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                listState.errorMessage = error.localizedDescription
            }
            listState.hasLoadedFromCache = true
            listState.isFetching = false  // Enable pagination even on error
            listState.isLoading = false // ✅ error state is not loading state
        }
    }
    
    private func handleFilterChange() async {
        logger.info("🔄 Applying filters and reloading...")
        
        // Handle cutoff unmet filter separately
        var cutoffUnmetScenes: [WhisparrScene]? = nil
        let currentFilterType = self.filterType
        
        if currentFilterType == .cutoffUnmet {
            do {
                cutoffUnmetScenes = try await cacheSyncManager.loadCutoffUnmetScenes()
            } catch {
                logger.error("❌ Failed to load cutoff unmet scenes: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    listState.errorMessage = error.localizedDescription
                }
                return
            }
        }
        
        // Capture current state for background processing
        let allScenes = cacheSyncManager.allCachedScenes
        let currentSortType = self.sortType
        let currentSortDirection = self.sortDirection
        let currentSearchText = listState.searchText
        
        // Apply filters and sort in background
        let filteredScenes = await Task.detached(priority: .userInitiated) {
            var workingSet: [WhisparrScene]
            
            // Handle cutoff unmet filter separately
            if currentFilterType == .cutoffUnmet, let cutoffScenes = cutoffUnmetScenes {
                workingSet = cutoffScenes
            } else {
                // Apply filter type
                workingSet = Self.applyFilter(to: allScenes, filterType: currentFilterType)
            }
            
            // Apply search filter
            if !currentSearchText.isEmpty {
                workingSet = Self.applySearch(to: workingSet, searchText: currentSearchText)
            }
            
            // Apply sorting
            let sortedScenes = Self.applySort(to: workingSet, sortType: currentSortType, ascending: currentSortDirection == "ASC")
            return sortedScenes
        }.value
        
        // Update allItems via state (this will trigger updateContent which handles paging)
        
        await MainActor.run {
            listState.updateContent(filteredScenes)
        }
        
        // Prefetch visible images
        imagePrefetchManager.prefetchVisibleImages(scenes: items)
    }
    
    // MARK: - Pagination
    
    func loadMore(currentItem: WhisparrScene) async {
        // Prefetch upcoming images
        imagePrefetchManager.prefetchUpcomingImages(currentItem: currentItem, from: items)
        
        // Check if we need to load more
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }),
              index >= items.count - 10, // Load when within 10 items of bottom
              hasMore else { return }
        
        listState.appendPage()
    }
    
    // MARK: - Sorting
    
    /// Toggles the current sort direction.
    func toggleSortDirection() {
        sortDirection = self.sortDirection == "ASC" ? "DESC" : "ASC"
        logger.info("🔄 Toggled sort direction to: \(self.sortDirection, privacy: .public)")
    }
    
    // MARK: - Live Updates
    
    private func setupLiveUpdates() {
        liveUpdatesManager.onSceneUpdated = { [weak self] scene in
            self?.onSceneUpdated(scene)
        }
        
        liveUpdatesManager.onSceneDeleted = { [weak self] sceneId in
            self?.onSceneDeleted(sceneId)
        }
        
        
        liveUpdatesManager.onSceneRefreshNeeded = { [weak self] sceneId in
            self?.refreshSingleScene(id: sceneId)
        }
        
        liveUpdatesManager.onLibraryChanged = { [weak self] in
            self?.observers.refreshTask?.cancel()
            self?.observers.refreshTask = Task { @MainActor in
                await self?.fetchItems(reset: true)
            }
        }
    }
    
    private func refreshSingleScene(id: Int) {
        Task {
            do {
                // Fetch fresh data from API
                let updatedScene = try await cacheSyncManager.fetchScene(id: id)
                await MainActor.run {
                    self.onSceneUpdated(updatedScene)
                }
            } catch {
                logger.error("❌ Failed to refresh single scene \(id): \(error.localizedDescription)")
            }
        }
    }

    private func onSceneUpdated(_ scene: WhisparrScene) {
        logger.info("🔄 Handling scene update in ViewModel")
        
        var displayed = items
        var cached = cacheSyncManager.allCachedScenes
        var filtered = listState.allItems
        
        liveUpdatesManager.updateSceneInLists(
            scene,
            displayedScenes: &displayed,
            cachedScenes: &cached,
            filteredScenes: &filtered
        )
        
        // Update managers
        cacheSyncManager.allCachedScenes = cached
        
        // Update state in place
        // However, listState has methods for this too.
        
        listState.updateItemInPlace(scene)
    }
    
    private func onSceneDeleted(_ sceneId: Int) {
        logger.info("🗑️ Handling scene deletion in ViewModel")
        
        // Remove from manager cache
        cacheSyncManager.allCachedScenes.removeAll { $0.id == sceneId }
        
        // Update state
        // Update state
        if let index = listState.allItems.firstIndex(where: { $0.id == sceneId }) {
             var newItems = listState.allItems
             newItems.remove(at: index)
             listState.updateContent(newItems)
        }
    }
    
    // MARK: - Filtering & Sorting Logic
    
    private static nonisolated func applyFilter(to scenes: [WhisparrScene], filterType: WhisparrFilterType) -> [WhisparrScene] {
        switch filterType {
        case .all:
            return scenes
        case .monitored:
            return scenes.filter { $0.monitored }
        case .unmonitored:
            return scenes.filter { !$0.monitored }
        case .missing:
            return scenes.filter { !$0.hasFile }
        case .wanted:
            return scenes.filter { !$0.hasFile && $0.monitored }
        case .downloaded:
            return scenes.filter { $0.hasFile }
        case .dangling:
            return scenes.filter { $0.hasFile && !$0.monitored }
        case .cutoffUnmet:
            // Handled separately
            return scenes
        }
    }
    
    private static nonisolated func applySearch(to scenes: [WhisparrScene], searchText: String) -> [WhisparrScene] {
        return scenes.filter { scene in
            scene.title.localizedCaseInsensitiveContains(searchText) ||
            (scene.studioTitle?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (scene.code?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            scene.credits.contains(where: { $0.performer.name?.localizedCaseInsensitiveContains(searchText) ?? false })
        }
    }
    
    private static nonisolated func applySort(to scenes: [WhisparrScene], sortType: WhisparrSortType, ascending: Bool) -> [WhisparrScene] {
        switch sortType {
        case .title:
            return scenes.sorted { ascending ? $0.title < $1.title : $0.title > $1.title }
        case .year:
            return scenes.sorted { ascending ? $0.year < $1.year : $0.year > $1.year }
        case .dateAdded:
            return scenes.sorted { ascending ? $0.added < $1.added : $0.added > $1.added }
        case .fileSize:
            return scenes.sorted { ascending ? $0.sizeOnDisk < $1.sizeOnDisk : $0.sizeOnDisk > $1.sizeOnDisk }
        case .releaseDate:
            return scenes.sorted { (lhs, rhs) in
                guard let lhsDate = lhs.releaseDate, let rhsDate = rhs.releaseDate else {
                    return lhs.releaseDate != nil
                }
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
        }
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
}

/// Thread-safe container for observers to allow safe cleanup in nonisolated deinit.
private final class WhisparrObserversContainer: @unchecked Sendable {
    var searchTask: Task<Void, Never>?
    var filterTask: Task<Void, Never>?
    var refreshTask: Task<Void, Never>?
    
    nonisolated init() {}
}

