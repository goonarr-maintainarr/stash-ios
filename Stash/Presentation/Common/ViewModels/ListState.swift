import Foundation

/// A generic state container for paginated list views.
/// Encapsulates the logic for managing a full dataset, a filtered/displayed subset, and pagination.
struct ListState<Item: Identifiable & Sendable>: Sendable {
    
    // MARK: - Data Source
    
    /// The raw dataset (loaded from repo, before filtering/sorting).
    var cachedItems: [Item] = []
    
    /// The processed dataset (after filtering/sorting, before pagination).
    var allItems: [Item] = []
    
    /// The currently visible subset of items (pagination applied to allItems).
    var displayedItems: [Item] = []
    
    // MARK: - View State
    
    /// Current search/filter text.
    var searchText: String = ""
    
    /// Whether the list is currently simple loading (e.g. init).
    var isLoading: Bool = true
    
    /// Whether a network fetch is in progress.
    var isFetching: Bool = false
    
    /// Whether a pull-to-refresh is in progress.
    var isRefreshing: Bool = false
    
    /// Tracks if we have successfully loaded from cache at least once.
    var hasLoadedFromCache: Bool = false
    
    /// Optional error message to display.
    var errorMessage: String? = nil
    
    // MARK: - Pagination State
    
    /// Number of items to display per page.
    var pageSize: Int = 40
    
    /// Current page number (1-based).
    var currentPage: Int = 1
    
    /// Whether there are more items to display from the `allItems` source.
    var hasMore: Bool = true
    
    // MARK: - Mutations
    
    /// Updates the `allItems` and recalculates the `displayedItems` (first page).
    /// Used when filtering or sorting changes the underlying list.
    mutating func updateContent(_ newItems: [Item]) {
        self.allItems = newItems
        self.currentPage = 1
        self.hasMore = true
        self.recalculateDisplayedItems()
    }
    
    /// Resets the state with a new full dataset.
    /// Resets pagination to page 1 and recalculates displayed items.
    mutating func reset(newItems: [Item]) {
        self.updateContent(newItems)
    }
    
    /// Appends the next page of items to `displayedItems`.
    mutating func appendPage() {
        guard hasMore else { return }
        
        let start = (currentPage - 1) * pageSize
        // Safely calculate end index
        let end = min(start + pageSize, allItems.count)
        
        // Check if we've reached the end of the data
        if end >= allItems.count {
            hasMore = false
        }
        
        if start < end {
            // Check bounds again to be absolutely safe (though start < end implies start < count)
            if start < allItems.count {
               let chunk = allItems[start..<end]
               // If it's the first page (or reset), we might overwrite, but appendPage is usually additive.
               // However, our logic here is simpler: displayedItems tracks the *cumulative* view.
               // But wait, if we use a simple slice approach, we need to append.
               
               // Ideally, displayedItems should just be the prefix `0..<end` of allItems (if filtered).
               // But usually `allItems` IS the filtered list in memory.
               
               // Let's assume allItems IS the working set (filtered).
               if displayedItems.count < end {
                   displayedItems = Array(allItems[0..<end])
               }
               
               currentPage += 1
            }
        }
    }
    
    /// Updates a specific item in place in both `allItems` and `displayedItems`.
    /// Useful for updating "favorite" status or ratings without reloading the whole list.
    mutating func updateItemInPlace(_ item: Item) {
        // Update in source of truth
        if let index = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[index] = item
        }
        
        // Update in displayed view
        if let index = displayedItems.firstIndex(where: { $0.id == item.id }) {
            displayedItems[index] = item
        }
    }
    
    // MARK: - Private Helpers
    
    private mutating func recalculateDisplayedItems() {
        // If no items, clear display
        if allItems.isEmpty {
            displayedItems = []
            hasMore = false
            return
        }
        
        // Initial load: take first page
        let end = min(pageSize, allItems.count)
        displayedItems = Array(allItems[0..<end])
        
        // Setup next page index
        currentPage = 2 
        hasMore = allItems.count > pageSize
    }
}
