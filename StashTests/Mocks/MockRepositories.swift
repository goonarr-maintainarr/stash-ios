import Foundation
@testable import Stash

class MockSceneRepository: SceneRepositoryProtocol {
    typealias Entity = Scene
    
    var mockScenes: [Scene] = [] // Cache
    var remoteScenes: [Scene] = [] // Remote
    var shouldThrowError = false
    var mockStashBoxes: [StashBox] = []
    var mockScrapedResults: [ScrapedScene] = []
    var mockApplyScrapeResultScene: Scene?
    var mockSceneStreams: [SceneStreamEndpoint] = []
    var mockIncrementOCounterScene: Scene?
    var mockUpdateRatingScene: Scene?
    var mockUpdateTitleScene: Scene?
    
    // Spies
    var prefetchImagesCalled = false
    
    // Repository Protocol
    func getAll() async throws -> [Scene] {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return mockScenes
    }
    
    func getById(_ id: String) async throws -> Scene? {
        return mockScenes.first { $0.id == id }
    }
    
    func refresh() async throws {
        // No-op
    }
    
    // SceneRepositoryProtocol Methods
    
    func getScenes(searchText: String, page: Int, perPage: Int, sortBy: SceneSortType, sortDirection: String, tagIds: [String]?, forceRefresh: Bool) async throws -> SceneRepositoryResult {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return SceneRepositoryResult(scenes: mockScenes, totalCount: mockScenes.count, hasMore: false, source: .cache)
    }
    
    func getScene(id: String, forceRefresh: Bool) async throws -> Scene? {
        if forceRefresh {
            return remoteScenes.first { $0.id == id }
        }
        return mockScenes.first { $0.id == id }
    }
    
    func getAllScenes(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Scene] {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return remoteScenes.isEmpty ? mockScenes : remoteScenes
    }
    
