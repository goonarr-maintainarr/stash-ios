import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerFetchService")

/// Service responsible for fetching performer data from the API.
///
/// Handles:
/// - Paginated performer queries
/// - Individual performer lookups
/// - Performer scenes
/// - Bulk performer fetching
/// - Remote timestamp fetching
class PerformerFetchService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    private let database: StashDatabase
    let settings: any SettingsStoreProtocol
    private let cacheService: PerformerCacheService
    
    // Guard against concurrent getAllPerformers calls
    private let fetchGuard = FetchGuard()
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: any SettingsStoreProtocol,
        cacheService: PerformerCacheService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.cacheService = cacheService
    }
    
    // MARK: - API Methods
    
    /// Fetches a paginated list of performers.
    /// Fetches a paginated list of performers.
    func getPerformers(
        searchText: String = "",
        page: Int = 1,
        perPage: Int = 20,
        sortBy: PerformerSortType = .name,
        sortDirection: String = "ASC",
        studioId: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> PerformerRepositoryResult {
        let url = try settings.validateStashConfiguration()
        
        // First page and no search - try cache first (unless forcing refresh)
        // Similar to Scenes, bypass cache if studio filtering is active
        if !forceRefresh && page == 1 && searchText.isEmpty && studioId == nil {
            let shouldRefresh = try await cacheService.shouldRefreshCache()
            
            if !shouldRefresh {
                logger.info("✅ Cache is fresh, returning cached performers")
                let cached = try await cacheService.getCachedPerformers()
                return PerformerRepositoryResult(
                    performers: Array(cached.prefix(perPage)),
                    totalCount: cached.count,
                    hasMore: cached.count > perPage,
                    source: .cache
                )
            }
        }
        
        // Fetch from API
        logger.info("🌐 Fetching performers from API (page: \(page))")
        let query: String
        
        if let studioId = studioId {
            logger.debug("🔎 Filtering performers by Studio ID: \(studioId)")
            
            // 1. Fetch ALL scene performer IDs for this studio first (if not cacheable for now, just fetch)
            // Ideally we'd optimize this, but for now we aggregate.
            // Note: This paging logic is tricky with 2-step.
            // We need to fetch ALL IDs, then page locally or page the ID query?
            // "findPerformersByIds" supports pagination.
            // So we need ALL IDs first.
            
            let idQuery = StashQueries.findStudioScenePerformerIDs(studioId: studioId)
             struct SceneIDResult: Decodable {
                struct SceneContainer: Decodable {
                    struct Scene: Decodable {
                        struct Perf: Decodable { let id: String }
                        let performers: [Perf]?
                    }
                    let scenes: [Scene]
                }
                let findScenes: SceneContainer
            }
            
            // We need to fetch this only once ideally? Or every time?
            // For simplicity/correctness, we fetch every time for now unless we cache it contextually.
            // But we can't cache in `PerformerFetchService` easily without state.
            // Let's assume the network is fast enough or use a very basic cache if needed.
            
            // Actually, we can just run the ID fetch.
            let idResult: SceneIDResult = try await fetchWithErrorWrapping(query: idQuery, variables: nil, url: url)
            let allAccIds = Set(idResult.findScenes.scenes.flatMap { $0.performers?.map(\.id) ?? [] })
            let ids = Array(allAccIds)
            
            if ids.isEmpty {
                 return PerformerRepositoryResult(
                    performers: [],
                    totalCount: 0,
                    hasMore: false,
                    source: .api
                )
            }
            
            // 2. Fetch Performers by IDs
            query = StashQueries.findPerformersByIds(
                ids: ids,
                page: page,
                perPage: perPage,
                sort: sortBy.rawValue,
                direction: sortDirection
            )
            
        } else {
            query = StashQueries.findPerformers(
                searchText: searchText,
                page: page,
                perPage: perPage,
                sort: sortBy.rawValue,
                direction: sortDirection
            )
        }
        
        let result: PerformerResultDTO = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        let domainResult = result.findPerformers.toDomain()
        let performers = domainResult.performers
        let totalCount = domainResult.count
        
        logger.info("📦 Received \(performers.count) performers from API (total: \(totalCount))")
        
        // Cache first page of default view ONLY
        if page == 1 && searchText.isEmpty && studioId == nil {
            try await cacheService.cachePerformers(performers)
        }
        
        return PerformerRepositoryResult(
            performers: performers,
            totalCount: totalCount,
            hasMore: performers.count == perPage && (page * perPage) < totalCount,
            source: .api
        )
    }
    
    /// Fetches a single performer by ID.
    func getPerformer(id: String) async throws -> Performer? {
        let url = try settings.validateStashConfiguration()
        
        let query = StashQueries.findPerformer(id: id)
        
        struct PerformerResult: Decodable {
            let findPerformer: Performer?
        }
        
        let result: PerformerResult = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        return result.findPerformer
    }
    
    /// Fetches all performers from the API and caches them.
    func getAllPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer] {
        let url = try settings.validateStashConfiguration()
        
        // Prevent concurrent fetches
        let started = await fetchGuard.beginIfPossible()
        if !started {
            logger.info("⏭️ Already fetching all performers, returning cached data")
            return try await cacheService.getCachedPerformers()
        }
        
        defer {
            Task { await fetchGuard.end() }
        }
        
        var allPerformers: [Performer] = []
        var page = 1
        let perPage = 500
        var hasMore = true
        var totalCount = 0
        
        logger.info("🌐 Fetching ALL performers from API...")
        
        while hasMore {
            let query = StashQueries.findPerformers(
                searchText: "",
                page: page,
                perPage: perPage,
                sort: "name",
                direction: "ASC"
            )
            
            let result: PerformerResultDTO = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )
            
            let domainResult = result.findPerformers.toDomain()
            totalCount = domainResult.count
            allPerformers.append(contentsOf: domainResult.performers)
            hasMore = domainResult.performers.count == perPage
            
            
            page += 1
            
            // Report progress
            if let handler = progressHandler {
                await handler(allPerformers.count, totalCount)
            }
        }
        
        logger.info("✅ Fetched \(allPerformers.count) performers total")
        
        // Cache all performers
        try await cacheService.cachePerformers(allPerformers)
        
        return allPerformers
    }
    
    /// Fetches all scenes for a specific performer.
    func getPerformerScenes(performerId: String) async throws -> [Scene] {
        let url = try settings.validateStashConfiguration()
        
        var allScenes: [Scene] = []
        var page = 1
        let perPage = 100
        var hasMore = true
        
        while hasMore {
            let query = StashQueries.findPerformerScenes(
                performerId: performerId,
                page: page,
                perPage: perPage
            )
            
            let result: SceneResultDTO = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )
            
            let scenes = result.findScenes.toDomain().scenes
            allScenes.append(contentsOf: scenes)
            
            if scenes.count < perPage {
                hasMore = false
            } else {
                page += 1
            }
        }
        
        logger.info("📦 Fetched \(allScenes.count) scenes for performerId: \(performerId)")
        return allScenes
    }
    
    /// Fetches lightweight timestamp data for all remote performers.
    func fetchRemotePerformerTimestamps(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [String: String] {
        let url = try settings.validateStashConfiguration()
        
        struct TSResult: Codable {
            struct TSPerformers: Codable {
                let count: Int
                let performers: [PerformerTS]
            }
            struct PerformerTS: Codable {
                let id: String
                let updated_at: String?
            }
            let findPerformers: TSPerformers
        }
        
        return try await fetchRemoteTimestamps(
            queryBuilder: { StashQueries.findPerformerTimestamps(page: $0, perPage: $1) },
            url: url,
            transform: { (result: TSResult) in
                (result.findPerformers.count, result.findPerformers.performers.map { ($0.id, $0.updated_at) })
            },
            perPage: 500,
            progressHandler: progressHandler
        )
    }
    
}
