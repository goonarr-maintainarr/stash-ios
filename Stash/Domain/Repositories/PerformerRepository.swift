import Foundation
import Nuke
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerRepository")

/// A repository responsible for managing Performer data.
///
/// Acts as a coordinator that delegates to specialized services:
/// - PerformerCacheService: Cache operations
/// - PerformerFetchService: Read operations
/// - PerformerMutationService: Write operations
/// - PerformerScrapeService: StashBox integration
/// - PerformerSyncService: Synchronization
class PerformerRepository: BaseRepository, PerformerRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Services
    
    private let cacheService: PerformerCacheService
    private let fetchService: PerformerFetchService
    private let mutationService: PerformerMutationService
    private let scrapeService: PerformerScrapeService
    private let syncService: PerformerSyncService
    
    // Guard against concurrent getAllPerformers calls
    private let fetchGuard = FetchGuard()
    
    // MARK: - Initialization
    
    override init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        imagePrefetchManager: ImagePrefetchService
    ) {
        // Initialize services
        self.cacheService = PerformerCacheService(
            database: database,
            settings: settings,
            imagePrefetchManager: imagePrefetchManager
        )
        
        self.fetchService = PerformerFetchService(
            apiClient: apiClient,
            database: database,
            settings: settings,
            cacheService: cacheService
        )
        
        self.mutationService = PerformerMutationService(
            apiClient: apiClient,
            database: database,
            settings: settings,
            fetchService: fetchService
        )
        
        self.scrapeService = PerformerScrapeService(
            apiClient: apiClient,
            settings: settings
        )
        
        self.syncService = PerformerSyncService(
            apiClient: apiClient,
            database: database,
            settings: settings,
            fetchService: fetchService,
            cacheService: cacheService
        )
        
        super.init(apiClient: apiClient, database: database, settings: settings, imagePrefetchManager: imagePrefetchManager)
    }
    
    // MARK: - Read Methods (Delegated to FetchService)
    
    func getPerformers(
        searchText: String = "",
        page: Int = 1,
        perPage: Int = 20,
        sortBy: PerformerSortType = .name,
        sortDirection: String = "ASC",
        studioId: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> PerformerRepositoryResult {
        return try await fetchService.getPerformers(
            searchText: searchText,
            page: page,
            perPage: perPage,
            sortBy: sortBy,
            sortDirection: sortDirection,
            studioId: studioId,
            forceRefresh: forceRefresh
        )
    }
    
    func getPerformer(id: String, forceRefresh: Bool = false) async throws -> (performer: Performer, scenes: [Scene])? {
        if !forceRefresh {
            if let cached = try await database.fetchPerformerDetails(id: id) {
                return (cached.performer, cached.scenes)
            }
        }
        
        // Fetch from API
        guard let performer = try await fetchService.getPerformer(id: id) else { return nil }
        let scenes = try await fetchService.getPerformerScenes(performerId: id)
        
        // Save to cache
        try await database.savePerformerDetails(performer, scenes: scenes)
        
        return (performer, scenes)
    }
    
    func getAllPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer] {
        // Prevent concurrent fetches
        let started = await fetchGuard.beginIfPossible()
        if !started {
            logger.info("⏭️ Already fetching all performers, returning cached data")
            return try await getCachedPerformers()
        }
        
        defer {
            Task { await fetchGuard.end() }
        }
        
        return try await fetchService.getAllPerformers(progressHandler: progressHandler)
    }
    
    func getPerformerScenes(performerId: String) async throws -> [Scene] {
        return try await fetchService.getPerformerScenes(performerId: performerId)
    }
    
    // MARK: - Mutations (Delegated to MutationService)
    
    func createPerformer(input: PerformerCreateInput) async throws -> String {
        return try await mutationService.createPerformer(input: input)
    }
    
    func updatePerformer(input: PerformerUpdateInput) async throws -> String {
        return try await mutationService.updatePerformer(input: input)
    }
    
    func deletePerformer(id: String) async throws -> Bool {
        return try await mutationService.deletePerformer(id: id)
    }
    
    // MARK: - Scraping (Delegated to ScrapeService)
    
    func searchPerformer(term: String) async throws -> [PerformerScrapeResult] {
        return try await scrapeService.searchPerformer(term: term)
    }
    
    func fetchStashBoxConfiguration() async throws -> StashBoxConfiguration {
        return try await scrapeService.fetchStashBoxConfiguration()
    }
    
    // MARK: - Cache Methods (Delegated to CacheService)
    
    func getCachedPerformers() async throws -> [Performer] {
        return try await cacheService.getCachedPerformers()
    }
    
    func getCachedPerformerCount() async throws -> Int {
        return try await cacheService.getCachedPerformerCount()
    }
    
    func getCachedPerformerById(_ id: String) async throws -> Performer? {
        return try await database.fetchPerformerById(id)
    }
    
    func shouldRefreshCache() async throws -> Bool {
        return try await cacheService.shouldRefreshCache()
    }
    
    func getLastSyncDate() async throws -> Date? {
        return try await cacheService.getLastSyncDate()
    }
    
    func prefetchImages(for performers: [Performer], count: Int = 10) async {
        cacheService.prefetchImages(for: performers, count: count)
    }
    
    // MARK: - Syncing (Delegated to SyncService)
    
    func syncNewPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer] {
        return try await syncService.syncNewPerformers(progressHandler: progressHandler)
    }
    
    func syncChangedPerformers() async throws -> [Performer] {
        return try await syncService.syncChangedPerformers()
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (performers: [Performer], removedCount: Int) {
        logger.info("🔄 Starting full performer sync...")
        
        // Get current cache count before sync
        let cachedBefore = try await getCachedPerformers()
        let cachedBeforeCount = cachedBefore.count
        
        // Fetch all performers from API
        let allPerformers = try await getAllPerformers(progressHandler: progressHandler)
        
        // Remove deleted performers
        let performerIds = Set(allPerformers.map { $0.id })
        try await database.removeDeletedPerformers(keeping: performerIds)
        
        // Calculate how many were removed
        let cachedAfter = try await getCachedPerformers()
        let removedCount = max(0, cachedBeforeCount - cachedAfter.count + (allPerformers.count - cachedBeforeCount))
        
        logger.info("✅ Full performer sync complete: \(allPerformers.count) performers, \(removedCount) removed")
        
        return (allPerformers, removedCount)
    }
    
    // MARK: - Protocol Conformance
    
    func getAll() async throws -> [Performer] {
        return try await getCachedPerformers()
    }
    
    func getById(_ id: String) async throws -> Performer? {
        return try await getPerformer(id: id)?.performer
    }
    
    func refresh() async throws {
        let result = try await getPerformers(page: 1, perPage: 20)
        try await cacheService.cachePerformers(result.performers)
    }
}
