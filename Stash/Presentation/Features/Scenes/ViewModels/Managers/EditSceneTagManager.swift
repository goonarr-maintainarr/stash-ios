import Observation
import Foundation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditSceneTagManager")

/// Manages tag search and selection for scene editing.
@MainActor
@Observable
class EditSceneTagManager {
    
    // MARK: - Observable Properties
    
    var currentTags: [Tag]
    var searchResults: [Tag] = []
    var isSearching = false
    
    private var _searchText = ""
    var searchText: String {
        get { _searchText }
        set {
            _searchText = newValue
            performDebouncedSearch(query: newValue)
        }
    }
    
    // MARK: - Dependencies
    
    private let tagRepository: any TagRepositoryProtocol
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        initialTags: [Tag],
        tagRepository: any TagRepositoryProtocol
    ) {
        self.currentTags = initialTags
        self.tagRepository = tagRepository
        
        logger.debug("🔧 EditSceneTagManager initialized with \(initialTags.count) tags")
    }
    
    private func performDebouncedSearch(query: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                performSearch(query: query)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Adds a tag to the scene's list if not already present.
    func addTag(_ tag: Tag) {
        if !currentTags.contains(where: { $0.id == tag.id }) {
            currentTags.append(tag)
            logger.info("🏷️ Added tag: \(tag.name, privacy: .public)")
        } else {
            logger.debug("⏭️ Tag already added: \(tag.name, privacy: .public)")
        }
        
        // Clear search after adding
        searchText = ""
        searchResults = []
    }
    
    /// Removes a tag from the scene's list.
    func removeTag(id: String) {
        if let index = currentTags.firstIndex(where: { $0.id == id }) {
            let name = currentTags[index].name
            currentTags.remove(at: index)
            logger.info("🗑️ Removed tag: \(name, privacy: .public)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Searches for tags matching the query string.
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        searchTask = Task {
            isSearching = true
            logger.debug("🔍 Searching tags: \(query)")
            
            do {
                let result = try await tagRepository.getTags(
                    searchText: query,
                    page: 1,
                    perPage: 20,
                    forceRefresh: false
                )
                
                if !Task.isCancelled {
                    self.searchResults = result.tags
                    self.isSearching = false
                    logger.info("✅ Found \(result.tags.count) tags")
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("❌ Tag search failed: \(error.localizedDescription)")
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
}
