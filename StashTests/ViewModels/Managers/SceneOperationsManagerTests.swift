import XCTest
@testable import Stash

@MainActor
final class SceneOperationsManagerTests: XCTestCase {
    var manager: SceneOperationsManager!
    var mockSceneRepo: MockSceneRepository!
    var mockWhisparrRepo: MockWhisparrRepository!
    var mockSettings: MockSettingsStore!
    var whisparrIntegration: SceneWhisparrIntegration!
    
    override func setUp() async throws {
        mockSceneRepo = MockSceneRepository()
        mockWhisparrRepo = MockWhisparrRepository()
        mockSettings = MockSettingsStore()
        whisparrIntegration = SceneWhisparrIntegration(
            whisparrRepository: mockWhisparrRepo,
            settings: mockSettings
        )
        manager = SceneOperationsManager(
            sceneRepository: mockSceneRepo,
            settings: mockSettings,
            whisparrIntegration: whisparrIntegration
        )
    }
    
    override func tearDown() async throws {
        manager = nil
        mockSceneRepo = nil
        mockWhisparrRepo = nil
        mockSettings = nil
        whisparrIntegration = nil
    }
    
    // MARK: - Delete Scene
    
    func testDeleteScene_Success_ReturnsTrue() async throws {
        // Act
        let result = try await manager.deleteScene(
            id: "123",
            stashId: nil,
            deleteFile: false,
            deleteGenerated: false
        )
        
        // Assert
        XCTAssertTrue(result)
    }
    
    func testDeleteScene_Error_Throws() async {
        // Arrange
        mockSceneRepo.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await manager.deleteScene(
                id: "123",
                stashId: nil,
                deleteFile: false,
                deleteGenerated: false
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - O-Counter
    
    func testIncrementOCounter_Success_ReturnsUpdatedScene() async throws {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        var updatedScene = testScene
        updatedScene.o_counter = 1
        mockSceneRepo.mockIncrementOCounterScene = updatedScene
        
        // Act
        let result = try await manager.incrementOCounter(for: testScene)
        
        // Assert
        XCTAssertEqual(result.o_counter, 1)
    }
    
    func testIncrementOCounter_Error_Throws() async {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        mockSceneRepo.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await manager.incrementOCounter(for: testScene)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Rating
    
    func testUpdateRating_Success_ReturnsUpdatedScene() async throws {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        var updatedScene = testScene
        updatedScene.rating100 = 80
        mockSceneRepo.mockUpdateRatingScene = updatedScene
        
        // Act
        let result = try await manager.updateRating(for: testScene, rating: 80)
        
        // Assert
        XCTAssertEqual(result.rating100, 80)
    }
    
    // MARK: - Title
    
    func testUpdateTitle_Success_ReturnsUpdatedScene() async throws {
        // Arrange
        var updatedScene = Scene.testScene(id: "123", title: "New Title")
        mockSceneRepo.mockUpdateTitleScene = updatedScene
        
        // Act
        let result = try await manager.updateTitle(for: "123", title: "New Title")
        
        // Assert
        XCTAssertEqual(result.title, "New Title")
    }
}
