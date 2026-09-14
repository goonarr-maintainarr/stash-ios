import Foundation
import os

/// Repository for accessing StashDB data with caching support.
///
/// This repository acts as a coordinator, delegating operations to specialized service classes
/// for better separation of concerns and maintainability.
class StashDBRepository: StashDBRepositoryProtocol {
    
    // Service layer
    private let fetchService: StashDBFetchService
    private let cacheService: StashDBCacheService
    
    /// Initializes a new StashDBRepository.
    ///
    /// - Parameters:
    ///   - stashDBClient: The client for StashDB API calls.
    ///   - whisparrDatabase: Database for checking owned scenes.
    ///   - stashDatabase: Database for caching.
    ///   - settings: Settings store for API keys and preferences.
    init(
        stashDBClient: StashDBClientProtocol,
        whisparrDatabase: WhisparrDatabase,
        stashDatabase: StashDatabase,
        settings: SettingsStoreProtocol
    ) {
        // Initialize services
        self.fetchService = StashDBFetchService(stashDBClient: stashDBClient, whisparrDatabase: whisparrDatabase, settings: settings)
        self.cacheService = StashDBCacheService(stashDatabase: stashDatabase, settings: settings)
    }
    
    // MARK: - Scene Operations
    
    func fetchSceneDetails(id: String) async throws -> StashDBScene {
        return try await fetchService.fetchSceneDetails(id: id)
    }
    
    func fetchScenes(ids: [String]) async throws -> [StashDBScene] {
        return try await fetchService.fetchScenes(ids: ids)
    }
    
    // MARK: - Performer Operations
    
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer {
        return try await fetchService.fetchPerformerDetails(performerId: performerId)
    }
    
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData {
        return try await fetchService.fetchFavoritePerformersOverview(page: page, perPage: perPage)
    }
    
    func fetchPerformerSceneIds(
        performerId: String,
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> [String] {
        return try await fetchService.fetchPerformerSceneIds(
            performerId: performerId,
            excludeVR: excludeVR,
            excludeCompilations: excludeCompilations
        )
    }
    
    func fetchPerformerScenesOverview(
        performerId: String,
        page: Int,
        perPage: Int,
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> StashDBScenesData {
        return try await fetchService.fetchPerformerScenesOverview(
            performerId: performerId,
            page: page,
            perPage: perPage,
            excludeVR: excludeVR,
            excludeCompilations: excludeCompilations
        )
    }
    
    func searchPerformers(term: String, endpoint: String, apiKey: String) async throws -> [StashDBPerformer] {
        return try await fetchService.searchPerformers(term: term, endpoint: endpoint, apiKey: apiKey)
    }
    
    // MARK: - Studio Operations
    
    func fetchFavoriteStudios() async throws -> StashDBStudiosData {
        return try await fetchService.fetchFavoriteStudios()
    }
    
    func fetchScenesByPerformersAndStudiosOverview(
        performerIds: [String],
        studioIds: [String],
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> StashDBScenesData {
        return try await fetchService.fetchScenesByPerformersAndStudiosOverview(
            performerIds: performerIds,
            studioIds: studioIds,
            excludeVR: excludeVR,
            excludeCompilations: excludeCompilations
        )
    }
    
    // MARK: - Favorites
    
    func fetchFavoriteScenesFromStashDB(
        excludeVR: Bool,
        excludeCompilations: Bool,
        excludeOwned: Bool
    ) async throws -> [StashDBScene]? {
        return try await fetchService.fetchFavoriteScenesFromStashDB(
            excludeVR: excludeVR,
            excludeCompilations: excludeCompilations,
            excludeOwned: excludeOwned
        )
    }
    
    // MARK: - Cache Operations
    
    func getCachedFavoriteScenes() async -> [StashDBScene]? {
        return await cacheService.getCachedFavoriteScenes()
    }
    
    func cacheFavoriteScenes(_ scenes: [StashDBScene]) async {
        await cacheService.cacheFavoriteScenes(scenes)
    }
}
