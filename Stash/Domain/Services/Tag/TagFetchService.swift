import Foundation
import os

/// Service responsible for fetching tag data from the Stash API.
///
/// This service handles all read operations from the remote Stash server for tags.
class TagFetchService: @unchecked Sendable {
    private let apiClient: StashClientProtocol
    private let cacheService: TagCacheService
    private let settings: any SettingsStoreProtocol
    private let fetchGuard = FetchGuard()
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "TagFetchService")
    
    init(apiClient: StashClientProtocol, cacheService: TagCacheService, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.cacheService = cacheService
        self.settings = settings
    }
    
    

    
    // MARK: - Fetch Operations
    
    /// Fetches a paginated list of tags, optionally filtered by a search string.
    func getTags(
        searchText: String = "",
        page: Int = 1,
        perPage: Int = 100,
        forceRefresh: Bool = false
    ) async throws -> TagRepositoryResult {
        
        let url = try settings.validateStashConfiguration()
        
        // If not forcing refresh and searching, return from cache
        if !forceRefresh && !searchText.isEmpty {
            let cached = try await cacheService.getCachedTags()
            let filtered = cached.filter { tag in
                tag.name.localizedCaseInsensitiveContains(searchText)
            }
            
            
            return TagRepositoryResult(
                tags: Array(filtered.prefix(perPage)),
                totalCount: filtered.count,
                hasMore: filtered.count > perPage,
                source: .cache
            )
        }
        
        // Fetch from API
        Logger.repository.info("🌐 Fetching tags from API (page: \(page))")
        
        let query = StashQueries.findTags(
            searchText: searchText,
            page: page,
            perPage: perPage
        )
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        let result: TagResultDTO = try await apiClient.fetch(
            query: query,
            variables: nil,
            url: url,
            apiKey: settingsStore.apiKey
        )
        
        let tags = result.findTags.tags
        let totalCount = result.findTags.count
        
        Logger.repository.info("📦 Received \(tags.count) tags from API (total: \(totalCount))")
        
        // Cache first page of default view
        if page == 1 && searchText.isEmpty {
            try await cacheService.cacheTags(tags)
        }
        
        return TagRepositoryResult(
            tags: tags,
            totalCount: totalCount,
            hasMore: tags.count == perPage && (page * perPage) < totalCount,
            source: .api
        )
    }
    
    /// Fetches all tags from the API, handling pagination automatically.
    func getAllTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag] {
        
        let url = try settings.validateStashConfiguration()
        
        // Prevent concurrent fetches - return cached data if already fetching
        let started = await fetchGuard.beginIfPossible()
        if !started {
            Logger.repository.info("⏭️ Already fetching all tags, returning cached data")
            return try await cacheService.getCachedTags()
        }
        
        defer {
            Task { await fetchGuard.end() }
        }
        
        var allTags: [Tag] = []
        var page = 1
        let perPage = 500
        var hasMore = true
        var totalCount = 0
        
        Logger.repository.info("🌐 Fetching ALL tags from API...")
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        while hasMore {
            
            let query = StashQueries.findTags(
                searchText: "",
                page: page,
                perPage: perPage
            )
            
            let result: TagResult = try await apiClient.fetch(
                query: query,
                variables: nil,
                url: url,
                apiKey: settingsStore.apiKey
            )
            
            totalCount = result.findTags.count
            allTags.append(contentsOf: result.findTags.tags)
            hasMore = result.findTags.tags.count == perPage
            
            
            page += 1
            
            // Report progress
            if let handler = progressHandler {
                await handler(allTags.count, totalCount)
            }
        }
        
        Logger.repository.info("✅ Fetched \(allTags.count) tags total")
        
        // Cache all tags
        try await cacheService.cacheTags(allTags)
        
        return allTags
    }
    
    /// Retrieves a single tag by its ID from the local cache.
    func getTag(id: String) async throws -> Tag? {
        let _ = try settings.validateStashConfiguration()
        
        // For now, tags don't have a single fetch query in GraphQL
        // So we'll return from cache if available
        let cached = try await cacheService.getCachedTags()
        return cached.first { $0.id == id }
    }
}
