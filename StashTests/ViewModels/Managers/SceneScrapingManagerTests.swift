import XCTest
@testable import Stash

@MainActor
final class SceneScrapingManagerTests: XCTestCase {
    var manager: SceneScrapingManager!
    var mockSceneRepo: MockSceneRepository!
    
    override func setUp() async throws {
        mockSceneRepo = MockSceneRepository()
        manager = SceneScrapingManager(sceneRepository: mockSceneRepo)
    }
    
    override func tearDown() async throws {
        manager = nil
        mockSceneRepo = nil
    }
    
    // MARK: - Initial State
    
    func testInitialState_IsEmpty() {
        XCTAssertTrue(manager.stashBoxes.isEmpty)
        XCTAssertTrue(manager.scrapedResults.isEmpty)
        XCTAssertFalse(manager.isScraping)
    }
    
    // MARK: - Fetch StashBoxes
    
    func testFetchStashBoxes_Success_PopulatesState() async throws {
        // Arrange
        mockSceneRepo.mockStashBoxes = [
            StashBox(name: "StashDB", endpoint: "https://stashdb.org/graphql", api_key: "test-key")
        ]
        
        // Act
        try await manager.fetchStashBoxes()
        
        // Assert
        XCTAssertEqual(manager.stashBoxes.count, 1)
        XCTAssertEqual(manager.stashBoxes.first?.name, "StashDB")
    }
    
    func testFetchStashBoxes_Error_Throws() async {
        // Arrange
        mockSceneRepo.shouldThrowError = true
        
        // Act & Assert
        do {
            try await manager.fetchStashBoxes()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(manager.stashBoxes.isEmpty)
        }
    }
    
    // MARK: - Scrape Scene
    
    func testScrapeScene_Success_PopulatesResults() async throws {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        let stashBox = StashBox(name: "StashDB", endpoint: "https://stashdb.org/graphql", api_key: "test-key")
        mockSceneRepo.mockScrapedResults = [
            ScrapedScene(title: "Scraped Title", details: "Details", date: "2024-01-01", studio: nil, performers: nil, tags: nil, image: nil, remote_site_id: nil, director: nil, code: nil, url: nil, urls: nil)
        ]
        
        // Act
        try await manager.scrapeScene(using: stashBox, scene: testScene)
        
        // Assert
        XCTAssertEqual(manager.scrapedResults.count, 1)
        XCTAssertEqual(manager.scrapedResults.first?.title, "Scraped Title")
        XCTAssertFalse(manager.isScraping)
    }
    
    func testScrapeScene_Error_ThrowsAndResetsState() async {
        // Arrange
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        let stashBox = StashBox(name: "StashDB", endpoint: "https://stashdb.org/graphql", api_key: "test-key")
        mockSceneRepo.shouldThrowError = true
        
        // Act & Assert
        do {
            try await manager.scrapeScene(using: stashBox, scene: testScene)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(manager.scrapedResults.isEmpty)
            XCTAssertFalse(manager.isScraping)
        }
    }
    
    // MARK: - Reset State
    
    func testResetScrapeState_ClearsResults() async throws {
        // Arrange - populate some results first
        let testScene = Scene.testScene(id: "123", title: "Test Scene")
        let stashBox = StashBox(name: "StashDB", endpoint: "https://stashdb.org/graphql", api_key: "test-key")
        mockSceneRepo.mockScrapedResults = [
            ScrapedScene(title: "Scraped Title", details: nil, date: nil, studio: nil, performers: nil, tags: nil, image: nil, remote_site_id: nil, director: nil, code: nil, url: nil, urls: nil)
        ]
        try await manager.scrapeScene(using: stashBox, scene: testScene)
        XCTAssertEqual(manager.scrapedResults.count, 1)
        
        // Act
        manager.resetScrapeState()
        
        // Assert
        XCTAssertTrue(manager.scrapedResults.isEmpty)
        XCTAssertFalse(manager.isScraping)
    }
    
    // MARK: - Apply Scrape Result
    
    func testApplyScrapeResult_Success_ReturnsUpdatedScene() async throws {
        // Arrange
        let scrapeResult = ScrapedScene(title: "New Title", details: "New Details", date: nil, studio: nil, performers: nil, tags: nil, image: nil, remote_site_id: nil, director: nil, code: nil, url: nil, urls: nil)
        let updatedScene = Scene.testScene(id: "123", title: "New Title")
        mockSceneRepo.mockApplyScrapeResultScene = updatedScene
        
        // Act
        let result = try await manager.applyScrapeResult(
            scrapeResult,
            to: "123",
            useTitle: true,
            useDetails: true,
            usePerformers: false,
            useTags: false,
            useImage: false,
            useStudio: false,
            useDirector: false,
            useCode: false,
            useUrl: false
        )
        
        // Assert
        XCTAssertEqual(result.id, "123")
        XCTAssertEqual(result.title, "New Title")
    }
}
