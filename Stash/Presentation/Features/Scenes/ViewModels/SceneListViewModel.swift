import Foundation
import SwiftUI
import os
import Observation
import Nuke

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneListViewModel")

/// A ViewModel responsible for managing the list of scenes.
///
/// Uses `@Observable` for modern SwiftUI integration with granular observation updates.
/// Owns a `SceneListState` for all observable state, replacing inheritance from `BaseListViewModel`.
@MainActor
@Observable
final class SceneListViewModel {
    
    // MARK: - Observer Storage
    
    private nonisolated let observers = ObserversContainer()
    
    // MARK: - Observable State
    
    /// All observable state is encapsulated here.
    private(set) var listState = ListState<Scene>()
    
    // MARK: - Sort State (Specific to Scenes)

    var randomSortOrder: [Scene]?
    
    // MARK: - Convenience Accessors (View-facing API)
    
    /// The currently displayed scenes.
    var scenes: [Scene] { listState.displayedItems }
    
    /// The current view state (loading, content, empty, error).
    var state: ListViewState<Scene> {
        if listState.isLoading { return .loading }
        if let error = listState.errorMessage { return .error(error) }
        if listState.displayedItems.isEmpty {
            return .empty
        }
        return .content(listState.displayedItems)
    }
    
    /// Whether a fetch operation is in progress.
    var isFetching: Bool { listState.isFetching }
    
    /// Total count of scenes (for display in navigation title).
    var totalCount: Int { listState.allItems.count }
    
    /// Whether more items can be loaded.
    var hasMore: Bool { listState.hasMore }
    
    /// The search text for filtering.
    var searchText: String {
        get { listState.searchText }
        set {
            if listState.searchText != newValue {
                listState.searchText = newValue
                scheduleSearch(query: newValue)
            }
        }
    }
    
    /// The current sort type.
    var sortType: SceneSortType {
        get { _sortType }
        set {
            if _sortType != newValue {
                _sortType = newValue
                observers.filterSortTask?.cancel()
                observers.filterSortTask = Task { await applyFilterAndSort() }
                // Persist
                settings.sceneSortType = newValue.rawValue
            }
        }
    }
    private var _sortType: SceneSortType = .date
    
    /// The current sort direction ("ASC" or "DESC").
    var sortDirection: String {
        get { _sortDirection }
        set {
            if _sortDirection != newValue {
                _sortDirection = newValue
                observers.filterSortTask?.cancel()
                observers.filterSortTask = Task { await applyFilterAndSort() }
                // Persist
                settings.sceneSortDirection = newValue
            }
        }
    }
    private var _sortDirection: String = "DESC"
    
    // MARK: - Dependencies
    
    private let repository: any SceneRepositoryProtocol
    private let settings: SettingsStore
    
    // MARK: - Initialization
    
    init(
        repository: any SceneRepositoryProtocol,
        settings: SettingsStore
    ) {
        self.repository = repository
        self.settings = settings
        
        // Load initial sort state
        if let type = SceneSortType(rawValue: settings.sceneSortType) {
            self._sortType = type
        }
        self._sortDirection = settings.sceneSortDirection
        
        setupNotificationObservers()
        logger.info("✨ Initializing SceneListViewModel")
    }
    
    deinit {
        let obs = observers
        if let o = obs.databaseObserver { NotificationCenter.default.removeObserver(o) }
        if let o = obs.sceneUpdateObserver { NotificationCenter.default.removeObserver(o) }
        obs.searchTask?.cancel()
        obs.filterSortTask?.cancel()
        obs.databaseChangedTask?.cancel()
        obs.sceneUpdateTask?.cancel()
    }
    
    // MARK: - Notification Setup
    
