import Foundation
import Observation
import os

/// A ViewModel responsible for managing tag selection, filtering, and deletion.
///
/// `TagSelectionViewModel` handles fetching tags from the local database, filtering them based on user input,
/// managing the user's "followed" tags which are persisted in the settings, and deleting tags from the server.
@MainActor
@Observable
final class TagSelectionViewModel {
    
    // MARK: - State
    
    private(set) var listState = TagSelectionState()
    
    // MARK: - Convenience Accessors
    
    var tags: [Tag] { listState.items }
    var items: [Tag] { listState.items }
    var selectedTags: [Tag] {
        get { listState.selectedTags }
    }
    
    var state: ListViewState<Tag> { listState.state }
    var alertMessage: String? {
        get { listState.alertMessage }
        set { listState.alertMessage = newValue }
    }
    
    var totalTagCount: Int { listState.totalCount }
    
    var searchText: String {
        get { listState.searchText }
        set {
            if listState.searchText != newValue {
                listState.searchText = newValue
                scheduleSearch(query: newValue)
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let settings: SettingsStoreProtocol
    private let database: StashDatabase
    private let tagRepository: TagRepository?
    
    private let logger = Logger(subsystem: "com.stash.app", category: "TagSelectionViewModel")
    
    // MARK: - Initialization
    
    /// Initializes the `TagSelectionViewModel`.
    init(
        settings: SettingsStoreProtocol,
        database: StashDatabase,
        tagRepository: TagRepository? = nil
    ) {
        self.settings = settings
        self.database = database
        self.tagRepository = tagRepository
        
        
        logger.info("🏭️ TagSelectionViewModel initialized")
        setupDatabaseObserver()
    }
    
    // MARK: - Observer Storage
    
    /// Thread-safe container for observers to allow safe cleanup in nonisolated deinit.
    private final class ObserversContainer: @unchecked Sendable {
        var searchTask: Task<Void, Never>?
        var filterTask: Task<Void, Never>?
        var databaseChangedTask: Task<Void, Never>?
    }
    
    private let observers = ObserversContainer()
    
    private func scheduleSearch(query: String) {
        observers.searchTask?.cancel()
        observers.searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            if !Task.isCancelled {
                await performClientSideSearch(query: query)
            }
        }
    }
    
    // MARK: - Data Loading
    
    func fetchItems(reset: Bool = false) async {
        // TagSelectionViewModel typically loads from local DB only
        await loadFromCache()
    }
    
    private func loadFromCache() async {
        do {
            let all = try await database.fetchAllTags()
            
            // Sync selected tags
            let followedIds = settings.followedTagIds
            let selected = all.filter { followedIds.contains($0.id) }
            
            await MainActor.run {
                listState.cachedItems = all
                listState.allItems = all
                listState.updateSelectedTags(selected)
                
                // Initial filter (if any search text exists, though usually empty on start)
                self.observers.filterTask?.cancel()
                self.observers.filterTask = Task { await performClientSideSearch(query: listState.searchText) }
            }
        } catch {
             logger.error("❌ Failed to load tags: \(error.localizedDescription)")
             await MainActor.run {
                 listState.state = .error("Failed to load tags: \(error.localizedDescription)")
             }
        }
    }
    
    private func performClientSideSearch(query: String) async {
        let trimmedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        let dataset = listState.allItems
        
        let filtered = await Task.detached(priority: .userInitiated) {
            if trimmedQuery.isEmpty {
                // Return all sorted by name
                return dataset.sorted { $0.name.lowercased() < $1.name.lowercased() }
            } else {
                return dataset
                    .filter { $0.name.lowercased().contains(trimmedQuery) }
                    .sorted { $0.name.lowercased() < $1.name.lowercased() }
            }
        }.value
        
        await MainActor.run {
            listState.updateContent(filtered)
        }
    }
    
    // MARK: - Specific Methods
    
    /// Checks if a tag is currently followed by the user.
    func isFollowing(tagId: String) -> Bool {
        return settings.followedTagIds.contains(tagId)
    }
    
    /// Toggles the followed state of a tag.
    func toggleFollow(tag: Tag) {
        if isFollowing(tagId: tag.id) {
            settings.removeFollowedTag(id: tag.id)
            // Update local state
            if let index = listState.selectedTags.firstIndex(where: { $0.id == tag.id }) {
                var newSelected = listState.selectedTags
                newSelected.remove(at: index)
                listState.updateSelectedTags(newSelected)
            }
        } else {
            settings.addFollowedTag(id: tag.id)
            var newSelected = listState.selectedTags
            newSelected.append(tag)
            listState.updateSelectedTags(newSelected)
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a single tag from the server and local cache.
    func deleteTag(_ tag: Tag) async {
        guard let repo = tagRepository else {
            alertMessage = "Delete not available"
            return
        }
        
        // Optimistic UI update or loading state could go here, but deletion is fast.
        
        do {
            try await repo.deleteTag(id: tag.id)
            
            HapticManager.mediumImpact()
            logger.info("✅ Deleted tag: \(tag.name)")
            
            await MainActor.run {
                listState.removeTag(tag.id)
            }
            
        } catch {
            alertMessage = "Failed to delete tag: \(error.localizedDescription)"
            logger.error("❌ Failed to delete tag: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Handling
    
    private func setupDatabaseObserver() {
        NotificationCenter.default.addObserver(
            forName: .stashDatabaseChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            logger.info("🔄 Database changed, reloading tags...")
            self.observers.databaseChangedTask?.cancel()
            self.observers.databaseChangedTask = Task { @MainActor in
                await self.loadFromCache()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        let obs = observers
        obs.searchTask?.cancel()
        obs.filterTask?.cancel()
        obs.databaseChangedTask?.cancel()
    }
}