    func syncNewScenes(progressHandler: (@MainActor (Int, Int) -> Void)?, checkForDeletions: Bool) async throws -> [Scene] {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return remoteScenes
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (scenes: [Scene], removedCount: Int) {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return (remoteScenes.isEmpty ? mockScenes : remoteScenes, 0)
    }
    
    func getCachedScenes() async throws -> [Scene] {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return mockScenes
    }
    
    func getCachedSceneCount() async throws -> Int {
        if shouldThrowError { throw NSError(domain: "MockSceneRepo", code: 1) }
        return mockScenes.count
    }
    
    func shouldRefreshCache() async throws -> Bool {
        return false
    }
    
    func getLastSyncDate() async throws -> Date? {
        return Date()
    }
    
    func prefetchImages(for scenes: [Scene], count: Int) async {
        prefetchImagesCalled = true
    }
    
    func prefetchDetails(for sceneIds: [String]) async {
        // No-op
    }
    
    func fetchSceneDetails(for ids: [String], url: URL, apiKey: String) async throws -> [Scene] {
        return []
    }
    
    func syncChangedScenes() async throws -> [Scene] { return [] }
    
    func incrementOCounter(for sceneId: String, currentCount: Int?) async throws -> Scene {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        guard let scene = mockIncrementOCounterScene else {
            throw NSError(domain: "Mock", code: -1)
        }
        return scene
    }
    
    func updateRating(for sceneId: String, rating: Int) async throws -> Scene {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        guard let scene = mockUpdateRatingScene else {
            throw NSError(domain: "Mock", code: -1)
        }
        return scene
    }
    
    func updateTitle(for sceneId: String, title: String) async throws -> Scene {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        guard let scene = mockUpdateTitleScene else {
            throw NSError(domain: "Mock", code: -1)
        }
        return scene
    }

    
    func fetchStashBoxes() async throws -> [StashBox] {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockStashBoxes
    }
    
    func scrapeScene(id: String, title: String?, stashBox: StashBox) async throws -> [ScrapedScene] {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockScrapedResults
    }
    
    func applyScrapeResult(to sceneId: String, result: ScrapedScene, options: ScrapeApplyOptions) async throws -> Scene {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        guard let scene = mockApplyScrapeResultScene else {
            throw NSError(domain: "Mock", code: -1)
        }
        return scene
    }
    
    func getSceneStreams(id: String) async throws -> [SceneStreamEndpoint] {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockSceneStreams
    }
    
    func deleteScene(id: String, deleteFile: Bool, deleteGenerated: Bool) async throws -> Bool {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return true
    }
    
    func updateScene(id: String, title: String?, details: String?, performerIds: [String]?, tagIds: [String]?, coverImage: String?, director: String?, code: String?, url: String?) async throws -> Scene {
        throw NSError(domain: "Mock", code: -1)
    }
    
    func saveScene(_ scene: Scene) async throws {
        // No-op
    }
    
    func deleteOHistory(sceneId: String, times: [String]) async throws {
        // No-op
    }
    
    func deletePlayHistory(sceneId: String, times: [String]) async throws {
        // No-op
    }

    func saveSceneDetails(_ scene: Scene) async throws {
        // No-op
    }
    
    func saveScenes(_ scenes: [Scene]) async throws {
        // No-op
    }
    
    func fetchSceneDetails(id: String) async throws -> (scene: Scene, cachedAt: Date?)? {
        if let scene = mockScenes.first(where: { $0.id == id }) {
            return (scene, Date())
        }
        return nil
    }
    
    func fetchAllScenes() async throws -> [Scene] {
        return mockScenes
    }

    func fetchTaggerConfig() async throws -> TaggerConfig {
        throw NSError(domain: "MockSceneRepo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    func saveTaggerConfig(_ config: TaggerConfig) async throws {
        // No-op
    }
    
    func scrapeSceneByFragment(fragment: SceneFragmentInput, stashBox: StashBox) async throws -> [ScrapedScene] {
        return []
    }
}

class MockPerformerRepository: PerformerRepositoryProtocol {
    typealias Entity = Performer
    
    var mockPerformers: [Performer] = [] // Cache
    var remotePerformers: [Performer] = [] // Remote
    var shouldThrowError = false
    var mockSearchResults: [PerformerScrapeResult] = []
    var mockCreatePerformerId: String = "1"
    
    var mockScenes: [Scene] = []
    var remoteScenes: [Scene] = []
    
    // Repository Protocol
    func getAll() async throws -> [Performer] {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return mockPerformers
    }
    
    func getById(_ id: String) async throws -> Performer? {
        return mockPerformers.first { $0.id == id }
    }
    
    func refresh() async throws {
        // No-op
    }

    // PerformerRepositoryProtocol Methods
    
    func getPerformers(searchText: String, page: Int, perPage: Int, sortBy: PerformerSortType, sortDirection: String, forceRefresh: Bool) async throws -> PerformerRepositoryResult {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return PerformerRepositoryResult(performers: mockPerformers, totalCount: mockPerformers.count, hasMore: false, source: .cache)
    }

    func getPerformer(id: String, forceRefresh: Bool = false) async throws -> (performer: Performer, scenes: [Scene])? {
        if forceRefresh {
            guard let performer = remotePerformers.first(where: { $0.id == id }) ?? mockPerformers.first(where: { $0.id == id }) else { return nil }
            return (performer, remoteScenes.isEmpty ? mockScenes : remoteScenes)
        } else {
            guard let performer = mockPerformers.first(where: { $0.id == id }) else { return nil }
            return (performer, mockScenes)
        }
    }

    func getAllPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer] {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return remotePerformers.isEmpty ? mockPerformers : remotePerformers
    }

    func syncNewPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer] {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return remotePerformers
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (performers: [Performer], removedCount: Int) {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return (remotePerformers.isEmpty ? mockPerformers : remotePerformers, 0)
    }

    func getCachedPerformers() async throws -> [Performer] {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return mockPerformers
    }
    
    func getCachedPerformerCount() async throws -> Int {
        if shouldThrowError { throw NSError(domain: "MockPerformerRepo", code: 1) }
        return mockPerformers.count
    }

    func shouldRefreshCache() async throws -> Bool {
        return false
    }

    func getLastSyncDate() async throws -> Date? {
        return Date()
    }

    func prefetchImages(for performers: [Performer], count: Int) async {
        // No-op
    }
    
    func searchPerformer(term: String) async throws -> [PerformerScrapeResult] {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockSearchResults
    }
    
    func createPerformer(input: PerformerCreateInput) async throws -> String {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockCreatePerformerId
    }
    
    func getPerformerScenes(performerId: String) async throws -> [Scene] {
        return []
    }
    
    func deletePerformer(id: String) async throws -> Bool {
        return true
    }
    
    func updatePerformer(input: PerformerUpdateInput) async throws -> String {
        return input.id
    }
    
    func fetchStashBoxConfiguration() async throws -> StashBoxConfiguration {
        throw NSError(domain: "Mock", code: -1)
    }
}

class MockTagRepository: TagRepositoryProtocol {
    typealias Entity = Tag
    