    //remove this.
    private func setupNotificationObservers() {
        // Observe database changes
        observers.databaseObserver = NotificationCenter.default.addObserver(
            forName: .stashDatabaseChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            logger.info("🔄 Database changed, reloading scenes...")
            self.observers.databaseChangedTask?.cancel()
            self.observers.databaseChangedTask = Task { @MainActor in
                await self.loadFromCache()
            }
        }
        
        // Observe individual scene updates
        observers.sceneUpdateObserver = NotificationCenter.default.addObserver(
            forName: .sceneUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let sceneId = notification.userInfo?["id"] as? String else { return }
            logger.info("📢 Scene \(sceneId) updated, updating in place")
            self.observers.sceneUpdateTask?.cancel()
            self.observers.sceneUpdateTask = Task { @MainActor in
                if let scene = self.listState.allItems.first(where: { $0.id == sceneId }),
                   let screenshotPath = scene.paths?.screenshot,
                   let url = self.settings.createImageUrl(path: screenshotPath) {
                    ImagePipeline.shared.cache.removeCachedImage(for: ImageRequest(url: url))
                    logger.debug("🗑️ Cleared image cache for scene \(sceneId)")
                }
                await self.updateSceneInPlace(sceneId: sceneId)
            }
        }
    }
    
    // MARK: - Search Debouncing
    
