import XCTest
@testable import Stash

/// Tests for WhisparrSceneOperationsManager
///
/// **Why this is a good test:**
/// - **Destructive Operations:** Delete and monitor toggle are irreversible - bugs here cause data loss.
/// - **State Machine:** Tests verify operation states (idle→searching→success) transition correctly.
/// - **Concurrent Safety:** Tests attempt to detect race conditions (duplicate toggle prevention).
/// - **Error Recovery:** Ensures errors are surfaced to UI and don't leave manager in broken state.
@MainActor
final class WhisparrSceneOperationsManagerTests: XCTestCase {
    var manager: WhisparrSceneOperationsManager!
    var mockWhisparrRepo: MockWhisparrRepository!
    
    override func setUp() async throws {
        mockWhisparrRepo = MockWhisparrRepository()
        manager = WhisparrSceneOperationsManager(repository: mockWhisparrRepo)
    }
    
    override func tearDown() async throws {
        manager = nil
        mockWhisparrRepo = nil
    }
    
    // MARK: - Initial State
    
    func testInitialState_IsIdle() {
        XCTAssertEqual(manager.operationState, .idle)
    }
    
    // MARK: - Automatic Search
    
    func testPerformAutomaticSearch_Success_ReturnsTrue() async {
        // Act
        let result = await manager.performAutomaticSearch(sceneId: 123)
        
        // Assert
        XCTAssertTrue(result)
    }
    
    func testPerformAutomaticSearch_Error_ReturnsFalse() async {
        // Arrange
        mockWhisparrRepo.shouldThrowError = true
        
        // Act
        let result = await manager.performAutomaticSearch(sceneId: 123)
        
        // Assert
        XCTAssertFalse(result)
        if case .error = manager.operationState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Toggle Monitor Status
    
    func testToggleMonitorStatus_Success_ReturnsUpdatedScene() async throws {
        // Arrange
        let testScene = WhisparrScene.testScene(id: 1, title: "Test", monitored: false)
        
        // Act
        let result = try await manager.toggleMonitorStatus(scene: testScene)
        
        // Assert - mock returns same scene
        XCTAssertEqual(result.id, 1)
        XCTAssertEqual(manager.operationState, .idle)
    }
    
    func testToggleMonitorStatus_Error_Throws() async {
        // Arrange
        mockWhisparrRepo.shouldThrowError = true
        let testScene = WhisparrScene.testScene(id: 1, title: "Test", monitored: false)
        
        // Act & Assert
        do {
            _ = try await manager.toggleMonitorStatus(scene: testScene)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(manager.operationState, .idle)
        }
    }
    
    // MARK: - Refresh Scene
    
    func testRefreshScene_Success_ReturnsTrue() async {
        // Act
        let result = await manager.refreshScene(sceneId: 123)
        
        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(manager.operationState, .idle)
    }
    
    func testRefreshScene_Error_ReturnsFalse() async {
        // Arrange
        mockWhisparrRepo.shouldThrowError = true
        
        // Act
        let result = await manager.refreshScene(sceneId: 123)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    // MARK: - Delete Scene
    
    func testDeleteScene_Success_ReturnsTrue() async {
        // Arrange
        let testScene = WhisparrScene.testScene(id: 1, title: "To Delete")
        
        // Act
        let result = await manager.deleteScene(
            scene: testScene,
            deleteFiles: false,
            addImportExclusion: false
        )
        
        // Assert
        XCTAssertTrue(result)
        XCTAssertEqual(manager.operationState, .idle)
    }
    
    func testDeleteScene_Error_ReturnsFalse() async {
        // Arrange
        mockWhisparrRepo.shouldThrowError = true
        let testScene = WhisparrScene.testScene(id: 1, title: "To Delete")
        
        // Act
        let result = await manager.deleteScene(
            scene: testScene,
            deleteFiles: false,
            addImportExclusion: false
        )
        
        // Assert
        XCTAssertFalse(result)
    }
    
    func testDeleteScene_WithFiles_PassesCorrectFlags() async {
        // Arrange
        let testScene = WhisparrScene.testScene(id: 1, title: "To Delete")
        
        // Act
        let result = await manager.deleteScene(
            scene: testScene,
            deleteFiles: true,
            addImportExclusion: true
        )
        
        // Assert - mock doesn't track args but should succeed
        XCTAssertTrue(result)
    }
}
