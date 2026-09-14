import Foundation
@testable import Stash

/// Mock StashDB client for testing StashDBRepository
class MockStashDBClient: StashDBClientProtocol {
    
    // Mock return values
    var mockFavoritePerformers: StashDBPerformersData = StashDBPerformersData(count: 0, performers: [])
    var mockFavoriteStudios: StashDBStudiosData = StashDBStudiosData(count: 0, studios: [])
    var mockScenesByPerformersAndStudios: StashDBScenesData = StashDBScenesData(count: 0, scenes: [])
    var mockPerformerScenes: StashDBScenesData = StashDBScenesData(count: 0, scenes: [])
    var mockPerformerDetails: StashDBPerformer?
    var mockSearchPerformers: [StashDBPerformer] = []
    var mockPerformerSceneIds: [String] = []
    var mockScenes: [StashDBScene] = []
    var mockSceneDetails: StashDBScene?
    
    // Error simulation
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockStashDBClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    
    // Call tracking
    var fetchFavoritePerformersCallCount = 0
    var fetchFavoriteStudiosCallCount = 0
    var fetchScenesByPerformersAndStudiosCallCount = 0
    var lastPerformerIds: [String] = []
    var lastStudioIds: [String] = []
    
    // MARK: - StashDBClientProtocol
    
    func fetchFavoritePerformers(page: Int, perPage: Int) async throws -> StashDBPerformersData {
        if shouldThrowError { throw errorToThrow }
        fetchFavoritePerformersCallCount += 1
        return mockFavoritePerformers
    }
    
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData {
        if shouldThrowError { throw errorToThrow }
        fetchFavoritePerformersCallCount += 1
        return mockFavoritePerformers
    }
    
    func fetchPerformerScenes(performerId: String, page: Int, perPage: Int, excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData {
        if shouldThrowError { throw errorToThrow }
        return mockPerformerScenes
    }
    
    func fetchPerformerScenesOverview(performerId: String, page: Int, perPage: Int, excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData {
        if shouldThrowError { throw errorToThrow }
        return mockPerformerScenes
    }
    
    func fetchFavoriteStudios() async throws -> StashDBStudiosData {
        if shouldThrowError { throw errorToThrow }
        fetchFavoriteStudiosCallCount += 1
        return mockFavoriteStudios
    }
    
    func fetchScenesByPerformersAndStudios(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData {
        if shouldThrowError { throw errorToThrow }
        fetchScenesByPerformersAndStudiosCallCount += 1
        lastPerformerIds = performerIds
        lastStudioIds = studioIds
        return mockScenesByPerformersAndStudios
    }
    
    func fetchScenesByPerformersAndStudiosOverview(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData {
        if shouldThrowError { throw errorToThrow }
        fetchScenesByPerformersAndStudiosCallCount += 1
        lastPerformerIds = performerIds
        lastStudioIds = studioIds
        return mockScenesByPerformersAndStudios
    }
    
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer {
        if shouldThrowError { throw errorToThrow }
        guard let performer = mockPerformerDetails else {
            throw StashDBError.invalidResponse
        }
        return performer
    }
    
    func searchPerformers(term: String) async throws -> [StashDBPerformer] {
        if shouldThrowError { throw errorToThrow }
        return mockSearchPerformers
    }
    
    func fetchPerformerSceneIds(performerId: String, excludeVR: Bool, excludeCompilations: Bool) async throws -> [String] {
        if shouldThrowError { throw errorToThrow }
        return mockPerformerSceneIds
    }
    
    func fetchScenes(ids: [String]) async throws -> [StashDBScene] {
        if shouldThrowError { throw errorToThrow }
        return mockScenes
    }
    
    func fetchSceneDetails(id: String) async throws -> StashDBScene {
        if shouldThrowError { throw errorToThrow }
        guard let scene = mockSceneDetails else {
            throw StashDBError.invalidResponse
        }
        return scene
    }
}
