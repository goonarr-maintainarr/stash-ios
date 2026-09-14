import Foundation
import Combine

/// A protocol defining the contract for Scene repository operations.
///
/// It conforms to the `Repository` protocol with `Entity` typealias set to `Scene`.
/// Implementations of this protocol should handle data access for scenes, abstracting
/// the underlying data sources (API, Database).
protocol SceneRepositoryProtocol: Repository where Entity == Scene {
    // MARK: - Read
    
    /// Fetches a list of scenes with support for search, pagination, sorting, and filtering.
    ///
    /// - Parameters:
    ///   - searchText: Text to filter scenes by title, details, etc.
    ///   - page: The page number to fetch (1-indexed).
    ///   - perPage: The number of items per page.
    ///   - sortBy: The criteria to sort by (e.g., date, rating).
    ///   - sortDirection: The sort direction ("ASC" or "DESC").
    ///   - tagIds: Optional list of tag IDs to filter by.
    ///   - forceRefresh: If `true`, bypasses the cache and fetches from the API.
    /// - Returns: A `SceneRepositoryResult` containing the scenes and query metadata.
    func getScenes(
        searchText: String,
        page: Int,
        perPage: Int,
        sortBy: SceneSortType,
        sortDirection: String,
        tagIds: [String]?,
        studioId: String?,
        forceRefresh: Bool
    ) async throws -> SceneRepositoryResult
    
    /// Fetches a single scene by its unique identifier.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the scene.
    ///   - forceRefresh: If `true`, fetches the latest data from the API.
    /// - Returns: The `Scene` object if found, otherwise `nil`.
    func getScene(id: String, forceRefresh: Bool) async throws -> Scene?
    
    /// Fetches all available scenes from the API.
    ///
    /// - Parameter progressHandler: A closure to monitor download progress (current, total).
    /// - Returns: An array of all `Scene` objects.
    func getAllScenes(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Scene]
    
    /// Synchronizes only new or updated scenes incrementally.
    ///
    /// - Parameters:
    ///   - progressHandler: A closure to monitor sync progress.
    ///   - checkForDeletions: If `true`, also checks for and removes deleted scenes.
    /// - Returns: The updated list of scenes.
    func syncNewScenes(progressHandler: (@MainActor (Int, Int) -> Void)?, checkForDeletions: Bool) async throws -> [Scene]
    
    /// Performs a full synchronization, ensuring the local cache exactly matches the server.
    ///
    /// This includes fetching all scenes and removing any that no longer exist on the server.
    ///
    /// - Parameter progressHandler: A closure to monitor sync progress.
    /// - Returns: A tuple containing the updated scenes and the count of removed scenes.
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (scenes: [Scene], removedCount: Int)
    
    /// Retrieves all scenes currently stored in the local cache.
    func getCachedScenes() async throws -> [Scene]
    
    /// Retrieves the total number of scenes stored in the local cache.
    func getCachedSceneCount() async throws -> Int
    
    /// Determines if the local cache is stale and should be refreshed.
    func shouldRefreshCache() async throws -> Bool
    
    /// Retrieves the timestamp of the last successful sync.
    func getLastSyncDate() async throws -> Date?
    
    /// Retrieves a scene by its ID (alias for `getScene(id:forceRefresh:false)`).
    func getById(_ id: String) async throws -> Scene?
    
    /// Fetches all scenes updated since the last local sync from the server and updates the local cache.
    func syncChangedScenes() async throws -> [Scene]
    
    /// Prefetches images for a list of scenes to improve UI performance.
    ///
    /// - Parameters:
    ///   - scenes: The scenes to prefetch images for.
    ///   - count: The number of images to prefetch.
    func prefetchImages(for scenes: [Scene], count: Int) async
    
    /// Prefetches detailed information for a list of scene IDs in the background.
    func prefetchDetails(for sceneIds: [String]) async
    
    // MARK: - Efficient Queries (Home Screen Optimization)
    
    /// Fetches a single scene by ID from the cache.
    /// More efficient than loading all scenes when you only need one.
    func getCachedSceneById(_ id: String) async throws -> Scene?
    
    /// Fetches scenes with a specific tag from the cache.
    /// - Parameters:
    ///   - tagIds: Array of tag IDs to match (scenes with ANY of these tags are returned)
    ///   - limit: Optional limit on number of results
    ///   - sortBy: Sort column (created_at, date, rating100, o_counter, updated_at)
    ///   - ascending: Sort direction
    func getCachedScenesByTagIds(
        _ tagIds: [String],
        limit: Int?,
        sortBy: String?,
        ascending: Bool
    ) async throws -> [Scene]
    
    /// Fetches scenes sorted by a column from the cache.
    /// Used for Home screen categories like "Top Rated", "Recently Added", etc.
    func getCachedScenesSorted(
        by column: String,
        ascending: Bool,
        limit: Int?
    ) async throws -> [Scene]
    
    /// Fetches random scenes from the cache.
    func getCachedRandomScenes(limit: Int) async throws -> [Scene]
    
    // MARK: - Mutations
    
    /// Increments the 'O-Counter' for a specific scene.
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the scene.
    ///   - currentCount: The current count (for optimistic updates/rollback).
    /// - Returns: The updated `Scene` object.
    func incrementOCounter(for sceneId: String, currentCount: Int?) async throws -> Scene
    
