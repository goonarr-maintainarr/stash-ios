import Foundation
import Combine

/// Protocol for Tag repository operations
protocol TagRepositoryProtocol: Repository where Entity == Tag {
    /// Fetch tags with pagination and filtering
    func getTags(
        searchText: String,
        page: Int,
        perPage: Int,
        forceRefresh: Bool
    ) async throws -> TagRepositoryResult
    
    /// Fetch a single tag by ID
    func getTag(id: String) async throws -> Tag?
    
    /// Fetch all tags from API
    func getAllTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag]
    
    /// Fetch only new/updated tags incrementally
    func syncNewTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag]
    
    /// Full sync: fetch all tags and remove deleted ones
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (tags: [Tag], removedCount: Int)
    
    /// Get tags from cache
    func getCachedTags() async throws -> [Tag]
    
    /// Get tag count from cache
    func getCachedTagCount() async throws -> Int
    
    /// Check if cache should be refreshed
    func shouldRefreshCache() async throws -> Bool
    
    /// Get last sync date
    func getLastSyncDate() async throws -> Date?
}

/// Result of a tag fetch operation
struct TagRepositoryResult {
    let tags: [Tag]
    let totalCount: Int
    let hasMore: Bool
    let source: DataSource
}
