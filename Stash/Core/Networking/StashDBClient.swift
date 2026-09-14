import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBClient")

// MARK: - Protocol

/// Protocol defining the StashDB GraphQL API client interface.
/// StashDB is an external database for adult content metadata.
protocol StashDBClientProtocol {
    func fetchFavoritePerformers(page: Int, perPage: Int) async throws -> StashDBPerformersData
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData
    func fetchPerformerScenes(performerId: String, page: Int, perPage: Int, excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData
    func fetchPerformerScenesOverview(performerId: String, page: Int, perPage: Int, excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData
    func fetchFavoriteStudios() async throws -> StashDBStudiosData
    func fetchScenesByPerformersAndStudios(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData
    func fetchScenesByPerformersAndStudiosOverview(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer
    func searchPerformers(term: String) async throws -> [StashDBPerformer]
    func fetchPerformerSceneIds(performerId: String, excludeVR: Bool, excludeCompilations: Bool) async throws -> [String]
    func fetchScenes(ids: [String]) async throws -> [StashDBScene]
    func fetchSceneDetails(id: String) async throws -> StashDBScene
}

/// StashDB GraphQL client for querying external scene and performer metadata.
///
/// This client communicates with StashDB (https://stashdb.org) to:
/// - Fetch favorite performers and studios
/// - Query scenes by performer or studio
/// - Search for performers
/// - Retrieve detailed scene and performer information
///
/// All methods use GraphQL queries defined in `StashDBQueries`.
@MainActor
class StashDBClient: StashDBClientProtocol {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let settings: any SettingsStoreProtocol
    
    init(apiKey: String, baseURL: String = "https://stashdb.org/graphql", settings: any SettingsStoreProtocol = SettingsStore.shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = URLSession(configuration: GraphQLClientConfiguration.stashDBConfiguration())
        self.settings = settings
    }
    
    
    /// Fetches favorite performers with full details.
    func fetchFavoritePerformers(page: Int, perPage: Int) async throws -> StashDBPerformersData {
        let variables: [String: Any] = [
            "page": page,
            "perPage": perPage
        ]
        
        let result: StashDBPerformersResult = try await fetch(query: StashDBQueries.favoritePerformers, variables: variables)
        return result.queryPerformers
    }
    
    /// Fetches favorite performers with minimal overview data.
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData {
        let variables: [String: Any] = [
            "page": page,
            "perPage": perPage
        ]
        
        let result: StashDBPerformersResult = try await fetch(query: StashDBQueries.favoritePerformersOverview, variables: variables)
        return result.queryPerformers
    }
    
    /// Fetches scenes for a specific performer with optional tag filtering.
    func fetchPerformerScenes(performerId: String, page: Int = 1, perPage: Int = 40, excludeVR: Bool = false, excludeCompilations: Bool = false) async throws -> StashDBScenesData {
        logger.info("Fetching scenes for StashDB performer ID: \(performerId, privacy: .public) (page: \(page), perPage: \(perPage))")
        
        let excludedTags = StashDBQueries.buildExcludedTags(excludeVR: excludeVR, excludeCompilations: excludeCompilations)
        
        let query: String
        let variables: [String: Any]
        
        if excludedTags.isEmpty {
            query = StashDBQueries.performerScenesSimple
            
            variables = [
                "performerId": performerId,
                "page": page,
                "perPage": perPage
            ]
        } else {
            query = StashDBQueries.performerScenesWithTagFilter
            
            variables = [
                "performerId": performerId,
                "excludedTags": excludedTags,
                "page": page,
                "perPage": perPage
            ]
        }
        
        let result: StashDBScenesQueryResult = try await fetch(query: query, variables: variables)
        return StashDBScenesData(count: result.queryScenes.count, scenes: result.queryScenes.scenes)
    }
    
    /// Fetches performer scenes overview (delegates to fetchPerformerScenes).
    func fetchPerformerScenesOverview(performerId: String, page: Int = 1, perPage: Int = 40, excludeVR: Bool = false, excludeCompilations: Bool = false) async throws -> StashDBScenesData {
        return try await fetchPerformerScenes(performerId: performerId, page: page, perPage: perPage, excludeVR: excludeVR, excludeCompilations: excludeCompilations)
    }
    
    /// Fetches all scene IDs for a performer (paginated internally).
    func fetchPerformerSceneIds(performerId: String, excludeVR: Bool, excludeCompilations: Bool) async throws -> [String] {
        logger.info("Fetching scene IDs for StashDB performer ID: \(performerId, privacy: .public)")
        
        let excludedTags = StashDBQueries.buildExcludedTags(excludeVR: excludeVR, excludeCompilations: excludeCompilations)
        
        var allIds: [String] = []
        var currentPage = 1
        let perPage = 100 // Efficient ID fetching
        var hasMore = true
        
        while hasMore {
            let query: String
            let variables: [String: Any]
            
            if excludedTags.isEmpty {
                 query = StashDBQueries.performerSceneIdsSimple
                variables = ["performerId": performerId, "page": currentPage, "perPage": perPage]
            } else {
                query = StashDBQueries.performerSceneIdsWithTagFilter
                variables = ["performerId": performerId, "excludedTags": excludedTags, "page": currentPage, "perPage": perPage]
            }
            
            let result: StashDBSceneIdsQueryResult = try await fetch(query: query, variables: variables)
            let ids = result.queryScenes.scenes.map { $0.id }
            
            allIds.append(contentsOf: ids)
            hasMore = ids.count == perPage
            
            // Optional: logger.debug("Fetched page \(currentPage) of IDs: \(ids.count)")
            currentPage += 1
        }
        
        logger.info("✅ Fetched total \(allIds.count) scene IDs")
        return allIds
    }
    
    /// Fetches full scene details for multiple scenes using batch query.
    func fetchScenes(ids: [String]) async throws -> [StashDBScene] {
        guard !ids.isEmpty else {
            return []
        }
        logger.info("Fetching details for \(ids.count) scenes using batch query")
        
        // Construct batch query with aliases (s0, s1, s2, etc.)
        let queryBody = ids.enumerated().map { index, id in
            "s\(index): findScene(id: \"\(id)\") { \(StashDBQueries.sceneFields) }"
        }.joined(separator: "\n")
        
        let query = StashDBQueries.batchFindScenes(fields: StashDBQueries.sceneFields, queryBody: queryBody)
        
        // Fetch as a Dictionary [Alias: Scene?]
        // We use optional Scene? because findScene might return null
        let result: [String: StashDBScene?] = try await fetch(query: query, variables: [:])
        
        // Extract scenes in order of original IDs (s0, s1, etc)
        // This ensures the ViewModel receives them in the same order as requested (if important)
        var scenes: [StashDBScene] = []
        for i in 0..<ids.count {
            let key = "s\(i)"
            if let sceneWrapper = result[key], let scene = sceneWrapper {
                scenes.append(scene)
            }
        }
        
        return scenes
    }
    
    /// Fetches a single scene's details.
    func fetchSceneDetails(id: String) async throws -> StashDBScene {
        let scenes = try await fetchScenes(ids: [id])
        guard let scene = scenes.first else {
            throw AppError.notFound("StashDB Scene")
        }
        return scene
    }
            

    
    /// Fetches all favorite studios (paginated internally).
    func fetchFavoriteStudios() async throws -> StashDBStudiosData {
        logger.info("Fetching favorite studios from StashDB")
        
        var allStudios: [StashDBStudio] = []
        var currentPage = 1
        let perPage = 100
        var totalCount = 0
        var hasMore = true
        
        while hasMore {
            let variables: [String: Any] = [
                "page": currentPage,
                "perPage": perPage
            ]
            
            let result: StashDBStudiosResult = try await fetch(query: StashDBQueries.favoriteStudios, variables: variables)
            
            totalCount = result.queryStudios.count
            allStudios.append(contentsOf: result.queryStudios.studios)
            hasMore = result.queryStudios.studios.count == perPage && allStudios.count < totalCount
            
            logger.debug("📄 Fetched page \(currentPage): \(result.queryStudios.studios.count) studios (total so far: \(allStudios.count)/\(totalCount))")
            
            currentPage += 1
        }
        
        logger.info("✅ Fetched all \(allStudios.count) favorite studios")
        return StashDBStudiosData(count: totalCount, studios: allStudios)
    }
    
    /// Fetches scenes by performers OR studios from the past month.
    func fetchScenesByPerformersAndStudios(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData {
        logger.info("Fetching scenes from StashDB by \(performerIds.count) performers OR \(studioIds.count) studios (past month only) - Exclude VR: \(excludeVR), Comp: \(excludeCompilations)")
        
        // Calculate date one month ago
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDate = dateFormatter.string(from: oneMonthAgo)
        
        let excludedTags = StashDBQueries.buildExcludedTags(excludeVR: excludeVR, excludeCompilations: excludeCompilations)
        
        let tagsFilter = excludedTags.isEmpty ? "null" : "{ value: [\(excludedTags.map { "\"\($0)\"" }.joined(separator: ", "))], modifier: EXCLUDES }"
        
        // Use task group to fetch both concurrently
        return try await withThrowingTaskGroup(of: [StashDBScene].self) { group in
            // Task 1: Fetch by Performers
            if !performerIds.isEmpty {
                group.addTask {
                    let performersFilter = "{ value: [\(performerIds.map { "\"\($0)\"" }.joined(separator: ", "))], modifier: INCLUDES }"
                    return try await self.fetchScenesHelper(
                        period: "Performers",
                        studiosFilter: "null",
                        performersFilter: performersFilter,
                        dateFilter: "{ value: \"\(startDate)\", modifier: GREATER_THAN }",
                        tagsFilter: tagsFilter
                    )
                }
            }
            
            // Task 2: Fetch by Studios
            if !studioIds.isEmpty {
                group.addTask {
                    let studiosFilter = "{ value: [\(studioIds.map { "\"\($0)\"" }.joined(separator: ", "))], modifier: INCLUDES }"
                    return try await self.fetchScenesHelper(
                        period: "Studios",
                        studiosFilter: studiosFilter,
                        performersFilter: "null",
                        dateFilter: "{ value: \"\(startDate)\", modifier: GREATER_THAN }",
                        tagsFilter: tagsFilter
                    )
                }
            }
            
            var allScenes: [StashDBScene] = []
            for try await scenes in group {
                allScenes.append(contentsOf: scenes)
            }
            
            // Deduplicate by ID
            var uniqueScenesDict: [String: StashDBScene] = [:]
            for scene in allScenes {
                uniqueScenesDict[scene.id] = scene
            }
            
            // Sort by date descending
            let sortedScenes = uniqueScenesDict.values.sorted {
                ($0.date ?? "") > ($1.date ?? "")
            }
            
            logger.info("✅ Fetched total \(sortedScenes.count) unique scenes (OR logic)")
            return StashDBScenesData(count: sortedScenes.count, scenes: sortedScenes)
        }
    }
    
    /// Fetches scenes by performers/studios overview (delegates).
    func fetchScenesByPerformersAndStudiosOverview(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData {
        // Delegates to fetchScenesByPerformersAndStudios with the same query
        return try await fetchScenesByPerformersAndStudios(performerIds: performerIds, studioIds: studioIds, excludeVR: excludeVR, excludeCompilations: excludeCompilations)
    }
    
    /// Helper to fetch scenes with dynamic filters (internal pagination).
    private func fetchScenesHelper(period: String, studiosFilter: String, performersFilter: String, dateFilter: String, tagsFilter: String) async throws -> [StashDBScene] {
        var allScenes: [StashDBScene] = []
        var currentPage = 1
        let perPage = 100
        var totalCount = 0
        var hasMore = true
        
        while hasMore {
            let query = StashDBQueries.scenesWithFilters(
                studiosFilter: studiosFilter,
                performersFilter: performersFilter,
                dateFilter: dateFilter,
                tagsFilter: tagsFilter
            )
            
            let variables: [String: Any] = [
                "page": currentPage,
                "perPage": perPage
            ]
            
            let result: StashDBScenesQueryResult = try await fetch(query: query, variables: variables)
            
            totalCount = result.queryScenes.count
            allScenes.append(contentsOf: result.queryScenes.scenes)
            hasMore = result.queryScenes.scenes.count == perPage && allScenes.count < totalCount
            
            logger.debug("📄 [\(period)] Fetched page \(currentPage): \(result.queryScenes.scenes.count) scenes")
            
            currentPage += 1
        }
        
        return allScenes
    }
    
    /// Fetches detailed information for a specific performer.
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer {
        logger.info("Fetching performer details from StashDB for ID: \(performerId, privacy: .public)")
        
        let variables: [String: Any] = [
            "id": performerId
        ]
        
        let result: StashDBPerformerDetailResult = try await fetch(query: StashDBQueries.performerDetails(id: performerId), variables: variables)
        logger.info("✅ Fetched performer details for: \(result.findPerformer.name, privacy: .public)")
        return result.findPerformer
    }
    
    /// Searches for performers by name or other criteria.
    func searchPerformers(term: String) async throws -> [StashDBPerformer] {
        let variables: [String: Any] = ["term": term]
        
        // Intermediate struct to handle potential missing fields
        struct SearchPerformerResult: Decodable {
            struct Performer: Decodable {
                let id: String?
                let name: String
                let birth_date: String?
                let country: String?
                let ethnicity: String?
                let height: Int?
                let hair_color: String?
                let eye_color: String?
                let breast_type: String?
                let career_start_year: Int?
                let career_end_year: Int?
                let scene_count: Int?
                let measurements: StashDBMeasurements?
                let tattoos: [StashDBBodyMod]?
                let piercings: [StashDBBodyMod]?
                let images: [StashDBImage]?
                let urls: [StashDBURL]?
            }
            let searchPerformer: [Performer]
        }
        
        let result: SearchPerformerResult = try await fetch(query: StashDBQueries.searchPerformers, variables: variables)
        
        return result.searchPerformer.map { p in
            StashDBPerformer(
                id: p.id ?? UUID().uuidString,
                name: p.name,
                disambiguation: nil,
                gender: nil,
                birthDate: p.birth_date,
                ethnicity: p.ethnicity,
                country: p.country,
                height: p.height,
                hairColor: p.hair_color,
                eyeColor: p.eye_color,
                measurements: p.measurements,
                breastType: p.breast_type,
                careerStartYear: p.career_start_year,
                careerEndYear: p.career_end_year,
                tattoos: p.tattoos,
                piercings: p.piercings,
                sceneCount: p.scene_count ?? 0,
                isFavorite: false,
                images: p.images,
                urls: p.urls
            )
        }
    }
    
    /// Executes a GraphQL query using shared executor.
    private func fetch<T: Decodable>(query: String, variables: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL) else {
            throw AppError.network(.invalidURL(baseURL))
        }
        
        let executor = GraphQLExecutor(session: session, logger: logger)
        
        do {
            return try await executor.execute(
                query: query,
                variables: variables,
                url: url,
                apiKey: apiKey,
                acceptedStatusCodes: 200...200,  // StashDB only accepts 200
                createEncodingError: { AppError.network(.encodingFailed) },
                createInvalidResponseError: { AppError.stashDB(.invalidResponse) },
                createHttpError: { code in
                    if code == 401 {
                        return AppError.stashDB(.unauthorizedAPIKey)
                    } else if code == 429 {
                        return AppError.stashDB(.rateLimited)
                    }
                    return AppError.network(.httpError(statusCode: code, response: nil))
                },
                createDecodingError: { error in AppError.network(.decodingFailed(error)) },
                createApiError: { errors in AppError.stashDB(.invalidResponse) }
            )
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unknown(error)
        }
    }
}

// MARK: - Private Helper Structs for ID Fetching

private struct StashDBSceneIdsQueryResult: Codable {
    let queryScenes: StashDBSceneIdsData
}

private struct StashDBSceneIdsData: Codable {
    let count: Int
    let scenes: [StashDBSceneId]
}

private struct StashDBSceneId: Codable {
    let id: String
}
