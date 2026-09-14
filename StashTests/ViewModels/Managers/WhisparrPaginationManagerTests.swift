import XCTest
@testable import Stash

/// Tests for WhisparrPaginationManager
///
/// **Why this is a good test:**
/// - **Memory Efficiency:** Pagination prevents loading thousands of scenes at once - critical for device memory.
/// - **Infinite Scroll UX:** Tests verify loadMore triggers at right threshold so scrolling feels seamless.
/// - **Edge Cases:** Tests empty datasets, single pages, and last page scenarios.
/// - **Reset Behavior:** Ensures filter changes properly reset pagination state.
@MainActor
final class WhisparrPaginationManagerTests: XCTestCase {
    var manager: WhisparrPaginationManager!
    
    override func setUp() async throws {
        manager = WhisparrPaginationManager()
    }
    
    override func tearDown() async throws {
        manager = nil
    }
    
    // MARK: - Initial State
    
    func testInitialState_IsEmpty() {
        XCTAssertTrue(manager.scenes.isEmpty)
        XCTAssertTrue(manager.hasMore)
        XCTAssertEqual(manager.totalCount, 0)
    }
    
    // MARK: - Load First Page
    
    func testLoadFirstPage_LoadsPageSize() {
        // Arrange - 50 scenes, pageSize is 20
        let allScenes = (1...50).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        
        // Act
        manager.loadFirstPage(from: allScenes)
        
        // Assert
        XCTAssertEqual(manager.scenes.count, 20)
        XCTAssertTrue(manager.hasMore)
    }
    
    func testLoadFirstPage_LessThanPageSize_LoadsAll() {
        // Arrange - fewer scenes than page size
        let allScenes = (1...10).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        
        // Act
        manager.loadFirstPage(from: allScenes)
        
        // Assert
        XCTAssertEqual(manager.scenes.count, 10)
        XCTAssertFalse(manager.hasMore)
    }
    
    func testLoadFirstPage_EmptyArray_SetsEmpty() {
        // Act
        manager.loadFirstPage(from: [])
        
        // Assert
        XCTAssertTrue(manager.scenes.isEmpty)
        XCTAssertFalse(manager.hasMore)
    }
    
    // MARK: - Load More
    
    func testLoadMore_NearEnd_LoadsNextPage() {
        // Arrange
        let allScenes = (1...50).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        manager.loadFirstPage(from: allScenes)
        
        // Get scene near the end (within threshold)
        let nearEndScene = manager.scenes[18] // Near end of first page
        
        // Act
        let loaded = manager.loadMore(currentItem: nearEndScene, from: allScenes)
        
        // Assert
        XCTAssertTrue(loaded)
        XCTAssertEqual(manager.scenes.count, 40) // Two pages loaded
    }
    
    func testLoadMore_NotNearEnd_DoesNotLoad() {
        // Arrange
        let allScenes = (1...50).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        manager.loadFirstPage(from: allScenes)
        
        // Get scene at beginning (not near end)
        let earlyScene = manager.scenes[5]
        
        // Act
        let loaded = manager.loadMore(currentItem: earlyScene, from: allScenes)
        
        // Assert
        XCTAssertFalse(loaded)
        XCTAssertEqual(manager.scenes.count, 20) // Still first page
    }
    
    func testLoadMore_AlreadyFullyLoaded_ReturnsFalse() {
        // Arrange - load all scenes
        let allScenes = (1...15).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        manager.loadFirstPage(from: allScenes)
        XCTAssertFalse(manager.hasMore)
        
        // Act
        let loaded = manager.loadMore(currentItem: allScenes.last!, from: allScenes)
        
        // Assert
        XCTAssertFalse(loaded)
    }
    
    func testLoadMore_ItemNotInList_ReturnsFalse() {
        // Arrange
        let allScenes = (1...50).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        manager.loadFirstPage(from: allScenes)
        
        let unknownScene = WhisparrScene.testScene(id: 999, title: "Unknown")
        
        // Act
        let loaded = manager.loadMore(currentItem: unknownScene, from: allScenes)
        
        // Assert
        XCTAssertFalse(loaded)
    }
    
    // MARK: - Reset
    
    func testReset_ClearsState() {
        // Arrange
        let allScenes = (1...50).map { WhisparrScene.testScene(id: $0, title: "Scene \($0)") }
        manager.loadFirstPage(from: allScenes)
        XCTAssertEqual(manager.scenes.count, 20)
        
        // Act
        manager.reset()
        
        // Assert
        XCTAssertTrue(manager.scenes.isEmpty)
        XCTAssertTrue(manager.hasMore)
    }
}
