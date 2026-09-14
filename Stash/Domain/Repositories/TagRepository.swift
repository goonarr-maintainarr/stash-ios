import Foundation
import os

/// A repository responsible for managing `Tag` entities.
///
/// This repository acts as a coordinator, delegating operations to specialized service classes
/// for better separation of concerns and maintainability.
final class TagRepository: BaseRepository, TagRepositoryProtocol, @unchecked Sendable {
    typealias Entity = Tag
    
    // Service layer
    private let cacheService: TagCacheService
    private let fetchService: TagFetchService
    private let syncService: TagSyncService
    
    /// Initializes the `TagRepository`.
    ///
    /// - Parameters:
    ///   - apiClient: The client used for network requests.
    ///   - database: The local database for caching.
    ///   - settings: The store for user settings.
    override init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        imagePrefetchManager: ImagePrefetchService
    ) {
        // Initialize services
        self.cacheService = TagCacheService(database: database)
        self.fetchService = TagFetchService(apiClient: apiClient, cacheService: self.cacheService, settings: settings)
        self.syncService = TagSyncService(apiClient: apiClient, cacheService: self.cacheService, fetchService: self.fetchService, settings: settings)
        
        super.init(apiClient: apiClient, database: database, settings: settings, imagePrefetchManager: imagePrefetchManager)
    }
    
    // MARK: - Fetch Operations
    
    func getTags(
        searchText: String = "",
        page: Int = 1,
        perPage: Int = 100,
        forceRefresh: Bool = false
    ) async throws -> TagRepositoryResult {
        return try await fetchService.getTags(searchText: searchText, page: page, perPage: perPage, forceRefresh: forceRefresh)
    }
    
    func getAllTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag] {
        return try await fetchService.getAllTags(progressHandler: progressHandler)
    }
    
    func getTag(id: String) async throws -> Tag? {
        return try await fetchService.getTag(id: id)
    }
    
    // MARK: - Sync Operations
    
    func syncNewTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag] {
        return try await syncService.syncNewTags(progressHandler: progressHandler)
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (tags: [Tag], removedCount: Int) {
        return try await syncService.fullSync(progressHandler: progressHandler)
    }
    
    func refresh() async throws {
        try await syncService.refresh()
    }
    
    // MARK: - Cache Operations
    
    func getCachedTags() async throws -> [Tag] {
        return try await cacheService.getCachedTags()
    }
    
    func getCachedTagCount() async throws -> Int {
        return try await cacheService.getCachedTagCount()
    }
    
    func shouldRefreshCache() async throws -> Bool {
        let lastSync = try await cacheService.getLastSyncDate()
        return shouldRefreshCache(lastSyncDate: lastSync)
    }
    
    func getLastSyncDate() async throws -> Date? {
        return try await cacheService.getLastSyncDate()
    }
    
    // MARK: - Protocol Conformance
    
    func getAll() async throws -> [Tag] {
        return try await getCachedTags()
    }
    
    func getById(_ id: String) async throws -> Tag? {
        return try await getTag(id: id)
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a single tag from the server and local cache.
    func deleteTag(id: String) async throws {
        guard let url = settings.url else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        let query = StashQueries.tagDestroy(id: id)
        
        struct TagDestroyResult: Decodable {
            let tagDestroy: Bool
        }
        
        let _: TagDestroyResult = try await apiClient.fetch(
            query: query,
            variables: nil,
            url: url,
            apiKey: settings.apiKey
        )
        
        // Remove from local cache
        try await cacheService.deleteTag(id: id)
    }
    
    /// Deletes multiple tags from the server and local cache.
    func deleteTags(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        
        guard let url = settings.url else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        let query = StashQueries.tagsDestroy(ids: ids)
        
        struct TagsDestroyResult: Decodable {
            let tagsDestroy: Bool
        }
        
        let _: TagsDestroyResult = try await apiClient.fetch(
            query: query,
            variables: nil,
            url: url,
            apiKey: settings.apiKey
        )
        
        // Remove from local cache
        for id in ids {
            try await cacheService.deleteTag(id: id)
        }
    }
}
