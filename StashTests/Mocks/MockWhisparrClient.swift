import Foundation
@testable import Stash

class MockWhisparrClient: WhisparrClientProtocol {
    
    var mockScenes: [WhisparrScene] = []
    var mockSearchResults: [WhisparrSearchResult] = []
    var mockLookupResult: WhisparrLookupScene?
    var mockReleases: [WhisparrRelease] = []
    var mockQueue: [WhisparrQueueItem] = []
    var shouldThrowError = false
    
    var mockHistoryResponse: WhisparrHistoryResponse?
    
    func fetchScenes(url: String, apiKey: String, since: Date?) async throws -> [WhisparrScene] {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        return mockScenes
    }
    
    func searchScenes(term: String, url: String, apiKey: String) async throws -> [WhisparrSearchResult] {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        return mockSearchResults
    }
    
    func lookupScene(stashId: String, url: String, apiKey: String) async throws -> WhisparrLookupScene? {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        return mockLookupResult
    }
    
    func fetchReleases(sceneId: Int, url: String, apiKey: String) async throws -> [WhisparrRelease] {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        return mockReleases
    }
    
    func fetchQueue(url: String, apiKey: String) async throws -> [WhisparrQueueItem] {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        return mockQueue
    }
    
    // Stub implementations for other methods
    func fetchScene(id: Int, url: String, apiKey: String) async throws -> WhisparrScene {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        if let scene = mockScenes.first(where: { $0.id == id }) {
            return scene
        }
        throw WhisparrAPIError.notFound
    }
    func fetchCutoffUnmet(url: String, apiKey: String) async throws -> [WhisparrScene] { return [] }
    func addScene(lookupScene: WhisparrLookupScene, url: String, apiKey: String, qualityProfileId: Int, rootFolderPath: String, tags: [Int]) async throws -> WhisparrScene { fatalError("Not implemented") }
    func fetchRootFolders(url: String, apiKey: String) async throws -> [WhisparrRootFolder] { return [] }
    func fetchQualityProfiles(url: String, apiKey: String) async throws -> [WhisparrQualityProfile] { return [] }
    func fetchLogs(url: String, apiKey: String) async throws -> [WhisparrLog] { return [] }
    func executeCommand(command: WhisparrSearchCommand, url: String, apiKey: String) async throws {}
    func downloadRelease(release: WhisparrRelease, sceneId: Int, url: String, apiKey: String) async throws {}
    func deleteSceneFile(fileId: Int, url: String, apiKey: String) async throws {}
    func refreshDownloads(url: String, apiKey: String) async throws {}
    func removeQueueItem(id: Int, url: String, apiKey: String, removeFromClient: Bool, blocklist: Bool) async throws {}
    func refreshScene(sceneId: Int, url: String, apiKey: String) async throws {}
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, url: String, apiKey: String) async throws -> WhisparrScene { fatalError("Not implemented") }
    func updateSceneUsingEditor(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, moveFiles: Bool?, url: String, apiKey: String) async throws -> WhisparrScene { fatalError("Not implemented") }
    func deleteScene(sceneId: Int, deleteFiles: Bool, addImportExclusion: Bool, url: String, apiKey: String) async throws {}
    func fetchCommands(url: String, apiKey: String) async throws -> [WhisparrCommand] { return [] }
    func fetchCommand(id: Int, url: String, apiKey: String) async throws -> WhisparrCommand { fatalError("Not implemented") }
    func fetchHistory(sceneId: Int, url: String, apiKey: String) async throws -> [WhisparrHistoryEvent] { return [] }
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String, url: String, apiKey: String) async throws -> WhisparrHistoryResponse {
        if shouldThrowError { throw WhisparrAPIError.invalidResponse }
        if let response = mockHistoryResponse {
            return response
        }
        return WhisparrHistoryResponse(page: page, pageSize: pageSize, sortKey: sortKey, sortDirection: sortDirection, totalRecords: 0, records: [])
    }
}