    var mockTags: [Tag] = [] // Cache
    var remoteTags: [Tag] = [] // Remote
    
    // Repository Protocol
    func getAll() async throws -> [Tag] { return mockTags }
    func getById(_ id: String) async throws -> Tag? { return mockTags.first { $0.id == id } }
    func refresh() async throws {}
    
    // TagRepositoryProtocol Methods
    
    func getTags(searchText: String, page: Int, perPage: Int, forceRefresh: Bool) async throws -> TagRepositoryResult {
        return TagRepositoryResult(tags: mockTags, totalCount: mockTags.count, hasMore: false, source: .cache)
    }
    
    func getTag(id: String) async throws -> Tag? {
        return mockTags.first { $0.id == id }
    }
    
    func getAllTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag] {
        return remoteTags.isEmpty ? mockTags : remoteTags
    }
    
    func syncNewTags(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Tag] {
        return remoteTags
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (tags: [Tag], removedCount: Int) {
        return (remoteTags.isEmpty ? mockTags : remoteTags, 0)
    }
    
    func getCachedTags() async throws -> [Tag] {
        return mockTags
    }
    
    func getCachedTagCount() async throws -> Int {
        return mockTags.count
    }
    
    func shouldRefreshCache() async throws -> Bool {
        return false
    }
    
    func getLastSyncDate() async throws -> Date? {
        return Date()
    }
}

// MARK: - MockWhisparrRepository

class MockWhisparrRepository: WhisparrRepositoryProtocol {
    var mockScenes: [WhisparrScene] = []
    var mockLookupResult: WhisparrLookupScene?
    var shouldThrowError = false
    
    func getCachedScenes() async throws -> [WhisparrScene] {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockScenes
    }
    
    func getScenes(hasFile: Bool?, monitored: Bool?) async throws -> [WhisparrScene] { return mockScenes }
    func syncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene] { return mockScenes }
    func incrementalSyncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene] { return mockScenes }
    func shouldRefreshCache() async throws -> Bool { return false }
    func getLastSyncDate() async throws -> Date? { return Date() }
    func getScene(id: Int) async throws -> WhisparrScene? { return mockScenes.first { $0.id == id } }
    func getCutoffUnmet() async throws -> [WhisparrScene] { return [] }
    func fetchHistory(sceneId: Int) async throws -> [WhisparrHistoryEvent] { return [] }
    func deleteSceneFile(fileId: Int) async throws {}
    func fetchQualityProfiles() async throws -> [WhisparrQualityProfile] { return [] }
    func fetchRootFolders() async throws -> [WhisparrRootFolder] { return [] }
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene { return scene }
    func fetchAllSceneStashIds() async throws -> Set<String> { return [] }
    func lookupScene(stashId: String) async throws -> WhisparrLookupScene? { return mockLookupResult }
    func fetchScene(id: Int) async throws -> WhisparrScene { return mockScenes.first { $0.id == id } ?? WhisparrScene.testScene(id: id, title: "Mock") }
    func addScene(lookupScene: WhisparrLookupScene, qualityProfileId: Int, rootFolderPath: String) async throws -> WhisparrScene { return WhisparrScene.testScene(id: lookupScene.id ?? 0, title: lookupScene.title) }
    func fetchQueue() async throws -> [WhisparrQueueItem] { return [] }
    func fetchLogs() async throws -> [WhisparrLog] { return [] }
    func removeQueueItem(id: Int, removeFromClient: Bool, blocklist: Bool) async throws {}
    func fetchReleases(sceneId: Int) async throws -> [WhisparrRelease] { return [] }
    func downloadRelease(release: WhisparrRelease, sceneId: Int) async throws {}
    func executeCommand(_ command: WhisparrSearchCommand) async throws {}
    func searchScenes(term: String) async throws -> [WhisparrSearchResult] { return [] }
    func refreshDownloads() async throws {}
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String) async throws -> WhisparrHistoryResponse { return WhisparrHistoryResponse(page: 1, pageSize: pageSize, sortKey: sortKey, sortDirection: sortDirection, totalRecords: 0, records: []) }
    func refreshScenes() async throws {}
    func getRemoteScene(id: Int) async throws -> WhisparrScene? { return mockScenes.first { $0.id == id } }
    func getCutoffUnmetScenes() async throws -> [WhisparrScene] { return [] }
    func fetchRemoteScene(id: Int) async throws -> WhisparrScene { return mockScenes.first { $0.id == id } ?? WhisparrScene.testScene(id: id, title: "Mock") }
    
    // These 4 methods need error handling for tests
    func deleteScene(scene: WhisparrScene, deleteFiles: Bool, addImportExclusion: Bool) async throws {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
    }
    func toggleMonitorStatus(scene: WhisparrScene) async throws -> WhisparrScene {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return scene
    }
    func performAutomaticSearch(sceneId: Int) async throws {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
    }
    func refreshScene(sceneId: Int) async throws {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
    }
}

