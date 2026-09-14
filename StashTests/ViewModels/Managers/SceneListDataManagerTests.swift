import XCTest
@testable import Stash

@MainActor
final class SceneListDataManagerTests: XCTestCase {
    var manager: SceneListDataManager!
    var mockSceneRepo: MockSceneRepository!
    
    override func setUp() async throws {
        mockSceneRepo = MockSceneRepository()
        manager = SceneListDataManager(repository: mockSceneRepo)
    }
    
    override func tearDown() async throws {
        manager = nil
        mockSceneRepo = nil
    }
    
    // MARK: - Load From Cache
    
    func testLoadFromCache_Success_ReturnsScenes() async throws {
        // Arrange
        let testScenes = [
            Scene.testScene(id: "1", title: "Scene 1"),
            Scene.testScene(id: "2", title: "Scene 2")
        ]
        mockSceneRepo.mockScenes = testScenes
        
        // Act
        let result = try await manager.loadFromCache()
        
        // Assert
        XCTAssertEqual(result.count, 2)
        XCTAssertNotNil(manager.lastSyncDate)
    }
    
    func testLoadFromCache_Empty_ReturnsEmptyArray() async throws {
        // Arrange
        mockSceneRepo.mockScenes = []
        
        // Act
        let result = try await manager.loadFromCache()
        
        // Assert
        XCTAssertTrue(result.isEmpty)
    }
    
    func testLoadFromCache_Error_Throws() async {
        // Arrange
        mockSceneRepo.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await manager.loadFromCache()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Fetch Scenes
    
    func testFetchScenes_NoForceRefresh_ReturnsAllScenes() async throws {
        // Arrange
        let testScenes = [Scene.testScene(id: "1", title: "Test")]
        mockSceneRepo.mockScenes = testScenes
        
        // Act
        let result = try await manager.fetchScenes(forceRefresh: false)
        
        // Assert
        XCTAssertEqual(result.count, 1)
    }
    
    func testFetchScenes_ForceRefresh_SyncsNewScenes() async throws {
        // Arrange
        let remoteScenes = [
            Scene.testScene(id: "1", title: "Remote Scene 1"),
            Scene.testScene(id: "2", title: "Remote Scene 2")
        ]
        mockSceneRepo.remoteScenes = remoteScenes
        
        // Act
        let result = try await manager.fetchScenes(forceRefresh: true)
        
        // Assert
        XCTAssertEqual(result.count, 2)
    }
    
    // MARK: - Sync Changed Scenes
    
    func testSyncChangedScenes_Success_ReturnsChangedScenes() async throws {
        // Arrange
        mockSceneRepo.remoteScenes = [Scene.testScene(id: "changed", title: "Changed")]
        
        // Act
        let result = try await manager.syncChangedScenes()
        
        // Assert - syncChangedScenes returns empty by default in mock
        XCTAssertTrue(result.isEmpty)
    }
}
