import Foundation
import Combine

protocol WhisparrRepositoryProtocol: Sendable {
    /// Get scenes from cache
    func getCachedScenes() async throws -> [WhisparrScene]
    
    /// Get scenes with optional filtering
    func getScenes(hasFile: Bool?, monitored: Bool?) async throws -> [WhisparrScene]
    
    /// Sync scenes from Whisparr API
    func syncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene]
    
    /// Check if cache needs refresh
    func shouldRefreshCache() async throws -> Bool
    
    /// Get last sync date
    func getLastSyncDate() async throws -> Date?
    
    /// Refresh cache (sync scenes)
    func refreshScenes() async throws
    
    /// Get remote scene by ID (Optional)
    func getRemoteScene(id: Int) async throws -> WhisparrScene?
    
    /// Get cutoff unmet scenes
    func getCutoffUnmetScenes() async throws -> [WhisparrScene]
    
    /// Fetch history for a scene
    func fetchHistory(sceneId: Int) async throws -> [WhisparrHistoryEvent]
    
    /// Delete a scene file
    func deleteSceneFile(fileId: Int) async throws
    
    /// Fetch quality profiles
    func fetchQualityProfiles() async throws -> [WhisparrQualityProfile]
    
    /// Fetch root folders
    func fetchRootFolders() async throws -> [WhisparrRootFolder]
    
    /// Update scene
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene
    
    /// Fetch all scene Stash IDs
    func fetchAllSceneStashIds() async throws -> Set<String>
    
    // MARK: - New methods for SceneDetailViewModel
    
    /// Lookup a scene in Whisparr by Stash ID
    func lookupScene(stashId: String) async throws -> WhisparrLookupScene?
    
    /// Refresh a specific scene in Whisparr (trigger scan/refresh)
    func refreshScene(sceneId: Int) async throws
    
    /// Fetch a single scene from API (bypass cache/lookups) - Throwing
    func fetchRemoteScene(id: Int) async throws -> WhisparrScene
    
    /// Add a scene to Whisparr
    func addScene(lookupScene: WhisparrLookupScene, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene
    
    // MARK: - Queue & Logs
    
    /// Fetches the current activity queue.
    func fetchQueue() async throws -> [WhisparrQueueItem]
    
    /// Fetches recent log entries.
    func fetchLogs() async throws -> [WhisparrLog]
    
    /// Removes an item from the queue, optionally from the download client and blocklisting.
    func removeQueueItem(id: Int, removeFromClient: Bool, blocklist: Bool) async throws
    
    // MARK: - Releases & Downloads
    
    /// Fetches releases for a specific scene.
    func fetchReleases(sceneId: Int, term: String?) async throws -> [WhisparrRelease]
    
    /// Queues a release for download.
    func downloadRelease(release: WhisparrRelease, sceneId: Int) async throws
    
    // MARK: - Commands & Search
    
    /// Executes a command on the Whisparr server.
    func executeCommand(_ command: WhisparrSearchCommand) async throws
    
    /// Searches for scenes (manual search).
    func searchScenes(term: String) async throws -> [WhisparrSearchResult]
    
    /// Triggers a refresh of monitored downloads.
    func refreshDownloads() async throws
    
    // MARK: - History
    
    /// Fetches paginated history.
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String) async throws -> WhisparrHistoryResponse
    
    // MARK: - Actions (Consolidated)
    
    /// Delete a scene (optimistic)
    func deleteScene(scene: WhisparrScene, deleteFiles: Bool, addImportExclusion: Bool) async throws
    
    /// Toggle monitor status
    func toggleMonitorStatus(scene: WhisparrScene) async throws -> WhisparrScene
    
    /// Trigger automatic search
    func performAutomaticSearch(sceneId: Int) async throws
}
