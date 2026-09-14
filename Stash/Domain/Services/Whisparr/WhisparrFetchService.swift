import Foundation
import os

/// Service responsible for fetching data from the Whisparr API.
///
/// This service handles all read operations from the remote Whisparr server,
/// including fetching scenes, queue items, logs, and history.
class WhisparrFetchService: @unchecked Sendable {
    private let apiClient: WhisparrClientProtocol
    private let settings: any SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrFetchService")
    
    init(apiClient: WhisparrClientProtocol, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.settings = settings
    }
    
    

    
    // MARK: - Scene Fetch Operations
    
    /// Fetches a specific scene by its ID from the remote API.
    ///
    /// - Parameter id: The ID of the scene to fetch.
    /// - Returns: The `WhisparrScene` if found, or `nil` otherwise.
    /// - Throws: `RepositoryError` if configuration is invalid or request fails.
    func getRemoteScene(id: Int) async throws -> WhisparrScene? {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let scene = try await apiClient.fetchScene(
                id: id,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return scene
        } catch {
            throw error
        }
    }
    
    /// Fetches a specific scene by its ID, throwing an error if not found.
    ///
    /// - Parameter id: The ID of the scene to fetch.
    /// - Returns: The found `WhisparrScene`.
    /// - Throws: `RepositoryError` if not found or other errors occur.
    func fetchRemoteScene(id: Int) async throws -> WhisparrScene {
        return try await getRemoteScene(id: id) ?? {
            throw NSError(domain: "WhisparrRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Movie not found"])
        }()
    }
    
    /// Fetches a list of scenes that have not met their cutoff quality profile.
    ///
    /// - Returns: An array of `WhisparrScene` objects needing attention.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func getCutoffUnmetScenes() async throws -> [WhisparrScene] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        logger.info("🔍 Fetching cutoff unmet scenes from Whisparr...")
        
        do {
            let movies = try await apiClient.fetchCutoffUnmet(
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            logger.info("📦 Found \(movies.count) cutoff unmet scenes")
            
            return movies
        } catch {
            throw error
        }
    }
    
    /// Looks up a scene in Whisparr by its Stash ID.
    ///
    /// - Parameter stashId: The unique Stash ID to lookup.
    /// - Returns: A `WhisparrLookupScene` if found, or `nil` otherwise.
    /// - Throws: `RepositoryError` if configuration is invalid or network error occurs.
    func lookupScene(stashId: String) async throws -> WhisparrLookupScene? {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let scene = try await apiClient.lookupScene(
                stashId: stashId,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            if let scene = scene {
            } else {
            }
            
            return scene
        } catch {
            throw error
        }
    }
    
    /// Searches for scenes using a manual search term.
    ///
    /// - Parameter term: The search term.
    /// - Returns: An array of `WhisparrSearchResult`.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func searchScenes(term: String) async throws -> [WhisparrSearchResult] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let results = try await apiClient.searchScenes(
                term: term,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return results
        } catch {
            throw error
        }
    }
    
    // MARK: - Queue & Logs
    
    /// Fetches the current activity queue from Whisparr.
    ///
    /// - Returns: An array of `WhisparrQueueItem`.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchQueue() async throws -> [WhisparrQueueItem] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let queue = try await apiClient.fetchQueue(
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return queue
        } catch {
            throw error
        }
    }
    
    /// Fetches recent system logs from Whisparr.
    ///
    /// - Returns: An array of `WhisparrLog`.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchLogs() async throws -> [WhisparrLog] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let logs = try await apiClient.fetchLogs(
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return logs
        } catch {
            throw error
        }
    }
    
    // MARK: - History
    
    /// Fetches the history of events for a specific scene.
    ///
    /// - Parameter sceneId: The ID of the scene to retrieve history for.
    /// - Returns: An array of `WhisparrHistoryEvent` objects.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchHistory(sceneId: Int) async throws -> [WhisparrHistoryEvent] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let history = try await apiClient.fetchHistory(
                sceneId: sceneId,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return history
        } catch {
            throw error
        }
    }
    
    /// Fetches paginated history events.
    ///
    /// - Parameters:
    ///   - page: The page number (1-based).
    ///   - pageSize: The number of items per page.
    ///   - sortKey: The key to sort by.
    ///   - sortDirection: The direction to sort (\"asc\" or \"desc\").
    /// - Returns: A `WhisparrHistoryResponse` containing the records and total count.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String) async throws -> WhisparrHistoryResponse {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let response = try await apiClient.fetchHistory(
                page: page,
                pageSize: pageSize,
                sortKey: sortKey,
                sortDirection: sortDirection,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return response
        } catch {
            throw error
        }
    }
}
