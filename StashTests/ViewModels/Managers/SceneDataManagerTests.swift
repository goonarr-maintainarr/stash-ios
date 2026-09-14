import XCTest
@testable import Stash

@MainActor
final class SceneDataManagerTests: XCTestCase {
    var manager: SceneDataManager!
    var mockSceneRepo: MockSceneRepository!
    
    override func setUp() async throws {
        mockSceneRepo = MockSceneRepository()
        manager = SceneDataManager(sceneRepository: mockSceneRepo)
    }
    
    override func tearDown() async throws {
        manager = nil
        mockSceneRepo = nil
    }
    
    // MARK: - Fetch Scene Details
    
    func testFetchSceneDetails_Success_ReturnsScene() async throws {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        mockSceneRepo.mockScenes = [testScene]
        
        // Act
        let result = try await manager.fetchSceneDetails(id: "123")
        
        // Assert
        XCTAssertEqual(result.id, "123")
        XCTAssertEqual(result.title, "Test Scene")
    }
    
    func testFetchSceneDetails_NotFound_Throws() async {
        // Arrange
        mockSceneRepo.mockScenes = []
        
        // Act & Assert
        do {
            _ = try await manager.fetchSceneDetails(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    func testFetchSceneDetails_ForceRefresh_ReturnsFreshScene() async throws {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Fresh Scene")
        mockSceneRepo.mockScenes = [testScene]
        
        // Act
        let result = try await manager.fetchSceneDetails(id: "123", forceRefresh: true)
        
        // Assert
        XCTAssertEqual(result.title, "Fresh Scene")
    }
    
    func testFetchSceneDetails_CacheHit_ReturnsCachedImmediatelyAndTriggersRefresh() async throws {
        // Arrange
        let cachedScene = Scene.testScene(id: "123", title: "Cached Scene")
        let freshScene = Scene.testScene(id: "123", title: "Fresh Scene")
        
        mockSceneRepo.mockScenes = [cachedScene]
        mockSceneRepo.remoteScenes = [freshScene]
        
        let expectation = XCTestExpectation(description: "Fresh data callback triggered")
        
        // Act
        let result = try await manager.fetchSceneDetails(id: "123") { fresh in
            XCTAssertEqual(fresh.title, "Fresh Scene")
            expectation.fulfill()
        }
        
        // Assert
        XCTAssertEqual(result.title, "Cached Scene")
        
        // Wait for background refresh callback
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
