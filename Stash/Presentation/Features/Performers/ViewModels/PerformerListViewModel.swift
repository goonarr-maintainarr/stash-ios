import Foundation
import os
import Observation
import Nuke

/// Layout options for the Performer List
enum PerformerLayoutType: Int, Codable, CaseIterable, Identifiable {
    case grid3x = 0
    case grid2x = 1
    case list = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .grid3x: return "Grid (Small)"
        case .grid2x: return "Grid (Large)"
        case .list: return "List"
        }
    }
    
    var iconName: String {
        switch self {
        case .grid3x: return "square.grid.3x2"
        case .grid2x: return "square.grid.2x2"
        case .list: return "rectangle.grid.1x2"
        }
    }
}

/// A ViewModel responsible for managing the list of performers.
///
/// Uses `@Observable` for modern SwiftUI integration with granular observation updates.
/// Owns a `PerformerListState` for all observable state, replacing inheritance from `BaseListViewModel`.
@MainActor
@Observable
final class PerformerListViewModel {
    
    private nonisolated let observers = ObserversContainer()
    
    // MARK: - Observable State
    
    /// All observable state is encapsulated here.
    private(set) var listState = ListState<Performer>()
    
    // MARK: - Sort State (Specific to Performers)
    private var _sortType: PerformerSortType = .name
    private var _sortDirection: String = "ASC"
    
    // MARK: - Convenience Accessors (View-facing API)
    
    /// The currently displayed performers.
    var performers: [Performer] { listState.displayedItems }
    
    /// The current view state (loading, content, empty, error).
    var state: ListViewState<Performer> {
        if listState.isLoading { return .loading }
        if let error = listState.errorMessage { return .error(error) }
        if listState.displayedItems.isEmpty {
            return .empty
        }
        return .content(listState.displayedItems)
    }
    
    /// Whether the initial load or a reset fetch is in progress.
    var isFetching: Bool { listState.isFetching }
    
    /// Whether the list is currently refreshing (pull-to-refresh).
    var isRefreshing: Bool { listState.isRefreshing }
    
    /// Whether more pages are available to load.
    var hasMore: Bool { listState.hasMore }
    
    /// The total number of performers matching the current filters.
    var totalCount: Int { listState.allItems.count }
    
    /// Bound to the search bar. Triggers debounced filtering.
    var searchText: String {
        get { listState.searchText }
        set {
            if listState.searchText != newValue {
                listState.searchText = newValue
                scheduleSearch(query: newValue)
            }
        }
    }
    
    /// The current sort criteria.
    /// The current sort criteria.
    var sortType: PerformerSortType {
        get { _sortType }
        set {
            if _sortType != newValue {
                _sortType = newValue
                observers.filterSortTask?.cancel()
                observers.filterSortTask = Task { await applyFilterAndSort() }
                // Persist
                settings.performerSortType = newValue.rawValue
            }
        }
    }
    