    /// Updates the rating for a specific scene.
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the scene.
    ///   - rating: The new rating value (0-100).
    /// - Returns: The updated `Scene` object.
    func updateRating(for sceneId: String, rating: Int) async throws -> Scene
    
    /// Updates the title of a specific scene.
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the scene.
    ///   - title: The new title string.
    /// - Returns: The updated `Scene` object.
    func updateTitle(for sceneId: String, title: String) async throws -> Scene
    
    /// Updates a scene's properties.
    ///
    /// - Parameters:
    ///   - id: The ID of the scene to update.
    ///   - title: The new title, or `nil` to keep current.
    ///   - details: The new details, or `nil` to keep current.
    ///   - performerIds: An array of performer IDs to associate, or `nil` to keep current.
    ///   - tagIds: An array of tag IDs to associate, or `nil` to keep current.
    ///   - coverImage: The new cover image URL, or `nil` to keep current.
    ///   - director: The new director, or `nil` to keep current.
    ///   - code: The new scene code, or `nil` to keep current.
    ///   - url: The new URL, or `nil` to keep current.
    /// - Returns: The updated `Scene` object.
    func updateScene(id: String, title: String?, details: String?, performerIds: [String]?, tagIds: [String]?, coverImage: String?, director: String?, code: String?, url: String?) async throws -> Scene
    
    /// Deletes specific entries from a scene's O-Counter history.
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the scene.
    ///   - times: An array of timestamps (as strings) to delete from the history.
    func deleteOHistory(sceneId: String, times: [String]) async throws
    
    /// Deletes specific entries from a scene's play history.
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the scene.
    ///   - times: An array of timestamps (as strings) to delete from the history.
    func deletePlayHistory(sceneId: String, times: [String]) async throws
    
    /// Deletes a scene from the server and locally.
    ///
    /// - Parameters:
    ///   - id: The ID of the scene to delete.
    ///   - deleteFile: If `true`, deletes the associated file.
    ///   - deleteGenerated: If `true`, deletes generated artifacts (thumbnails, previews).
    /// - Returns: `true` if deletion was successful.
    func deleteScene(id: String, deleteFile: Bool, deleteGenerated: Bool) async throws -> Bool
    
    /// Fetches available 'StashBox' endpoints for metadata scraping.
    func fetchStashBoxes() async throws -> [StashBox]
    
    /// Initiates a scrape operation for a scene using a specific StashBox.
    ///
    /// - Parameters:
    ///   - id: The scene ID.
    ///   - title: An optional title to aid the search.
    ///   - stashBox: The specific StashBox to query.
    /// - Returns: An array of `ScrapedScene` results.
    func scrapeScene(id: String, title: String?, stashBox: StashBox) async throws -> [ScrapedScene]
    
    /// Initiates a fragment-based scrape operation.
    func scrapeSceneByFragment(fragment: SceneFragmentInput, stashBox: StashBox) async throws -> [ScrapedScene]
    
    /// Applies a chosen scrape result to a scene.
    ///
    /// - Parameters:
    ///   - sceneId: The ID of the target scene.
    ///   - result: The scraped data to apply.
    ///   - options: Configuration options for which fields to update.
    /// - Returns: The updated `Scene` object.
    func applyScrapeResult(
        to sceneId: String,
        result: ScrapedScene,
        options: ScrapeApplyOptions
    ) async throws -> Scene
    
    // MARK: - Tagger Configuration
    
    func fetchTaggerConfig() async throws -> TaggerConfig
    func saveTaggerConfig(_ config: TaggerConfig) async throws
    
    /// Saves a scene to the local cache.
    ///
    /// - Parameter scene: The scene to save.
    func saveScene(_ scene: Scene) async throws

    /// Fetches all available streaming endpoints for a scene.
    ///
    /// - Parameter id: The ID of the scene.
    /// - Returns: An array of `SceneStreamEndpoint` objects.
    func getSceneStreams(id: String) async throws -> [SceneStreamEndpoint]
}

/// Options for configuring the application of scraped metadata.
struct ScrapeApplyOptions {
    /// Whether to update the title.
    let useTitle: Bool
    /// Whether to update the description/details.
    let useDetails: Bool
    /// Whether to update the list of performers.
    let usePerformers: Bool
    /// Whether to update the tags.
    let useTags: Bool
    /// Whether to update the cover image.
    let useImage: Bool
    /// Whether to update the studio.
    let useStudio: Bool
    /// Whether to update the director.
    let useDirector: Bool
    /// Whether to update the scene code.
    let useCode: Bool
    /// Whether to update the URL.
    let useUrl: Bool
    /// Custom set of tags to apply, overriding defaults if provided.
    let customTags: [ScrapedTag]?
}

/// Helper struct wrapping the result of a scene repository query.
struct SceneRepositoryResult {
    /// The list of retrieved scenes.
    let scenes: [Scene]
    /// The total count of scenes matching the query (on server or cache).
    let totalCount: Int
    /// Indicates if more pages are available.
    let hasMore: Bool
    /// The source of the data (.api or .cache).
    let source: DataSource
}
