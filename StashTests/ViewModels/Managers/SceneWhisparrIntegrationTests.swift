import XCTest
@testable import Stash

@MainActor
final class SceneWhisparrIntegrationTests: XCTestCase {
    var manager: SceneWhisparrIntegration!
    var mockWhisparrRepo: MockWhisparrRepository!
    var mockSettings: MockSettingsStore!
    
    override func setUp() async throws {
        mockWhisparrRepo = MockWhisparrRepository()
        mockSettings = MockSettingsStore()
        mockSettings.whisparrUrl = "http://localhost:7878"
        
        manager = SceneWhisparrIntegration(
            whisparrRepository: mockWhisparrRepo,
            settings: mockSettings
        )
    }
    
    override func tearDown() async throws {
        manager = nil
        mockWhisparrRepo = nil
        mockSettings = nil
    }
    
    // MARK: - Initial State
    
    func testInitialState_IsInitial() {
        XCTAssertNil(manager.movieId)
        XCTAssertNil(manager.movie)
        XCTAssertFalse(manager.isResolving)
    }
    
    // MARK: - Resolve Whisparr ID
    
    func testResolveWhisparrId_NoUrl_DoesNothing() async {
        // Arrange
        mockSettings.whisparrUrl = ""
        let testScene = Scene.testScene(id: "123", title: "Test")
        
        // Act
        await manager.resolveWhisparrId(scene: testScene)
        
        // Assert
        XCTAssertNil(manager.movieId)
        XCTAssertFalse(manager.isResolving)
    }
    
    func testResolveWhisparrId_NotFound_SetsNilState() async {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test")
        mockWhisparrRepo.mockLookupResult = nil
        
        // Act
        await manager.resolveWhisparrId(scene: testScene)
        
        // Assert
        XCTAssertNil(manager.movieId)
        XCTAssertNil(manager.movie)
        XCTAssertFalse(manager.isResolving)
    }
    
    // MARK: - Refresh Whisparr Scene
    
    func testRefreshWhisparrScene_NoMatch_DoesNotThrow() async {
        // Arrange
        mockWhisparrRepo.mockLookupResult = nil
        
        // Act & Assert - should not throw
        await manager.refreshWhisparrScene(stashId: "nonexistent")
        XCTAssertTrue(true)
    }
}
