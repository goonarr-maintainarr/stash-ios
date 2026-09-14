import Observation
import Foundation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditScenePerformerManager")

/// Manages performer search and selection for scene editing.
@MainActor
@Observable
class EditScenePerformerManager {
    
    // MARK: - Observable Properties
    
    var currentPerformers: [Performer]
    var searchResults: [Performer] = []
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
    
    private let performerRepository: any PerformerRepositoryProtocol
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        initialPerformers: [Performer],
        performerRepository: any PerformerRepositoryProtocol
    ) {
        self.currentPerformers = initialPerformers
        self.performerRepository = performerRepository
        
        logger.debug("🔧 EditScenePerformerManager initialized with \(initialPerformers.count) performers")
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
    
    /// Adds a performer to the scene's list if not already present.
    func addPerformer(_ performer: Performer) {
        if !currentPerformers.contains(where: { $0.id == performer.id }) {
            currentPerformers.append(performer)
            logger.info("➕ Added performer: \(performer.name ?? "Unknown", privacy: .public)")
        } else {
            logger.debug("⏭️ Performer already added: \(performer.name ?? "Unknown", privacy: .public)")
        }
        
        // Clear search after adding
        searchText = ""
        searchResults = []
    }
    
    /// Removes a performer from the scene's list.
    func removePerformer(id: String) {
        if let index = currentPerformers.firstIndex(where: { $0.id == id }) {
            let name = currentPerformers[index].name ?? "Unknown"
            currentPerformers.remove(at: index)
            logger.info("➖ Removed performer: \(name, privacy: .public)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Searches for performers matching the query string.
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        searchTask = Task {
            isSearching = true
            logger.debug("🔍 Searching performers: \(query)")
            
            do {
                let result = try await performerRepository.getPerformers(
                    searchText: query,
                    page: 1,
                    perPage: 20
                )
                
                if !Task.isCancelled {
                    self.searchResults = result.performers
                    self.isSearching = false
                    logger.info("✅ Found \(result.performers.count) performers")
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("❌ Performer search failed: \(error.localizedDescription)")
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
}