    /// The current sort direction ("ASC" or "DESC").
    /// The current sort direction ("ASC" or "DESC").
    var sortDirection: String {
        get { _sortDirection }
        set {
            if _sortDirection != newValue {
                _sortDirection = newValue
                observers.filterSortTask?.cancel()
                observers.filterSortTask = Task { await applyFilterAndSort() }
                // Persist
                settings.performerSortDirection = newValue
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let repository: any PerformerRepositoryProtocol
    private let settings: SettingsStore
    
    // MARK: - Initialization
    
    init(
        repository: any PerformerRepositoryProtocol,
        settings: SettingsStore
    ) {
        self.repository = repository
        self.settings = settings
        
        // Load initial sort state
        if let type = PerformerSortType(rawValue: settings.performerSortType) {
            self._sortType = type
        }
        self._sortDirection = settings.performerSortDirection
        
        setupNotificationObservers()
        Logger.performers.info("✨ Initializing PerformerListViewModel")
    }
    
    deinit {
        let obs = observers
        if let o = obs.performerUpdateObserver { NotificationCenter.default.removeObserver(o) }
        obs.searchTask?.cancel()
        obs.filterSortTask?.cancel()
    }
    
    // MARK: - Smart Sync
    
    /// Checks for updates from the server (incremental sync).
    func checkForUpdates() async {
        do {
            let changedPerformers = try await repository.syncChangedPerformers()
            if !changedPerformers.isEmpty {
                Logger.performers.info("🔄 SmartSync: \(changedPerformers.count) performers updated")
                await loadFromCache()
            }
        } catch {
            Logger.performers.error("❌ SmartSync failed: \(error.localizedDescription)")
            // Fallback to cache if sync fails
            if !listState.hasLoadedFromCache {
                await loadFromCache()
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Loads all performers from the local cache.
    func loadFromCache() async {
        Logger.performers.info("💾 Loading performers from cache...")
        do {
            let performers = try await repository.getCachedPerformers()
            listState.cachedItems = performers
            listState.hasLoadedFromCache = true
            await applyFilterAndSort()
            listState.isLoading = false
            Logger.performers.info("💾 Loaded \(performers.count) performers from cache")
        } catch {
            Logger.performers.error("❌ Failed to load performers from cache: \(error.localizedDescription)")
            listState.errorMessage = "Failed to load list"
            listState.isLoading = false
        }
    }
    
    /// Fetches performers from the repository.
    /// - Parameter reset: If true, performs a full sync from the API.
    func fetchItems(reset: Bool = false) async {
        Logger.performers.info("🌍 Fetching performers from API (reset: \(reset))...")
        
        listState.isFetching = true
        listState.errorMessage = nil
        if reset {
            listState.isRefreshing = true
        }
        
        defer { 
            listState.isFetching = false 
            if reset { listState.isRefreshing = false }
        }
        
            do {
                let result: PerformerRepositoryResult
                if reset {
                    let performers = try await repository.syncNewPerformers(progressHandler: nil)
                    result = PerformerRepositoryResult(performers: performers, totalCount: performers.count, hasMore: false, source: .api)
                } else {
                    let all = try await repository.getAllPerformers(progressHandler: nil)
                    result = PerformerRepositoryResult(performers: all, totalCount: all.count, hasMore: false, source: .cache)
                }
                
                listState.cachedItems = result.performers
            await applyFilterAndSort()
            Logger.performers.info("✅ Fetched \(result.performers.count) performers (source: \(String(describing: result.source)))")
        } catch {
            Logger.performers.error("❌ Full sync failed: \(error.localizedDescription)")
            if reset && listState.allItems.isEmpty {
                listState.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Appends the next page of items.
    func loadMore(currentItem: Performer?) async {
        guard let currentItem = currentItem else { return }
        
        // Prefetch images for upcoming performers
        prefetchUpcomingImages(from: currentItem)
        
        // Check if at end of list and should load more
        guard let index = performers.firstIndex(where: { $0.id == currentItem.id }),
              index >= performers.count - 10,
              hasMore else { return }
        
        Logger.performers.debug("📜 Loading next page of performers...")
        listState.appendPage()
        Logger.performers.debug("✅ Appended page. Current count: \(self.performers.count)")
    }
    
    private func prefetchUpcomingImages(from performer: Performer) {
        guard let currentIndex = performers.firstIndex(where: { $0.id == performer.id }) else { return }
        
        let upcoming = Array(performers.dropFirst(currentIndex + 1).prefix(10))
        if !upcoming.isEmpty {
            Logger.performers.debug("🖼️ Prefetching images for \(upcoming.count) performers")
            Task {
                await repository.prefetchImages(for: upcoming, count: 10)
            }
        }
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationObservers() {
        observers.performerUpdateObserver = NotificationCenter.default.addObserver(
            forName: .performerUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let performerId = notification.userInfo?["id"] as? String else { return }
            
            Logger.performers.info("📢 Performer \(performerId) updated, updating in place")
            
            Task { @MainActor in
                // Invalidate Nuke cache for this performer's image
                if let performer = self.listState.allItems.first(where: { $0.id == performerId }),
                   let imagePath = performer.image_path,
                   let url = self.settings.createImageUrl(path: imagePath) {
                    ImagePipeline.shared.cache.removeCachedImage(for: ImageRequest(url: url))
                    Logger.performers.debug("🗑️ Cleared image cache for performer \(performerId)")
                }
                await self.updatePerformerInPlace(performerId: performerId)
            }
        }
    }
    
    // MARK: - Search Debouncing
    
    private func scheduleSearch(query: String) {
        observers.searchTask?.cancel()
        observers.searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if !Task.isCancelled {
                await applyFilterAndSort()
            }
        }
    }
    
    // MARK: - Filtering & Sorting
    
    /// Processes the full cached list based on current search, sort, and direction.
    private func applyFilterAndSort() async {
        let query = listState.searchText
        let items = listState.cachedItems
        let type = self.sortType
        let direction = self.sortDirection
        
        // Background computation for filtering/sorting
        let sortedItems = await Task.detached(priority: .userInitiated) {
            let filtered = Self.filterPerformers(items: items, query: query)
            return Self.sortPerformers(items: filtered, type: type, direction: direction)
        }.value
        
        listState.updateContent(sortedItems)
        Logger.performers.debug("✅ Filter/Sort complete. Count: \(sortedItems.count)")
    }
    
    // MARK: - In-Place Updates
    
    private func updatePerformerInPlace(performerId: String) async {
        do {
            // Efficient single-performer lookup instead of loading all performers
            guard let updatedPerformer = try await repository.getCachedPerformerById(performerId) else {
                Logger.performers.warning("⚠️ Could not find performer \(performerId) in cache")
                return
            }
            
            listState.updateItemInPlace(updatedPerformer)
            Logger.performers.info("✅ Updated performer \(performerId) in performer list")
        } catch {
            Logger.performers.error("❌ Failed to update performer in list: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Static Logic
    
    nonisolated static func filterPerformers(items: [Performer], query: String) -> [Performer] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        
        return items.filter { performer in
            performer.name?.localizedCaseInsensitiveContains(q) == true
            || performer.details?.localizedCaseInsensitiveContains(q) == true
            || performer.alias_list?.contains { $0.localizedCaseInsensitiveContains(q) } == true
        }
    }
    
    nonisolated static func sortPerformers(items: [Performer], type: PerformerSortType, direction: String) -> [Performer] {
        let isAsc = direction == "ASC"
        
        return items.sorted { a, b in
            let comparison: Bool
            switch type {
            case .name:
                comparison = (a.name ?? "") < (b.name ?? "")
            case .sceneCount:
                comparison = (a.scene_count ?? 0) < (b.scene_count ?? 0)
            case .oCounter:
                comparison = (a.o_counter ?? 0) < (b.o_counter ?? 0)
            case .updatedAt:
                comparison = (a.updated_at ?? "") < (b.updated_at ?? "")
            default:
                comparison = (a.created_at ?? "") < (b.created_at ?? "")
            }
            return isAsc ? comparison : !comparison
        }
    }
}

/// Thread-safe container for observers to allow safe cleanup in nonisolated deinit.
private final class ObserversContainer: @unchecked Sendable {
    var performerUpdateObserver: NSObjectProtocol?
    var searchTask: Task<Void, Never>?
    var filterSortTask: Task<Void, Never>?
    
    nonisolated init() {}
}
