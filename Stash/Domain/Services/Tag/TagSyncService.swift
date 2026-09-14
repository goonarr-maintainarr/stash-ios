import Foundation
import os

/// Service responsible for synchronizing tag data between the server and local database.
///
/// This service handles incremental and full synchronization of tags.
class TagSyncService: StashService, @unchecked Sendable {
    let apiClient: StashClientProtocol
    private let cacheService: TagCacheService
    private let fetchService: TagFetchService
    let settings: any SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "TagSyncService")
    
    init(apiClient: StashClientProtocol, cacheService: TagCacheService, fetchService: TagFetchService, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.cacheService = cacheService
        self.fetchService = fetchService
        self.settings = settings
    }
    
    
    // MARK: - Sync Operations
    
    /// Synchronizes only new tags that are present on the server but missing locally.
    func syncNewTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag] {
        
        let url = try settings.validateStashConfiguration()
        
        Logger.repository.info("🔄 Starting incremental sync for tags...")
        
        // Get existing tag IDs from cache
        let cachedTags = try await cacheService.getCachedTags()
        let cachedTagIds = Set(cachedTags.map { $0.id })
        let cachedCount = cachedTagIds.count
        
        Logger.repository.info("📦 Have \(cachedCount) tags in cache")
        
        // First, get the total count from server
        let countQuery = StashQueries.findTags(searchText: "", page: 1, perPage: 1)
        
        let countResult: TagResult = try await fetchWithErrorWrapping(
            query: countQuery,
            variables: nil,
            url: url
        )
        
        let serverCount = countResult.findTags.count
        Logger.repository.info("🌐 Server has \(serverCount) tags")
        
        // If counts match, we're in sync
        if serverCount == cachedCount {
            Logger.repository.info("✅ Tag counts match, no sync needed")
            return cachedTags
        }
        
        // Counts differ - fetch all tags and find the missing ones
        Logger.repository.info("⚠️ Count mismatch (server: \(serverCount), cache: \(cachedCount)) - fetching missing tags...")
        
        var newTags: [Tag] = []
        var currentPage = 1
        let perPage = 500
        var hasMore = true
        
        while hasMore {
            
            let query = StashQueries.findTags(
                searchText: "",
                page: currentPage,
                perPage: perPage
            )
            
            let result: TagResult = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )
            
            let tags = result.findTags.tags
            
            // Find tags not in our cache
            for tag in tags {
                if !cachedTagIds.contains(tag.id) {
                    newTags.append(tag)
                }
            }
            
            hasMore = tags.count == perPage
            currentPage += 1
            
            Logger.repository.info("📥 Page \(currentPage - 1): Checked \(tags.count) tags, found \(newTags.count) new so far")
            
            // Report progress
            if let handler = progressHandler {
                await handler(newTags.count, serverCount - cachedCount)
            }
        }
        
        if newTags.isEmpty {
            Logger.repository.info("✅ No new tags to sync (count mismatch may be due to deletions)")
        } else {
            Logger.repository.info("✅ Found \(newTags.count) new tags, caching...")
            try await cacheService.cacheTags(newTags)
        }
        
        // Return all cached tags (including newly added ones)
        return try await cacheService.getCachedTags()
    }
    
    /// Performs a full synchronization of tags, including removing deleted ones.
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (tags: [Tag], removedCount: Int) {
        Logger.repository.info("🔄 Starting full sync with deletion cleanup...")
        
        // Get current cache count before sync
        let cachedBefore = try await cacheService.getCachedTags()
        let cachedBeforeCount = cachedBefore.count
        
        
        // Fetch all tags from API
        let allTags = try await fetchService.getAllTags(progressHandler: progressHandler)
        
        
        // Remove deleted tags
        let tagIds = Set(allTags.map { $0.id })
        try await cacheService.removeDeletedTags(keeping: tagIds)
        
        // Calculate how many were removed
        let cachedAfter = try await cacheService.getCachedTags()
        let removedCount = max(0, cachedBeforeCount - cachedAfter.count + (allTags.count - cachedBeforeCount))
        
        Logger.repository.info("✅ Full sync complete: \(allTags.count) tags, \(removedCount) removed")
        
        return (allTags, removedCount)
    }
    
    /// Triggers a refresh of the tags by fetching the first page.
    func refresh() async throws {
        
        let result = try await fetchService.getTags(page: 1, perPage: 100, forceRefresh: true)
        try await cacheService.cacheTags(result.tags)
        
    }
}