    private func scheduleSearch(query: String) {
        observers.searchTask?.cancel()
        observers.searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await applyFilterAndSort()
            }
        }
    }
    
    // MARK: - Data Loading
    
    func loadFromCache() async {
        logger.info("💾 Loading scenes from cache...")
        do {
            let loaded = try await repository.getCachedScenes()
            listState.cachedItems = loaded
            listState.hasLoadedFromCache = true
            await applyFilterAndSort()
            listState.isLoading = false
            logger.info("💾 Loaded \(loaded.count) scenes from cache")
        } catch {
            logger.error("❌ Failed to load scenes from cache: \(error.localizedDescription)")
            listState.errorMessage = "Failed to load list"
            listState.isLoading = false
        }
    }
    
    func fetchItems(reset: Bool = false) async {
        logger.info("🌍 Fetching scenes from API (reset: \(reset))...")
        
        listState.isFetching = true
        listState.errorMessage = nil
        if reset {
            listState.isRefreshing = true
            // Do NOT set state = .loading here, to keep content visible during refresh
        }
        
        defer { 
            listState.isFetching = false 
            if reset { listState.isRefreshing = false }
        }
        
        do {
            let fetched: [Scene]
            if reset {
                fetched = try await repository.syncNewScenes(progressHandler: nil, checkForDeletions: true)
            } else {
                fetched = try await repository.getAllScenes(progressHandler: nil)
            }
            
            listState.cachedItems = fetched
            await applyFilterAndSort()
            logger.info("✅ Fetched \(fetched.count) scenes")
        } catch {
            logger.error("❌ Failed to fetch scenes: \(error.localizedDescription)")
            if reset && listState.allItems.isEmpty {
                 // Only show error state if we have no content to show
                listState.errorMessage = error.localizedDescription
            }
            // If we have content, we just swallow the error for the UI (maybe show toast in future)
        }
    }
    
    func checkForUpdates() async {
        do {
            let changedScenes = try await repository.syncChangedScenes()
            guard !changedScenes.isEmpty else { return }
            
            logger.info("📥 Smart Sync: Found \(changedScenes.count) updated scenes, merging...")
            
            let allItems = listState.allItems
            let type = self.sortType
            let direction = self.sortDirection
            let currentRandomOrder = self.randomSortOrder
            
            let result = await Task.detached(priority: .userInitiated) {
                var uniqueScenesDict = Dictionary(grouping: allItems, by: { $0.id }).compactMapValues { $0.first }
                for scene in changedScenes {
                    uniqueScenesDict[scene.id] = scene
                }
                let mergedItems = Array(uniqueScenesDict.values)
                return Self.sortScenes(items: mergedItems, type: type, direction: direction, randomOrder: currentRandomOrder)
            }.value
            
            self.randomSortOrder = result.randomOrder
            listState.updateContent(result.sortedItems)
            logger.info("✅ Smart Sync: List updated with \(changedScenes.count) changes")
        } catch {
            logger.error("❌ Smart Sync Failed: \(error.localizedDescription)")
            if !listState.hasLoadedFromCache {
                await loadFromCache()
            }
        }
    }
    
    // MARK: - Pagination
    
    func loadMore(currentItem: Scene?) async {
        guard let currentItem = currentItem else { return }
        prefetchUpcomingImages(from: currentItem)
        guard let index = scenes.firstIndex(where: { $0.id == currentItem.id }),
              index >= scenes.count - 10,
              hasMore else { return }
        
        logger.debug("📜 Loading next page of scenes...")
        listState.appendPage()
        logger.debug("✅ Appended page. Current count: \(self.scenes.count)")
    }
    
    private func prefetchUpcomingImages(from scene: Scene) {
        guard let currentIndex = scenes.firstIndex(where: { $0.id == scene.id }) else { return }
        let upcoming = Array(scenes.dropFirst(currentIndex + 1).prefix(10))
        if !upcoming.isEmpty {
            logger.debug("🖼️ Prefetching images for \(upcoming.count) scenes")
            Task { await repository.prefetchImages(for: upcoming, count: 10) }
        }
    }
    
    // MARK: - Filtering & Sorting
    
    private func applyFilterAndSort() async {
        let query = listState.searchText
        let items = listState.cachedItems
        let type = self.sortType
        let direction = self.sortDirection
        let currentRandomOrder = self.randomSortOrder
        
        let result = await Task.detached(priority: .userInitiated) {
            let filtered = Self.filterScenes(items: items, query: query)
            return Self.sortScenes(items: filtered, type: type, direction: direction, randomOrder: currentRandomOrder)
        }.value
        
        self.randomSortOrder = result.randomOrder
        listState.updateContent(result.sortedItems)
        logger.debug("✅ Filter/Sort complete. Count: \(result.sortedItems.count)")
    }
    
    private func updateSceneInPlace(sceneId: String) async {
        do {
            // Efficient single-scene lookup instead of loading all scenes
            guard let updatedScene = try await repository.getCachedSceneById(sceneId) else {
                logger.warning("⚠️ Could not find scene \(sceneId) in cache")
                return
            }
            listState.updateItemInPlace(updatedScene)
            logger.info("✅ Updated scene \(sceneId) in scene list")
        } catch {
            logger.error("❌ Failed to update scene in list: \(error.localizedDescription)")
        }
    }
    
    func setScenes(_ items: [Scene]) {
        listState.updateContent(items)
    }
    
    func updateLoading(_ isLoading: Bool) {
        listState.isLoading = isLoading
    }
    
    func updateError(_ message: String?) {
        listState.errorMessage = message
        listState.isLoading = false
    }
    
    // MARK: - Static Logic
    
    nonisolated static func filterScenes(items: [Scene], query: String) -> [Scene] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        return items.filter { scene in
            scene.title?.localizedCaseInsensitiveContains(q) == true
            || scene.details?.localizedCaseInsensitiveContains(q) == true
            || scene.studio?.name.localizedCaseInsensitiveContains(q) == true
            || scene.performers?.contains { $0.name?.localizedCaseInsensitiveContains(q) == true } == true
            || scene.tags?.contains { $0.name.localizedCaseInsensitiveContains(q) } == true
        }
    }
    
    nonisolated static func sortScenes(items: [Scene], type: SceneSortType, direction: String, randomOrder: [Scene]?) -> (sortedItems: [Scene], randomOrder: [Scene]?) {
        if type == .random {
            if let cached = randomOrder, cached.count == items.count {
                return (cached, cached)
            } else {
                let shuffled = items.shuffled()
                return (shuffled, shuffled)
            }
        }
        
        let isAsc = direction == "ASC"
        let sorted = items.sorted { a, b in
            let comparison: Bool
            switch type {
            case .createdAt: comparison = (a.created_at ?? "") < (b.created_at ?? "")
            case .date: comparison = (a.date ?? "") < (b.date ?? "")
            case .rating: comparison = (a.rating100 ?? 0) < (b.rating100 ?? 0)
            case .oCounter: comparison = (a.o_counter ?? 0) < (b.o_counter ?? 0)
            case .updatedAt: comparison = (a.updated_at ?? "") < (b.updated_at ?? "")
            case .random: return true
            }
            return isAsc ? comparison : !comparison
        }
        return (sorted, nil)
    }
}

/// Thread-safe container for observers to allow safe cleanup in nonisolated deinit.
private final class ObserversContainer: @unchecked Sendable {
    var databaseObserver: NSObjectProtocol?
    var sceneUpdateObserver: NSObjectProtocol?
    var searchTask: Task<Void, Never>?
    var filterSortTask: Task<Void, Never>?
    var databaseChangedTask: Task<Void, Never>?
    var sceneUpdateTask: Task<Void, Never>?
    
    nonisolated init() {}
}
