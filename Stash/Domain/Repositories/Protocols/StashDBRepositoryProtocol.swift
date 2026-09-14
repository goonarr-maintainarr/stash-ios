import Foundation
import Combine

/// Protocol defining data access methods for StashDB scenes and performers.
///
/// This protocol abstracts the StashDB API and caching layer, allowing ViewModels
/// to fetch StashDB data without direct knowledge of the underlying services.
protocol StashDBRepositoryProtocol {
    /// Fetches details for a specific scene by ID.
    func fetchSceneDetails(id: String) async throws -> StashDBScene
    
    /// Fetches full scene details for multiple scenes using batch query.
    func fetchScenes(ids: [String]) async throws -> [StashDBScene]
    
    /// Fetches details for a specific performer by ID.
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer
    
    /// Fetches a paginated list of favorite performers.
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData
    
    /// Fetches a list of favorite studios.
    func fetchFavoriteStudios() async throws -> StashDBStudiosData
    
    /// Fetches scenes filtering by performers and studios, excluding specific types.
    func fetchScenesByPerformersAndStudiosOverview(
        performerIds: [String],
        studioIds: [String],
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> StashDBScenesData
    
    /// Fetches all scene IDs for a specific performer.
    func fetchPerformerSceneIds(
        performerId: String,
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> [String]
    
    /// Fetches a paginated list of scenes for a specific performer.
    func fetchPerformerScenesOverview(
        performerId: String,
        page: Int,
        perPage: Int,
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> StashDBScenesData
    
    /// Search performers on a specific StashDB endpoint.
    func searchPerformers(term: String, endpoint: String, apiKey: String) async throws -> [StashDBPerformer]
    
    /// Fetches scenes from favorite performers and studios on StashDB.
    func fetchFavoriteScenesFromStashDB(
        excludeVR: Bool,
        excludeCompilations: Bool,
        excludeOwned: Bool
    ) async throws -> [StashDBScene]?
    
    /// Retrieves cached favorite scenes from the local database.
    func getCachedFavoriteScenes() async -> [StashDBScene]?
    
    /// Caches the provided scenes to the local database.
    func cacheFavoriteScenes(_ scenes: [StashDBScene]) async
}