// MARK: - MockStashDBRepository

class MockStashDBRepository: StashDBRepositoryProtocol {
    var mockFavoriteScenes: [StashDBScene]?
    var mockPerformerDetails: StashDBPerformer?
    var mockSceneDetails: StashDBScene?
    var shouldThrowError = false
    
    func fetchFavoriteScenesFromStashDB(excludeVR: Bool, excludeCompilations: Bool, excludeOwned: Bool) async throws -> [StashDBScene]? {
        if shouldThrowError { throw NSError(domain: "Mock", code: 1) }
        return mockFavoriteScenes
    }
    
    func getCachedFavoriteScenes() async -> [StashDBScene]? { return mockFavoriteScenes }
    func cacheFavoriteScenes(_ scenes: [StashDBScene]) async {}
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer { return mockPerformerDetails ?? StashDBPerformer(id: performerId, name: "Mock", disambiguation: nil, gender: nil, birthDate: nil, ethnicity: nil, country: nil, height: nil, hairColor: nil, eyeColor: nil, measurements: nil, breastType: nil, careerStartYear: nil, careerEndYear: nil, tattoos: nil, piercings: nil, sceneCount: 0, isFavorite: false, images: nil) }
    func fetchSceneDetails(id: String) async throws -> StashDBScene { return mockSceneDetails ?? StashDBScene(id: id, title: "Mock", details: nil, date: nil, releaseDate: nil, productionDate: nil, duration: nil, director: nil, code: nil, deleted: nil, created: nil, updated: nil, studio: nil, performers: [], tags: nil, images: nil, urls: nil) }
    func fetchScenes(ids: [String]) async throws -> [StashDBScene] { return ids.map { id in StashDBScene(id: id, title: "Mock", details: nil, date: nil, releaseDate: nil, productionDate: nil, duration: nil, director: nil, code: nil, deleted: nil, created: nil, updated: nil, studio: nil, performers: [], tags: nil, images: nil, urls: nil) } }
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData { return StashDBPerformersData(count: 0, performers: []) }
    func fetchFavoriteStudios() async throws -> StashDBStudiosData { return StashDBStudiosData(count: 0, studios: []) }
    func fetchScenesByPerformersAndStudiosOverview(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData { return StashDBScenesData(count: 0, scenes: []) }
    func fetchPerformerSceneIds(performerId: String, excludeVR: Bool, excludeCompilations: Bool) async throws -> [String] { return [] }
    func fetchPerformerScenesOverview(performerId: String, page: Int, perPage: Int, excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData { return StashDBScenesData(count: 0, scenes: []) }
    func searchPerformers(term: String, endpoint: String, apiKey: String) async throws -> [StashDBPerformer] { return [] }
}

// MARK: - Mock Stats Repository

class MockStatsRepository: StatsRepositoryProtocol {
    var mockStats: Stats?
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockStatsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    
    func fetchStats() async throws -> Stats {
        if shouldThrowError { throw errorToThrow }
        guard let stats = mockStats else {
            throw NSError(domain: "MockStatsRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock stats configured"])
        }
        return stats
    }
}

// MARK: - Mock Settings Repository

class MockSettingsRepository: SettingsRepositoryProtocol, @unchecked Sendable {
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockSettingsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Settings error"])
    var testStashConnectionCalled = false
    var testStashDBCalled = false
    var triggerScanCalled = false
    var triggerGenerationCalled = false
    var mockTaggerConfig: TaggerConfig = TaggerConfig()
    
    func testStashConnection(url: URL, apiKey: String) async throws {
        testStashConnectionCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func testStashDBConnection(apiKey: String) async throws {
        testStashDBCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func triggerScan(options: ScanOptions) async throws {
        triggerScanCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func triggerGeneration(options: GenerationOptions) async throws {
        triggerGenerationCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func fetchTaggerConfig() async throws -> TaggerConfig {
        if shouldThrowError { throw errorToThrow }
        return mockTaggerConfig
    }
    
    func saveTaggerConfig(_ config: TaggerConfig) async throws {
        if shouldThrowError { throw errorToThrow }
        mockTaggerConfig = config
    }
}
