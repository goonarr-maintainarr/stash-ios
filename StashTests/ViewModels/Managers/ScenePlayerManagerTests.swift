import XCTest
@testable import Stash

@MainActor
final class ScenePlayerManagerTests: XCTestCase {
    var manager: ScenePlayerManager!
    var mockSceneRepo: MockSceneRepository!
    var mockSettings: MockSettingsStore!
    
    override func setUp() async throws {
        mockSceneRepo = MockSceneRepository()
        mockSettings = MockSettingsStore()
        // Set a valid URL for the mock settings
        mockSettings.url = URL(string: "http://localhost:9999")
        
        manager = ScenePlayerManager(
            sceneRepository: mockSceneRepo,
            settings: mockSettings
        )
    }
    
    override func tearDown() async throws {
        manager.cleanup()
        manager = nil
        mockSceneRepo = nil
        mockSettings = nil
    }
    
    // MARK: - Initial State
    
    func testInitialState_IsInitial() {
        XCTAssertNil(manager.player)
        XCTAssertFalse(manager.isLoaded)
        XCTAssertTrue(manager.availableStreams.isEmpty)
        XCTAssertNil(manager.selectedStream)
        XCTAssertFalse(manager.isLoadingStreams)
    }
    
    // MARK: - Setup Player
    
    func testSetupPlayer_ValidScene_CreatesPlayer() {
        // Arrange
        let paths = Scene.ScenePaths(
            screenshot: nil,
            preview: nil,
            stream: "/scene/123/stream",
            sprite: nil,
            vtt: nil
        )
        let testScene = Scene(
            id: "123",
            title: "Test Scene",
            paths: paths
        )
        
        // Act
        manager.setupPlayer(for: testScene)
        
        // Assert
        XCTAssertNotNil(manager.player)
        XCTAssertFalse(manager.isLoaded)
    }
    
    func testSetupPlayer_NoStreamPath_DoesNothing() {
        // Arrange - Scene without paths
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        
        // Act
        manager.setupPlayer(for: testScene)
        
        // Assert
        XCTAssertNil(manager.player)
    }
    
    // MARK: - Fetch Available Streams
    
    func testFetchAvailableStreams_Success_PopulatesStreams() async {
        // Arrange
        let mockStreams = [
            SceneStreamEndpoint(url: "/stream/direct", label: "Direct Stream", mimeType: "video/mp4"),
            SceneStreamEndpoint(url: "/stream/webm", label: "WebM", mimeType: "video/webm")
        ]
        mockSceneRepo.mockSceneStreams = mockStreams
        
        // Act
        await manager.fetchAvailableStreams(sceneId: "123", currentStreamPath: nil)
        
        // Assert
        XCTAssertEqual(manager.availableStreams.count, 2)
        XCTAssertFalse(manager.isLoadingStreams)
    }
    
    func testFetchAvailableStreams_Error_RemainsEmpty() async {
        // Arrange
        mockSceneRepo.shouldThrowError = true
        
        // Act
        await manager.fetchAvailableStreams(sceneId: "123", currentStreamPath: nil)
        
        // Assert
        XCTAssertTrue(manager.availableStreams.isEmpty)
        XCTAssertFalse(manager.isLoadingStreams)
    }
    
    // MARK: - Cleanup
    
    func testCleanup_ReleasesPlayer() {
        // Arrange
        let paths = Scene.ScenePaths(
            screenshot: nil,
            preview: nil,
            stream: "/scene/123/stream",
            sprite: nil,
            vtt: nil
        )
        let testScene = Scene(
            id: "123",
            title: "Test Scene",
            paths: paths
        )
        manager.setupPlayer(for: testScene)
        XCTAssertNotNil(manager.player)
        
        // Act
        manager.cleanup()
        
        // Assert
        XCTAssertNil(manager.player)
        XCTAssertFalse(manager.isLoaded)
    }
    
    // MARK: - Set Player Loaded
    
    func testSetPlayerLoaded_UpdatesState() {
        // Act
        manager.setPlayerLoaded(true)
        
        // Assert
        XCTAssertTrue(manager.isLoaded)
        
        // Act again
        manager.setPlayerLoaded(false)
        
        // Assert
        XCTAssertFalse(manager.isLoaded)
    }
}
