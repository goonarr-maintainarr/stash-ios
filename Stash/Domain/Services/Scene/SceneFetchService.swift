import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneFetchService")

/// Service responsible for fetching scene data from the Stash API and local database.
///
/// Handles all read operations including:
/// - Paginated scene lists
/// - Single scene details
/// - Core/related scene data
/// - Streaming endpoints
/// - Bulk scene fetching
class SceneFetchService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    private let database: StashDatabase
    let settings: any SettingsStoreProtocol
    private let cacheService: SceneCacheService
    
    // Guard against concurrent getAllScenes calls
    private let fetchGuard = FetchGuard()
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: any SettingsStoreProtocol,
        cacheService: SceneCacheService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.cacheService = cacheService
    }
    
    // MARK: - Fetch Operations
    
    /// Fetches a paginated list of scenes, optionally filtered by search text or tags.
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
        let url = try settings.validateStashConfiguration()
        
        // First page and no search - try cache first (unless forcing refresh)
        // Note: We don't currently cache by studioId strictly, unless we implement complex cache filtering.
        // For now, bypass cache if studioId is present, OR implement cache filtering.
        // Given Studio scenes can be large, maybe just stick to API for now or simple filtering if cache is valid?
        // Let's stick to API for filtered views for robustness, similar to Tags.
        if !forceRefresh && page == 1 && searchText.isEmpty && tagIds == nil && studioId == nil {
            let shouldRefresh = try await cacheService.shouldRefreshCache()
            
            if !shouldRefresh {
                logger.info("✅ Cache is fresh, returning cached scenes")
                let cached = try await cacheService.getCachedScenes()
                return SceneRepositoryResult(
                    scenes: Array(cached.prefix(perPage)),
                    totalCount: cached.count,
                    hasMore: cached.count > perPage,
                    source: .cache
                )
            }
        }
        
        // Fetch from API
        logger.info("🌐 Fetching scenes from API (page: \(page))")
        let query: String
        
        if let studioId = studioId {
            logger.debug("🔎 Filtering by Studio ID: \(studioId)")
            query = StashQueries.findStudioScenes(
                studioId: studioId,
                page: page,
                perPage: perPage
            )
        } else if let tagIds = tagIds, !tagIds.isEmpty {
            query = StashQueries.findScenesByTag(
                tagIds: tagIds,
                page: page,
                perPage: perPage,
                sort: sortBy.rawValue,
                direction: sortDirection
            )
        } else {
            query = StashQueries.findScenes(
                searchText: searchText,
                page: page,
                perPage: perPage,
                sort: sortBy.rawValue,
                direction: sortDirection
            )
        }
        
        let result: SceneResultDTO = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        let domainResult = result.findScenes.toDomain()
        let scenes = domainResult.scenes
        let totalCount = domainResult.count
        
        logger.info("📦 Received \(scenes.count) scenes from API (total: \(totalCount))")
        
        // Cache first page of default view ONLY
        if page == 1 && searchText.isEmpty && tagIds == nil && studioId == nil {
            try await cacheService.cacheScenes(scenes)
        }
        
        return SceneRepositoryResult(
            scenes: scenes,
            totalCount: totalCount,
            hasMore: scenes.count == perPage && (page * perPage) < totalCount, // Approximate hasMore check
            source: .api
        )
    }
    
    /// Fetches a single scene by ID, including detailed metadata.
    func getScene(id: String, forceRefresh: Bool = false) async throws -> Scene? {
        let url = try settings.validateStashConfiguration()
        
        // Try to load from database first unless forced refresh
        if !forceRefresh {
            if let cached = try await database.fetchSceneDetails(id: id) {
                let cacheAge = Date().timeIntervalSince(cached.cachedAt)
                let hasStashIds = cached.scene.stash_ids?.isEmpty == false
                let isStale = cacheAge > 86400 // 24 hours
                
                if !isStale && hasStashIds {
                    logger.info("📦 Returning cached scene details for: \(cached.scene.title ?? "Unknown")")
                    return cached.scene
                }
            }
        }
        
        // Fetch from API
        let query = StashQueries.findScene(id: id)
        let result: SingleSceneResultDTO = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        if let scene = result.toDomain() {
             // Save to cache
             try await database.saveSceneDetails(scene)
             return scene
        }
        
        return nil
    }
    
    /// Fetches all available streaming endpoints for a scene.
    func getSceneStreams(id: String) async throws -> [SceneStreamEndpoint] {
        let url = try settings.validateStashConfiguration()
        let query = StashQueries.sceneStreams(id: id)
        
        let result: SceneStreamResult = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        return result.sceneStreams
    }
    
    /// Fetches all scenes from the API and caches them.
    ///
    /// This is a heavy operation used for full syncs.
    func getAllScenes(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Scene] {
        let url = try settings.validateStashConfiguration()
        
        // Prevent concurrent fetches - return cached data if already fetching
        let started = await fetchGuard.beginIfPossible()
        if !started {
            logger.info("⏭️ Already fetching all scenes, returning cached data")
            return try await cacheService.getCachedScenes()
        }
        
        defer {
            Task { await fetchGuard.end() }
        }
        
        var allScenes: [Scene] = []
        var currentPage = 1
        let perPage = 100 // Small page size to prevent WebSocket message overflow (10MB limit)
        var hasMore = true
        var totalCount = 0
        
        logger.info("🌐 Fetching all scenes from API...")
        
        while hasMore {
            let query = StashQueries.findScenesListCore(
                searchText: "",
                page: currentPage,
                perPage: perPage,
                sort: "created_at",
                direction: "DESC"
            )
            
            let result: SceneResultDTO = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )
            
            let domainResult = result.findScenes.toDomain()
            let scenes = domainResult.scenes
            totalCount = domainResult.count
            allScenes.append(contentsOf: scenes)
            
            hasMore = scenes.count == perPage
            currentPage += 1
            
            logger.debug("📦 Fetched page \(currentPage - 1): \(scenes.count) scenes (total so far: \(allScenes.count))")
            
            // Report progress
            if let handler = progressHandler {
                await handler(allScenes.count, totalCount)
            }
        }
        
        logger.info("✅ Fetched \(allScenes.count) scenes total")
        
        // Cache all scenes
        try await cacheService.cacheScenes(allScenes)
        
        return allScenes
    }
    
    /// Fetches details for a batch of scene IDs using raw POST request to handle dynamic keys.
    func fetchSceneDetails(for ids: [String]) async throws -> [Scene] {
        guard !ids.isEmpty else { return [] }
        
        let url = try settings.validateStashConfiguration()
        let query = StashQueries.findScenesBatch(ids: ids)
        
        // Make raw HTTP request to get JSON response
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.apiKey, forHTTPHeaderField: "ApiKey")
        
        let body: [String: Any] = [
            "query": query,
            "variables": [:]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AppError.network(.encodingFailed)
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw AppError.network(error.toNetworkError())
        } catch {
            throw AppError.unknown(error)
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(.unknown(URLError(.badServerResponse)))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError.network(.httpError(statusCode: httpResponse.statusCode, response: data))
        }
        
        // Parse the GraphQL response
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObject = jsonResponse["data"] as? [String: Any] else {
            throw AppError.stashAPI(.invalidResponse)
        }
        
        // Extract scenes from the response
        var fetchedScenes: [Scene] = []
        for (index, _) in ids.enumerated() {
            if let sceneData = dataObject["scene\(index)"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: sceneData)
                let sceneDTO = try JSONDecoder().decode(SceneDTO.self, from: jsonData)
                fetchedScenes.append(sceneDTO.toDomain())
            }
        }
        
        // Save batch to database
        if !fetchedScenes.isEmpty {
            try await database.saveScenes(fetchedScenes)
        }
    
        return fetchedScenes
    }
    
}
