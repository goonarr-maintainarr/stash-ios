import Foundation

/// Protocol for services that interact with the Stash API.
///
/// This protocol provides shared functionality for all services that communicate with the Stash server,
/// including automatic error handling, configuration validation, and pagination utilities.
///
/// ## Conforming Types
/// All domain services that make GraphQL requests to Stash should conform to this protocol:
/// - `SceneFetchService`, `SceneMutationService`, `SceneScrapeService`, `SceneSyncService`
/// - `PerformerFetchService`, `PerformerMutationService`, `PerformerScrapeService`, `PerformerSyncService`
/// - `TagFetchService`, `TagSyncService`
/// - `StudioFetchService`, `StudioSyncService`
///
/// ## Usage Example
/// ```swift
/// class MyService: StashService {
///     let apiClient: StashClientProtocol
///     let settings: any SettingsStoreProtocol
///
///     func fetchData() async throws {
///         let url = try settings.validateStashConfiguration()
///         let result: MyResult = try await fetchWithErrorWrapping(
///             query: "query { ... }",
///             url: url
///         )
///     }
/// }
/// ```
protocol StashService {
    /// The API client used to make GraphQL requests.
    var apiClient: StashClientProtocol { get }
    
    /// The settings store containing server URL and API key.
    var settings: any SettingsStoreProtocol { get }
}

extension StashService {
    /// Executes a GraphQL query with automatic error handling and type conversion.
    ///
    /// This method wraps the underlying API client fetch call and converts various error types
    /// into standardized `AppError` instances for consistent error handling across the app.
    ///
    /// - Parameters:
    ///   - query: The GraphQL query string to execute
    ///   - variables: Optional dictionary of GraphQL variables (default: `nil`)
    ///   - url: The Stash server URL to connect to
    /// - Returns: The decoded response of type `T`
    /// - Throws:
    ///   - `AppError.stashAPI` if the server returns a GraphQL error
    ///   - `AppError.network` if there's a network connectivity issue
    ///   - `AppError.unknown` for any other unexpected errors
    ///
    /// ## Example
    /// ```swift
    /// struct SceneResult: Decodable {
    ///     let findScenes: FindScenes
    /// }
    ///
    /// let result: SceneResult = try await fetchWithErrorWrapping(
    ///     query: StashQueries.findScenes,
    ///     url: serverURL
    /// )
    /// ```
    func fetchWithErrorWrapping<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        url: URL
    ) async throws -> T {
        do {
            return try await apiClient.fetch(
                query: query,
                variables: variables,
                url: url,
                apiKey: settings.apiKey
            )
        } catch let error as StashAPIError {
            throw AppError.stashAPI(error)
        } catch let error as URLError {
            throw AppError.network(error.toNetworkError())
        } catch {
            throw AppError.unknown(error)
        }
    }

    /// Fetches remote IDs and timestamps for all items of a given type using automatic pagination.
    ///
    /// This generic method handles the common pattern of fetching lightweight timestamp data
    /// for synchronization operations. It automatically paginates through all results and
    /// builds a dictionary mapping IDs to their last update timestamps.
    ///
    /// - Parameters:
    ///   - queryBuilder: A closure that generates the GraphQL query for a given page and perPage count.
    ///                   Example: `{ StashQueries.findScenes(page: $0, perPage: $1) }`
    ///   - url: The Stash server URL to connect to
    ///   - transform: A closure that extracts the total count and items from the decoded result.
    ///                Returns a tuple of (totalCount, items) where items is an array of (id, updatedAt) tuples.
    ///   - perPage: Number of items to fetch per page (default: 500)
    ///   - progressHandler: Optional closure called on the main actor after each page to report progress.
    ///                      Receives (currentCount, totalCount) as parameters.
    ///
    /// - Returns: A dictionary mapping item IDs to their `updated_at` timestamps (empty string if null)
    /// - Throws: `AppError` if the request fails
    ///
    /// ## Performance Notes
    /// - Fetches only IDs and timestamps, minimizing network overhead
    /// - Processes pages sequentially to avoid overwhelming the server
    /// - Typical usage: 10,000 items = ~20 pages at 500/page = ~10-15 seconds
    ///
    /// ## Example
    /// ```swift
    /// struct TimestampResult: Decodable {
    ///     struct FindScenes: Decodable {
    ///         let count: Int
    ///         let scenes: [SceneTimestamp]
    ///     }
    ///     let findScenes: FindScenes
    /// }
    ///
    /// let timestamps = try await fetchRemoteTimestamps(
    ///     queryBuilder: { StashQueries.findSceneTimestamps(page: $0, perPage: $1) },
    ///     url: serverURL,
    ///     transform: { (result: TimestampResult) in
    ///         (result.findScenes.count, result.findScenes.scenes.map { ($0.id, $0.updated_at) })
    ///     },
    ///     perPage: 250,
    ///     progressHandler: { current, total in
    ///         print("Progress: \(current)/\(total)")
    ///     }
    /// )
    /// ```
    func fetchRemoteTimestamps<T: Decodable>(
        queryBuilder: (Int, Int) -> String,
        url: URL,
        transform: (T) -> (count: Int, items: [(id: String, updatedAt: String?)]),
        perPage: Int = 500,
        progressHandler: (@MainActor (Int, Int) -> Void)? = nil
    ) async throws -> [String: String] {
        var allTimestamps: [String: String] = [:]
        var currentPage = 1
        var hasMore = true
        
        while hasMore {
            let variables: [String: Any] = [
                "page": currentPage,
                "perPage": perPage
            ]
            
            let result: T = try await fetchWithErrorWrapping(
                query: queryBuilder(currentPage, perPage),
                variables: variables,
                url: url
            )
            
            let (totalCount, items) = transform(result)
            for item in items {
                allTimestamps[item.id] = item.updatedAt ?? ""
            }
            
            hasMore = items.count == perPage
            currentPage += 1
            
            if let progressHandler = progressHandler {
                await progressHandler(allTimestamps.count, totalCount)
            }
        }
        
        return allTimestamps
    }
}
