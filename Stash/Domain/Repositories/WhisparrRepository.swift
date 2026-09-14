import Foundation
import os

/// Repository responsible for managing Whisparr data, including fetching movies, syncing, and updating.
///
/// This repository acts as a coordinator, delegating operations to specialized service classes
/// for better separation of concerns and maintainability.
class WhisparrRepository: WhisparrRepositoryProtocol {
    // Service layer
    private let cacheService: WhisparrCacheService
    private let fetchService: WhisparrFetchService
    private let mutationService: WhisparrMutationService
    private let releaseService: WhisparrReleaseService
    private let commandService: WhisparrCommandService
    private let configService: WhisparrConfigService
    private let syncService: WhisparrSyncService
    
    /// Initializes a new instance of `WhisparrRepository`.
    ///
    /// - Parameters:
    ///   - apiClient: The client used for making API requests.
    ///   - database: The local database for caching Whisparr data.
    ///   - settings: The store for user settings.
    init(
        apiClient: WhisparrClientProtocol? = nil,
        database: WhisparrDatabase? = nil,
        settings: SettingsStore? = nil
    ) {
        let database = database ?? WhisparrDatabase.shared
        let settings = settings ?? SettingsStore.shared
        let apiClient = apiClient ?? WhisparrClient(settings: settings)
        
        // Initialize services
        self.cacheService = WhisparrCacheService(database: database)
        self.fetchService = WhisparrFetchService(apiClient: apiClient, settings: settings)
        self.mutationService = WhisparrMutationService(apiClient: apiClient, cacheService: self.cacheService, settings: settings)
        self.releaseService = WhisparrReleaseService(apiClient: apiClient, settings: settings)
        self.commandService = WhisparrCommandService(apiClient: apiClient, settings: settings)
        self.configService = WhisparrConfigService(apiClient: apiClient, settings: settings)
        self.syncService = WhisparrSyncService(apiClient: apiClient, cacheService: self.cacheService, fetchService: self.fetchService, settings: settings)
    }
    
    // MARK: - Cache Operations
    
    func getCachedScenes() async throws -> [WhisparrScene] {
        return try await cacheService.getCachedScenes()
    }
    
    func getScenes(hasFile: Bool? = nil, monitored: Bool? = nil) async throws -> [WhisparrScene] {
        return try await cacheService.getScenes(hasFile: hasFile, monitored: monitored)
    }
    
    func fetchAllSceneStashIds() async throws -> Set<String> {
        return try await cacheService.fetchAllSceneStashIds()
    }
    
    func shouldRefreshCache() async throws -> Bool {
        return try await cacheService.shouldRefreshCache()
    }
    
    func getLastSyncDate() async throws -> Date? {
        return try await cacheService.getLastSyncDate()
    }
    
    // MARK: - Sync Operations
    
    func syncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene] {
        return try await syncService.syncScenes(progressHandler: progressHandler)
    }
    
    func incrementalSyncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene] {
        return try await syncService.incrementalSyncScenes(progressHandler: progressHandler)
    }
    
    func refreshScenes() async throws {
        try await syncService.refreshScenes()
    }
    
    // MARK: - Fetch Operations
    
    func getRemoteScene(id: Int) async throws -> WhisparrScene? {
        return try await fetchService.getRemoteScene(id: id)
    }
    
    func fetchRemoteScene(id: Int) async throws -> WhisparrScene {
        return try await fetchService.fetchRemoteScene(id: id)
    }
    
    func getCutoffUnmetScenes() async throws -> [WhisparrScene] {
        return try await fetchService.getCutoffUnmetScenes()
    }
    
    func lookupScene(stashId: String) async throws -> WhisparrLookupScene? {
        return try await fetchService.lookupScene(stashId: stashId)
    }
    
    func searchScenes(term: String) async throws -> [WhisparrSearchResult] {
        return try await fetchService.searchScenes(term: term)
    }
    
    func fetchQueue() async throws -> [WhisparrQueueItem] {
        return try await fetchService.fetchQueue()
    }
    
    func fetchLogs() async throws -> [WhisparrLog] {
        return try await fetchService.fetchLogs()
    }
    
    func fetchHistory(sceneId: Int) async throws -> [WhisparrHistoryEvent] {
        return try await fetchService.fetchHistory(sceneId: sceneId)
    }
    
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String) async throws -> WhisparrHistoryResponse {
        return try await fetchService.fetchHistory(page: page, pageSize: pageSize, sortKey: sortKey, sortDirection: sortDirection)
    }
    
    // MARK: - Mutation Operations
    
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene {
        return try await mutationService.updateScene(scene: scene, monitored: monitored, qualityProfileId: qualityProfileId, rootFolderPath: rootFolderPath)
    }
    
    func updateSceneUsingEditor(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, moveFiles: Bool?) async throws -> WhisparrScene {
        return try await mutationService.updateSceneUsingEditor(scene: scene, monitored: monitored, qualityProfileId: qualityProfileId, rootFolderPath: rootFolderPath, moveFiles: moveFiles)
    }
    
    func toggleMonitorStatus(scene: WhisparrScene) async throws -> WhisparrScene {
        return try await mutationService.toggleMonitorStatus(scene: scene)
    }
    
    func deleteScene(scene: WhisparrScene, deleteFiles: Bool, addImportExclusion: Bool) async throws {
        try await mutationService.deleteScene(scene: scene, deleteFiles: deleteFiles, addImportExclusion: addImportExclusion)
    }
    
    func deleteSceneFile(fileId: Int) async throws {
        try await mutationService.deleteSceneFile(fileId: fileId)
    }
    
    func addScene(lookupScene: WhisparrLookupScene, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene {
        return try await mutationService.addScene(lookupScene: lookupScene, qualityProfileId: qualityProfileId, rootFolderPath: rootFolderPath)
    }
    
    func refreshScene(sceneId: Int) async throws {
        try await mutationService.refreshScene(sceneId: sceneId)
    }
    
    func refreshDownloads() async throws {
        try await mutationService.refreshDownloads()
    }
    
    // MARK: - Release Operations
    
    func fetchReleases(sceneId: Int, term: String? = nil) async throws -> [WhisparrRelease] {
        return try await releaseService.fetchReleases(sceneId: sceneId, term: term)
    }
    
    func downloadRelease(release: WhisparrRelease, sceneId: Int) async throws {
        try await releaseService.downloadRelease(release: release, sceneId: sceneId)
    }
    
    func removeQueueItem(id: Int, removeFromClient: Bool, blocklist: Bool) async throws {
        try await releaseService.removeQueueItem(id: id, removeFromClient: removeFromClient, blocklist: blocklist)
    }
    
    // MARK: - Command Operations
    
    func executeCommand(_ command: WhisparrSearchCommand) async throws {
        try await commandService.executeCommand(command)
    }
    
    func performAutomaticSearch(sceneId: Int) async throws {
        try await commandService.performAutomaticSearch(sceneId: sceneId)
    }
    
    // MARK: - Configuration Operations
    
    func fetchQualityProfiles() async throws -> [WhisparrQualityProfile] {
        return try await configService.fetchQualityProfiles()
    }
    
    func fetchRootFolders() async throws -> [WhisparrRootFolder] {
        return try await configService.fetchRootFolders()
    }
}
