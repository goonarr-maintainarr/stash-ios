import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrPaginationManager")

/// Manages pagination of Whisparr scenes for list display.
@MainActor
@Observable
class WhisparrPaginationManager {
    
    // MARK: - State
    
    /// The currently displayed list of scenes (paginated).
    var scenes: [WhisparrScene] = []
    
    /// Indicates if there are more items to load.
    var hasMore = true
    
    // MARK: - Configuration
    
    private let pageSize = 20
    private let loadMoreThreshold = 5
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 WhisparrPaginationManager initialized")
    }
    
    // MARK: - Pagination
    
    /// Loads the first page from filtered scenes.
    ///
    /// - Parameter filteredScenes: The complete filtered and sorted scene list.
    func loadFirstPage(from filteredScenes: [WhisparrScene]) {
        logger.info("📄 Loading first page from \(filteredScenes.count) filtered scenes")
        
        scenes = Array(filteredScenes.prefix(pageSize))
        hasMore = filteredScenes.count > pageSize
        
        let totalPages = Int(ceil(Double(filteredScenes.count) / Double(pageSize)))
        logger.info("✅ Displaying page 1 of \(totalPages): \(self.scenes.count) scenes")
    }
    
    /// Loads the next page when the user scrolls near the end.
    ///
    /// - Parameters:
    ///   - currentItem: The item currently appearing on screen.
    ///   - filteredScenes: The complete filtered and sorted scene list.
    /// - Returns: True if a new page was loaded, false otherwise.
    func loadMore(currentItem: WhisparrScene, from filteredScenes: [WhisparrScene]) -> Bool {
        guard hasMore else {
            logger.debug("⏹️ No more pages to load")
            return false
        }
        
        guard let currentIndex = scenes.firstIndex(where: { $0.id == currentItem.id }) else {
            logger.debug("⚠️ Current item not found in scenes list")
            return false
        }
        
        // Load next page when near the end (within threshold)
        let threshold = scenes.count - loadMoreThreshold
        guard currentIndex >= threshold else {
            return false
        }
        
        let currentCount = scenes.count
        let nextPageEndIndex = min(currentCount + pageSize, filteredScenes.count)
        let nextPage = Array(filteredScenes[currentCount..<nextPageEndIndex])
        
        guard !nextPage.isEmpty else {
            logger.info("✅ Reached end of list")
            hasMore = false
            return false
        }
        
        scenes.append(contentsOf: nextPage)
        hasMore = scenes.count < filteredScenes.count
        
        let currentPage = Int(ceil(Double(scenes.count) / Double(pageSize)))
        let totalPages = Int(ceil(Double(filteredScenes.count) / Double(pageSize)))
        logger.info("📺 Loaded page \(currentPage) of \(totalPages): displaying \(self.scenes.count) scenes")
        
        return true
    }
    
    /// Resets pagination state.
    func reset() {
        logger.debug("🔄 Resetting pagination")
        scenes = []
        hasMore = true
    }
    
    /// Returns the total count being paginated.
    var totalCount: Int {
        return scenes.count
    }
}
