import Foundation
import Nuke
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneRepository")

/// A repository responsible for managing Scene data.
///
/// Acts as a coordinator that delegates to specialized services:
/// - SceneCacheService: Cache operations
/// - SceneFetchService: Read operations
/// - SceneMutationService: Write operations
/// - SceneScrapeService: StashBox integration
/// - SceneSyncService: Synchronization
class SceneRepository: BaseRepository, SceneRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Services
    
    private let cacheService: SceneCacheService
    private let fetchService: SceneFetchService
    private let mutationService: SceneMutationService
    private let scrapeService: SceneScrapeService
    private let syncService: SceneSyncService
    
    // Guard against concurrent getAllScenes calls
    private let fetchGuard = FetchGuard()
    
    /// Initializes a new instance of `SceneRepository`.
    ///
    /// - Parameters:
    ///   - apiClient: The client used for making GraphQL requests.
    ///   - database: The local database for caching.
    ///   - settings: The store for user settings.
    ///   - imagePrefetchManager: Manager for image prefetching.
    override init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        imagePrefetchManager: ImagePrefetchService
    ) {
        // Initialize services
        self.cacheService = SceneCacheService(
            database: database,
            settings: settings,
            imagePrefetchManager: imagePrefetchManager
        )
        
        self.fetchService = SceneFetchService(
            apiClient: apiClient,
            database: database,
            settings: settings,
            cacheService: cacheService
        )
        
        self.mutationService = SceneMutationService(
            apiClient: apiClient,
            database: database,
            settings: settings,
            fetchService: fetchService
        )
        
        self.scrapeService = SceneScrapeService(
            apiClient: apiClient,
            settings: settings,
            fetchService: fetchService
        )
        
        self.syncService = SceneSyncService(
            apiClient: apiClient,
            database: database,
            settings: settings,
            cacheService: cacheService,
            imagePrefetchManager: imagePrefetchManager
        )
        
        super.init(apiClient: apiClient, database: database, settings: settings, imagePrefetchManager: imagePrefetchManager)
    }
    
    // MARK: - Read Methods (Delegated to FetchService)
    
    func getScenes(
        searchText: String = "",
        page: Int = 1,
        perPage: Int = 20,
        sortBy: SceneSortType = .createdAt,
        sortDirection: String = "DESC",
        tagIds: [String]? = nil,
        studioId: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> SceneRepositoryResult {
        return try await fetchService.getScenes(
            searchText: searchText,
            page: page,
            perPage: perPage,
            sortBy: sortBy,
            sortDirection: sortDirection,
            tagIds: tagIds,
            studioId: studioId,
            forceRefresh: forceRefresh
        )
    }
    
    func getScene(id: String, forceRefresh: Bool = false) async throws -> Scene? {
        return try await fetchService.getScene(id: id, forceRefresh: forceRefresh)
    }

    func getSceneStreams(id: String) async throws -> [SceneStreamEndpoint] {
        return try await fetchService.getSceneStreams(id: id)
    }
    
    func getAllScenes(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Scene] {
        // Prevent concurrent fetches - return cached data if already fetching
        let started = await fetchGuard.beginIfPossible()
        if !started {
            logger.info("⏭️ Already fetching all scenes, returning cached data")
            return try await getCachedScenes()
        }
        
        defer {
            Task { await fetchGuard.end() }
        }
        
        return try await fetchService.getAllScenes(progressHandler: progressHandler)
    }
    
    func fetchSceneDetails(for ids: [String], url: URL, apiKey: String) async throws -> [Scene] {
        return try await fetchService.fetchSceneDetails(for: ids)
    }
    
    // MARK: - Mutations (Delegated to MutationService)
    
    func incrementOCounter(for sceneId: String, currentCount: Int?) async throws -> Scene {
        return try await mutationService.incrementOCounter(for: sceneId, currentCount: currentCount)
    }
    
    func updateRating(for sceneId: String, rating: Int) async throws -> Scene {
        return try await mutationService.updateRating(for: sceneId, rating: rating)
    }
    
    func updateTitle(for sceneId: String, title: String) async throws -> Scene {
        return try await mutationService.updateTitle(for: sceneId, title: title)
    }
    
    func updateScene(id: String, title: String?, details: String?, performerIds: [String]?, tagIds: [String]?, coverImage: String?, director: String?, code: String?, url: String?) async throws -> Scene {
        return try await mutationService.updateScene(id: id, title: title, details: details, performerIds: performerIds, tagIds: tagIds, coverImage: coverImage, director: director, code: code, url: url)
    }
    
    func deleteOHistory(sceneId: String, times: [String]) async throws {
        try await mutationService.deleteOHistory(sceneId: sceneId, times: times)
    }
    
    func deletePlayHistory(sceneId: String, times: [String]) async throws {
        try await mutationService.deletePlayHistory(sceneId: sceneId, times: times)
    }
    
    func deleteScene(id: String, deleteFile: Bool, deleteGenerated: Bool) async throws -> Bool {
        return try await mutationService.deleteScene(id: id, deleteFile: deleteFile, deleteGenerated: deleteGenerated)
    }
    
    // MARK: - Scraping (Delegated to ScrapeService)
    
    func fetchStashBoxes() async throws -> [StashBox] {
        return try await scrapeService.fetchStashBoxes()
    }
    
    func scrapeScene(id: String, title: String?, stashBox: StashBox) async throws -> [ScrapedScene] {
        return try await scrapeService.scrapeScene(id: id, title: title, stashBox: stashBox)
    }
    
    func scrapeSceneByFragment(fragment: SceneFragmentInput, stashBox: StashBox) async throws -> [ScrapedScene] {
        return try await scrapeService.scrapeSceneByFragment(fragment: fragment, stashBox: stashBox)
    }
    
    func applyScrapeResult(to sceneId: String, result: ScrapedScene, options: ScrapeApplyOptions) async throws -> Scene {
        return try await scrapeService.applyScrapeResult(to: sceneId, result: result, options: options)
    }
    
    func fetchTaggerConfig() async throws -> TaggerConfig {
        return try await scrapeService.fetchTaggerConfig()
    }
    
    func saveTaggerConfig(_ config: TaggerConfig) async throws {
        try await scrapeService.saveTaggerConfig(config)
    }
    
    func saveScene(_ scene: Scene) async throws {
        // saveSceneDetails handles the full persistence including timestamps
        try await database.saveSceneDetails(scene)
    }
    
    // MARK: - Cache Methods (Delegated to CacheService)
    
    func getCachedScenes() async throws -> [Scene] {
        return try await cacheService.getCachedScenes()
    }
    
    func getCachedSceneCount() async throws -> Int {
        return try await database.fetchSceneCount()
    }
    
    func shouldRefreshCache() async throws -> Bool {
        return try await cacheService.shouldRefreshCache()
    }
    
    func getLastSyncDate() async throws -> Date? {
        return try await database.getLastSyncDate()
    }
    
    func refresh() async throws {
        let result = try await getScenes(page: 1, perPage: 20)
        try await cacheService.cacheScenes(result.scenes)
    }
    
    func prefetchImages(for scenes: [Scene], count: Int = 10) async {
        await cacheService.prefetchImages(for: scenes, count: count)
    }
    
    func prefetchDetails(for sceneIds: [String]) async {
        // TODO: Implementation for details prefetching (often not image related, so kept separate)
    }
    
    // MARK: - Efficient Queries (Home Screen Optimization)
    
    func getCachedSceneById(_ id: String) async throws -> Scene? {
        return try await database.fetchSceneById(id)
    }
    
    func getCachedScenesByTagIds(
        _ tagIds: [String],
        limit: Int? = nil,
        sortBy: String? = nil,
        ascending: Bool = false
    ) async throws -> [Scene] {
        return try await database.fetchScenesByTagIds(tagIds, limit: limit, sortBy: sortBy, ascending: ascending)
    }
    
    func getCachedScenesSorted(
        by column: String,
        ascending: Bool = false,
        limit: Int? = nil
    ) async throws -> [Scene] {
        return try await database.fetchScenesSorted(by: column, ascending: ascending, limit: limit)
    }
    
    func getCachedRandomScenes(limit: Int) async throws -> [Scene] {
        return try await database.fetchRandomScenes(limit: limit)
    }
    
    // MARK: - Syncing (Delegated to SyncService)
    
    func syncNewScenes(progressHandler: (@MainActor (Int, Int) -> Void)?, checkForDeletions: Bool = true) async throws -> [Scene] {
        return try await syncService.syncNewScenes(progressHandler: progressHandler, checkForDeletions: checkForDeletions)
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (scenes: [Scene], removedCount: Int) {
        return try await syncService.fullSync(progressHandler: progressHandler) { [weak self] in
            guard let self = self else { throw AppError.repository(.invalidConfiguration) }
            return try await self.getAllScenes(progressHandler: progressHandler)
        }
    }
    
    func syncChangedScenes() async throws -> [Scene] {
        return try await syncService.syncChangedScenes()
    }
    
    // MARK: - Protocol Conformance
    
    func getAll() async throws -> [Scene] {
        return try await getCachedScenes()
    }
    
    func getById(_ id: String) async throws -> Scene? {
        return try await getScene(id: id)
    }
}
