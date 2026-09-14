import Foundation
import os

/// Service responsible for managing releases and download queue in Whisparr.
///
/// This service handles fetching releases, downloading, and queue management operations.
class WhisparrReleaseService: @unchecked Sendable {
    private let apiClient: WhisparrClientProtocol
    private let settings: any SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrReleaseService")
    
    init(apiClient: WhisparrClientProtocol, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.settings = settings
    }
    
    

    
    // MARK: - Releases
    
    /// Fetches available releases for a specific scene.
    ///
    /// - Parameter sceneId: The ID of the scene.
    /// - Returns: An array of `WhisparrRelease`.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchReleases(sceneId: Int, term: String? = nil) async throws -> [WhisparrRelease] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let releases = try await apiClient.fetchReleases(
                sceneId: sceneId,
                term: term,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return releases
        } catch {
            throw error
        }
    }
    
    /// Queues a specific release for download.
    ///
    /// - Parameters:
    ///   - release: The release to download.
    ///   - sceneId: The ID of the scene the release belongs to.
    /// - Throws: `RepositoryError` if configuration is invalid or request fails.
    func downloadRelease(release: WhisparrRelease, sceneId: Int) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            try await apiClient.downloadRelease(
                release: release,
                sceneId: sceneId,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
        } catch {
            throw error
        }
    }
    
    // MARK: - Queue Management
    
    /// Removes an item from the queue.
    ///
    /// - Parameters:
    ///   - id: The ID of the queue item to remove.
    ///   - removeFromClient: Whether to remove the download from the download client.
    ///   - blocklist: Whether to add the release to the blocklist.
    /// - Throws: `RepositoryError` if configuration is invalid or request fails.
    func removeQueueItem(id: Int, removeFromClient: Bool, blocklist: Bool) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            try await apiClient.removeQueueItem(
                id: id,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey,
                removeFromClient: removeFromClient,
                blocklist: blocklist
            )
        } catch {
            throw error
        }
    }
}
