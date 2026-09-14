import Foundation
import Combine
import SwiftUI
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "HomeViewModel")

@MainActor
@Observable
final class HomeViewModel: DatabaseObservable {
    
    // MARK: - State
    
    /// The current state of the view.
    var state: SyncViewState = .idle
    var categories: [SceneCategory] = []
    var showTagSelection = false
    
    // MARK: - Managers
    
    let categoryBuilder: HomeCategoryBuilder
    let stashDBManager: HomeStashDBManager
    let syncManager: HomeSyncManager
    let sceneProcessor: HomeSceneProcessor
    let jobManager: HomeJobManager
    
    // MARK: - Dependencies
    
    private let settings: SettingsStore
    private let sceneRepository: any SceneRepositoryProtocol
    
    // MARK: - State Management
    
    var cancellables = Set<AnyCancellable>() // Internal for DatabaseObservable protocol
    
    // MARK: - Initialization
    
    init(
        settings: SettingsStore,
        sceneRepository: any SceneRepositoryProtocol,
        performerRepository: any PerformerRepositoryProtocol,
        tagRepository: any TagRepositoryProtocol,
        syncService: (any SyncServiceProtocol)? = nil,
        stashDBRepository: StashDBRepositoryProtocol
    ) {
        self.settings = settings
        self.sceneRepository = sceneRepository
        
        // Initialize managers
        self.categoryBuilder = HomeCategoryBuilder(tagRepository: tagRepository, settings: settings)
        self.stashDBManager = HomeStashDBManager(stashDBRepository: stashDBRepository, settings: settings)
        self.sceneProcessor = HomeSceneProcessor(sceneRepository: sceneRepository, settings: settings)
        self.jobManager = HomeJobManager()
        
        // Use injected service or create new one
        let service = syncService ?? SyncService(
            sceneRepository: sceneRepository,
            performerRepository: performerRepository,
            tagRepository: tagRepository
        )
        self.syncManager = HomeSyncManager(syncService: service, sceneRepository: sceneRepository)
        
        logger.info("🏗️ HomeViewModel initialized")
        
        setupDatabaseObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(onFollowedTagsChanged(_:)), name: .followedTagsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onCategoryOrderChanged(_:)), name: .categoryOrderChanged, object: nil)
        setupManagers()
    }
    
    deinit {
        let obs = observers
        obs.loadCategoriesTask?.cancel()
        obs.sceneUpdateTask?.cancel()
        obs.stashDBFavoritesTask?.cancel()
    }
    
    // MARK: - Setup
    
    
    private func setupManagers() {
        logger.debug("🔧 Setting up manager callbacks")
        
        // Setup job manager callback
        jobManager.setupRefreshCallback { [weak self] in
            await self?.triggerRefresh()
        }
        
        logger.info("✅ Manager callbacks set up successfully")
    }
    
    // MARK: - DatabaseObservable
    
    func onDatabaseChanged() {
        logger.info("📢 Database changed, reloading categories")
        // Cancel any pending load and start fresh
        observers.loadCategoriesTask?.cancel()
        observers.loadCategoriesTask = Task { await loadCategories() }
    }
    
    func onSceneUpdated(_ notification: Notification) {
        guard let sceneId = notification.userInfo?["id"] as? String else { return }
        logger.info("📢 Scene \(sceneId) updated, updating in place")
        // Cancel any pending scene update and start fresh
        observers.sceneUpdateTask?.cancel()
        observers.sceneUpdateTask = Task { await updateSceneInCategories(sceneId: sceneId) }
    }
    
    func onPerformerUpdated(_ notification: Notification) {
        let performerId = notification.userInfo?["id"] as? String ?? "unknown"
        logger.info("📢 Performer \(performerId) updated notification received")
        // Don't auto-refresh - performer updates are less critical
        // User can manually refresh if needed
    }
    
    @objc func onFollowedTagsChanged(_ notification: Notification) {
        logger.info("📢 Followed tags changed, reloading categories")
        Task { await loadCategories() }
    }
    
    @objc func onCategoryOrderChanged(_ notification: Notification) {
        logger.info("📢 Category order changed, reordering categories")
        // Reapply order without full reload
        Task { @MainActor in
            self.categories = applyCategoryOrder(to: self.categories)
        }
    }
    
    // MARK: - Data Loading
    
    /// Prefetch all data (scenes and performers) on app launch.
    func prefetchAppData(forceRefresh: Bool = false) async {
        await syncManager.prefetchAppData(forceRefresh: forceRefresh)
    }
    
    /// Trigger a manual refresh
    func refresh() async {
        await triggerRefresh()
    }
    
    /// Lightweight sync of scenes that changed since last sync.
    func syncChangedScenes() async {
        await syncManager.syncChangedScenes()
    }
    
    /// Full sync: fetches all data and removes deleted items.
    func fullSync() async {
        await syncManager.fullSync()
        await loadCategories()
    }
    
    private func triggerRefresh() async {
        await syncChangedScenes()
        await loadCategories()
    }
    
    // MARK: - Observer Storage
    
    /// Thread-safe container for observers to allow safe cleanup in nonisolated deinit.
    private final class ObserversContainer: @unchecked Sendable {
        var loadCategoriesTask: Task<Void, Never>?
        var sceneUpdateTask: Task<Void, Never>?
        var stashDBFavoritesTask: Task<Void, Never>?
    }
    
    private let observers = ObserversContainer()
    
    /// Updates a specific scene across all categories without rebuilding everything.
    /// This is a surgical update that doesn't disrupt navigation.
    private func updateSceneInCategories(sceneId: String) async {
        do {
            // Fetch the updated scene from cache (efficient single-scene lookup)
            guard let updatedScene = try await sceneRepository.getCachedSceneById(sceneId) else {
                logger.warning("⚠️ Could not find scene \(sceneId) in cache")
                return
            }
            
            // Update the scene in all categories that contain it
            await MainActor.run {
                var updatedCategories = self.categories
                var didUpdate = false
                
                for i in 0..<updatedCategories.count {
                    if let sceneIndex = updatedCategories[i].scenes.firstIndex(where: { $0.id == sceneId }) {
                        updatedCategories[i].scenes[sceneIndex] = updatedScene
                        didUpdate = true
                    }
                }
                
                if didUpdate {
                    self.categories = updatedCategories
                    logger.info("✅ Updated scene \(sceneId) in categories")
                } else {
                    logger.debug("⏭️ Scene \(sceneId) not found in any category")
                }
            }
        } catch {
            logger.error("❌ Failed to update scene in categories: \(error.localizedDescription)")
        }
    }
    
    func loadCategories() async {
        // Cancel any existing task to prefer the latest request
        observers.loadCategoriesTask?.cancel()
        
        observers.loadCategoriesTask = Task {
            logger.info("📂 loadCategories started")
            
            // Check for cancellation early
            if Task.isCancelled { return }
            
            guard settings.url != nil else {
                await MainActor.run { state = .error("Invalid Server URL") }
                return
            }
            
            // Only show loading state if we don't have categories yet
            // This prevents UI flashing during refresh
            if self.categories.isEmpty {
                await MainActor.run {
                    state = .loading
                }
            }
            
            do {
                // Check if we have any cached scenes (lightweight count check)
                let sceneCount = try await sceneRepository.getCachedSceneCount()
                
                if Task.isCancelled { return }
                
                if sceneCount == 0 {
                    logger.warning("⚠️ No cached scenes available for categories")
                    await MainActor.run {
                        self.state = .loaded
                    }
                    return
                }
                
                logger.info("📂 Building categories with \(sceneCount) cached scenes...")
                
                // Build category structure (async - filters based on settings)
                var categories = await categoryBuilder.buildSortBasedCategories()
                
                // Add StashDB favorites category if enabled
                if settings.showStashDBFavorites {
                    if let cachedCategory = await stashDBManager.loadCachedFavoritesCategory() {
                        categories.append(cachedCategory)
                    } else if let placeholder = await categoryBuilder.buildStashDBPlaceholderCategory() {
                        categories.append(placeholder)
                    }
                }
                
                // Build tag categories
                let tagCategories = try await categoryBuilder.buildTagCategories()
                
                if Task.isCancelled { return }
                
                categories.append(contentsOf: tagCategories)
                
                logger.info("📂 Loading scenes for \(categories.count) categories...")
                
                // Populate each category with efficient targeted queries (10 scenes each)
                let repo = sceneRepository
                var populatedCategories: [SceneCategory] = []
                
                for var category in categories {
                    if Task.isCancelled { return }
                    
                    if category.type == .localScenes {
                        // Use efficient targeted database queries per category
                        let scenes: [Scene]
                        
                        if let tagIds = category.tagIds, !tagIds.isEmpty {
                            // Tag-based category: query by tags with limit
                            let sortColumn = sortColumnForType(category.sortType)
                            scenes = try await repo.getCachedScenesByTagIds(
                                tagIds,
                                limit: 10,
                                sortBy: sortColumn,
                                ascending: false
                            )
                        } else {
                            // Sort-based category: use efficient sorted query
                            switch category.sortType {
                            case .random:
                                scenes = try await repo.getCachedRandomScenes(limit: 10)
                            case .createdAt:
                                scenes = try await repo.getCachedScenesSorted(by: "created_at", ascending: false, limit: 10)
                            case .date:
                                scenes = try await repo.getCachedScenesSorted(by: "date", ascending: false, limit: 10)
                            case .rating:
                                scenes = try await repo.getCachedScenesSorted(by: "rating100", ascending: false, limit: 10)
                            case .oCounter:
                                scenes = try await repo.getCachedScenesSorted(by: "o_counter", ascending: false, limit: 10)
                            case .updatedAt:
                                scenes = try await repo.getCachedScenesSorted(by: "updated_at", ascending: false, limit: 10)
                            }
                        }
                        
                        category.scenes = scenes
                    }
                    
                    populatedCategories.append(category)
                }

                if Task.isCancelled { return }
                
                // Apply user's saved category order
                let orderedCategories = applyCategoryOrder(to: populatedCategories)
                
                await MainActor.run {
                    self.categories = orderedCategories
                    self.state = .loaded
                }
                
                logger.info("✅ Home categories loaded")
                
                // Check for StashDB favorites update in background
                observers.stashDBFavoritesTask?.cancel()
                observers.stashDBFavoritesTask = Task {
                    if let updatedCategory = await stashDBManager.buildStashDBFavoritesCategory() {
                        await MainActor.run {
                            stashDBManager.updateFavoritesCategory(updatedCategory, in: &self.categories)
                            stashDBManager.removePlaceholderIfNeeded(from: &self.categories)
                        }
                    }
                }
                
            } catch is CancellationError {
                logger.info("🚫 loadCategories cancelled - this is expected during rapid updates")
            } catch {
                if Task.isCancelled {
                   logger.info("🚫 loadCategories cancelled during error handling")
                   return
                }
                logger.error("❌ Failed to load categories: \(error.localizedDescription)")
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
        
        // Await the task completion
        _ = await observers.loadCategoriesTask?.result
    }
    
    // MARK: - Background Operations
    
    private func loadStashDBFavoritesInBackground() async {
        logger.info("🔄 Loading StashDB favorites in background...")
        
        guard let favoritesCategory = await stashDBManager.buildStashDBFavoritesCategory() else {
            logger.info("⏭️ No StashDB favorites category to add - removing placeholder")
            // Remove the placeholder if no favorites found
            await MainActor.run {
                var updatedCategories = self.categories
                stashDBManager.removePlaceholderIfNeeded(from: &updatedCategories)
                self.categories = updatedCategories
            }
            return
        }
        
        // Update the existing placeholder category with the actual data
        await MainActor.run {
            var updatedCategories = self.categories
            stashDBManager.updateFavoritesCategory(favoritesCategory, in: &updatedCategories)
            self.categories = updatedCategories
        }
    }
    
    // MARK: - Helpers
    
    /// Maps SceneSortType to database column name for efficient SQL queries.
    private func sortColumnForType(_ sortType: SceneSortType) -> String {
        switch sortType {
        case .random: return "RANDOM()"
        case .createdAt: return "created_at"
        case .date: return "date"
        case .rating: return "rating100"
        case .oCounter: return "o_counter"
        case .updatedAt: return "updated_at"
        }
    }
    
    /// Applies user's saved category order to the given categories.
    /// Categories in the saved order appear first, then any new categories.
    private func applyCategoryOrder(to categories: [SceneCategory]) -> [SceneCategory] {
        let savedOrder = settings.categoryOrder
        
        // If no saved order, return as-is
        guard !savedOrder.isEmpty else { return categories }
        
        var orderedCategories: [SceneCategory] = []
        
        // Add categories in saved order
        for id in savedOrder {
            if let category = categories.first(where: { $0.id == id }) {
                orderedCategories.append(category)
            }
        }
        
        // Add any new categories not in saved order
        for category in categories {
            if !savedOrder.contains(category.id) {
                orderedCategories.append(category)
            }
        }
        
        return orderedCategories
    }
}
