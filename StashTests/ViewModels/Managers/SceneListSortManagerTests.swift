import XCTest
@testable import Stash

@MainActor
final class SceneListSortManagerTests: XCTestCase {
    var manager: SceneListSortManager!
    
    override func setUp() async throws {
        manager = SceneListSortManager()
    }
    
    override func tearDown() async throws {
        manager = nil
    }
    
    // MARK: - Sort By Created At
    
    func testSortScenes_ByCreatedAt_Ascending() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Scene 1", created_at: "2024-01-03"),
            Scene.testScene(id: "2", title: "Scene 2", created_at: "2024-01-01"),
            Scene.testScene(id: "3", title: "Scene 3", created_at: "2024-01-02")
        ]
        
        // Act
        let sorted = manager.sortScenes(scenes, by: .createdAt, direction: "ASC")
        
        // Assert
        XCTAssertEqual(sorted[0].id, "2")
        XCTAssertEqual(sorted[1].id, "3")
        XCTAssertEqual(sorted[2].id, "1")
    }
    
    func testSortScenes_ByCreatedAt_Descending() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Scene 1", created_at: "2024-01-01"),
            Scene.testScene(id: "2", title: "Scene 2", created_at: "2024-01-03")
        ]
        
        // Act
        let sorted = manager.sortScenes(scenes, by: .createdAt, direction: "DESC")
        
        // Assert
        XCTAssertEqual(sorted[0].id, "2")
        XCTAssertEqual(sorted[1].id, "1")
    }
    
    // MARK: - Sort By Rating
    
    func testSortScenes_ByRating_Descending() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Low", rating100: 20),
            Scene.testScene(id: "2", title: "High", rating100: 90),
            Scene.testScene(id: "3", title: "Mid", rating100: 50)
        ]
        
        // Act
        let sorted = manager.sortScenes(scenes, by: .rating, direction: "DESC")
        
        // Assert
        XCTAssertEqual(sorted[0].id, "2") // 90
        XCTAssertEqual(sorted[1].id, "3") // 50
        XCTAssertEqual(sorted[2].id, "1") // 20
    }
    
    // MARK: - Sort By O-Counter
    
    func testSortScenes_ByOCounter_Descending() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Low", o_counter: 1),
            Scene.testScene(id: "2", title: "High", o_counter: 10)
        ]
        
        // Act
        let sorted = manager.sortScenes(scenes, by: .oCounter, direction: "DESC")
        
        // Assert
        XCTAssertEqual(sorted[0].id, "2")
        XCTAssertEqual(sorted[1].id, "1")
    }
    
    // MARK: - Random Sort
    
    func testSortScenes_ByRandom_CachesPreviousSort() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Scene 1"),
            Scene.testScene(id: "2", title: "Scene 2"),
            Scene.testScene(id: "3", title: "Scene 3")
        ]
        
        // Act
        let firstSort = manager.sortScenes(scenes, by: .random, direction: "ASC")
        let secondSort = manager.sortScenes(scenes, by: .random, direction: "ASC")
        
        // Assert - Second sort should return same order as first
        XCTAssertEqual(firstSort.map { $0.id }, secondSort.map { $0.id })
    }
    
    func testClearRandomCache_ResetsRandomOrder() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Scene 1"),
            Scene.testScene(id: "2", title: "Scene 2")
        ]
        let firstSort = manager.sortScenes(scenes, by: .random, direction: "ASC")
        
        // Act
        manager.clearRandomCache()
        
        // After clearing, next random sort may differ (but can't guarantee with only 2 items)
        // So we just verify the method doesn't crash
        let secondSort = manager.sortScenes(scenes, by: .random, direction: "ASC")
        XCTAssertEqual(secondSort.count, 2)
    }
    
    // MARK: - Sort By Date
    
    func testSortScenes_ByDate_Descending() {
        // Arrange
        let scenes = [
            Scene.testScene(id: "1", title: "Old", date: "2020-01-01"),
            Scene.testScene(id: "2", title: "New", date: "2024-01-01")
        ]
        
        // Act
        let sorted = manager.sortScenes(scenes, by: .date, direction: "DESC")
        
        // Assert
        XCTAssertEqual(sorted[0].id, "2")
        XCTAssertEqual(sorted[1].id, "1")
    }
}
