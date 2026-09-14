import Foundation
import Observation
import SwiftUI
import os

@MainActor
@Observable
class StudioListViewModel {
    
    // MARK: - State
    
    /// The container for all observable state.
    private(set) var listState = ListState<Studio>()
    
    // MARK: - Sort State
    private var _sortType: String = "name"
    private var _sortDirection: String = "ASC"
    
    // MARK: - Convenience Accessors
    
    var items: [Studio] { listState.displayedItems }
    var state: ListViewState<Studio> {
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
    
    var sortType: String {
        get { _sortType }
        set {
            if _sortType != newValue {
                _sortType = newValue
                observers.sortTask?.cancel()
                observers.sortTask = Task { await performSortUpdate() }
            }
        }
    }
    
    var sortDirection: String {
        get { _sortDirection }
        set {
            if _sortDirection != newValue {
                _sortDirection = newValue
                observers.sortTask?.cancel()
                observers.sortTask = Task { await performSortUpdate() }
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let repository: any StudioRepositoryProtocol
    private let logger = Logger(subsystem: "com.stash.app", category: "StudioListViewModel")
    
    // MARK: - Initialization
    
    init(repository: any StudioRepositoryProtocol) {
        self.repository = repository
        logger.info("🏭️ StudioListViewModel initialized")
    }
    
    deinit {
        let obs = observers
        obs.searchTask?.cancel()
        obs.sortTask?.cancel()
    }
    
    // MARK: - Observer Storage
    
    private nonisolated let observers = ObserversContainer()
    
    private func scheduleSearch(query: String) {
        observers.searchTask?.cancel()
        observers.searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if !Task.isCancelled {
                await performSortUpdate()
            }
        }
    }
    
    // MARK: - Data Loading
    
    func fetchItems(reset: Bool = false) async {
        if reset {
             listState.isRefreshing = true
        }
        listState.isFetching = true
        listState.errorMessage = nil
        defer { 
            listState.isFetching = false 
            if reset { listState.isRefreshing = false }
        }
        
        do {
            logger.info("Fetching all studios...")
            
            // Load all studios for client-side search/sort consistency with other lists
            let (studios, totalCount) = try await repository.getStudios(
                searchText: "",
                page: 1,
                perPage: 1000, // Fetch all for now
                sortBy: sortType,
                sortDirection: sortDirection,
                forceRefresh: reset
            )
            
            // Update cache in state
            listState.cachedItems = studios
            listState.hasLoadedFromCache = true
            listState.isLoading = false
            
            // Perform initial sort/filter
            await performSortUpdate()
            
            logger.info("✅ Fetched \(studios.count) studios")
            
        } catch {
            logger.error("❌ Failed to fetch studios: \(error.localizedDescription)")
            await MainActor.run {
                if reset && listState.allItems.isEmpty {
                     listState.errorMessage = error.localizedDescription
                }
                listState.isLoading = false
            }
        }
    }
    
    /// Sorts and filters the *cached* items and updates the view state.
    private func performSortUpdate() async {
        let query = listState.searchText
        let items = listState.cachedItems
        // let currentSortType = self.sortType // Not used yet
        let currentSortDirection = self.sortDirection
        
        let filteredAndSorted = await Task.detached(priority: .userInitiated) {
             // 1. Filter
            let filtered: [Studio]
            if query.isEmpty {
                filtered = items
            } else {
                filtered = items.filter { $0.name.lowercased().contains(query.lowercased()) }
            }
            
            // 2. Sort
            let ascending = currentSortDirection == "ASC"
            // For now, simple name sort is implemented. Ideally extend this based on sortType.
            return filtered.sorted(by: ascending ? { $0.name < $1.name } : { $0.name > $1.name })
        }.value
        
        await MainActor.run {
            listState.updateContent(filteredAndSorted)
        }
    }
    
    // MARK: - Pagination
    
    func loadMore(currentItem: Studio) async {
        // Check if we need to load more
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }),
              index >= items.count - 10, // Load when within 10 items of bottom
              hasMore else { return }
        
        listState.appendPage()
    }
}

/// Thread-safe container for observers to allow safe cleanup in nonisolated deinit.
private final class ObserversContainer: @unchecked Sendable {
    var searchTask: Task<Void, Never>?
    var sortTask: Task<Void, Never>?
    
    nonisolated init() {}
}
