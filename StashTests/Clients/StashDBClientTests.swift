import XCTest
@testable import Stash

final class StashDBClientTests: XCTestCase {
    var client: MockStashDBClient!
    
    override func setUp() async throws {
        client = MockStashDBClient()
    }
    
    override func tearDown() async throws {
        client = nil
    }
    
    // MARK: - Fetch Favorite Performers Tests
    
    func testFetchFavoritePerformers_ReturnsData() async throws {
        // Arrange
        client.mockFavoritePerformers = StashDBPerformersData(count: 2, performers: [])
        
        // Act
        let result = try await client.fetchFavoritePerformers(page: 1, perPage: 20)
        
        // Assert
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(client.fetchFavoritePerformersCallCount, 1)
    }
    
    func testFetchFavoritePerformers_ThrowsOnError() async {
        // Arrange
        client.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await client.fetchFavoritePerformers(page: 1, perPage: 20)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Fetch Favorite Studios Tests
    
    func testFetchFavoriteStudios_ReturnsData() async throws {
        // Arrange
        client.mockFavoriteStudios = StashDBStudiosData(count: 5, studios: [])
        
        // Act
        let result = try await client.fetchFavoriteStudios()
        
        // Assert
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(client.fetchFavoriteStudiosCallCount, 1)
    }
    
    func testFetchFavoriteStudios_ThrowsOnError() async {
        client.shouldThrowError = true
        
        do {
            _ = try await client.fetchFavoriteStudios()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Fetch Scenes By Performers And Studios Tests
    
    func testFetchScenesByPerformersAndStudios_TracksParameters() async throws {
        // Arrange
        let performerIds = ["perf-1", "perf-2"]
        let studioIds = ["studio-1"]
        
        // Act
        _ = try await client.fetchScenesByPerformersAndStudios(
            performerIds: performerIds,
            studioIds: studioIds,
            excludeVR: true,
            excludeCompilations: true
        )
        
        // Assert
        XCTAssertEqual(client.fetchScenesByPerformersAndStudiosCallCount, 1)
        XCTAssertEqual(client.lastPerformerIds, performerIds)
        XCTAssertEqual(client.lastStudioIds, studioIds)
    }
    
    func testFetchScenesByPerformersAndStudios_ThrowsOnError() async {
        client.shouldThrowError = true
        
        do {
            _ = try await client.fetchScenesByPerformersAndStudios(
                performerIds: [],
                studioIds: [],
                excludeVR: false,
                excludeCompilations: false
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Fetch Performer Scenes Tests
    
    func testFetchPerformerScenes_ReturnsData() async throws {
        // Arrange
        client.mockPerformerScenes = StashDBScenesData(count: 10, scenes: [])
        
        // Act
        let result = try await client.fetchPerformerScenes(
            performerId: "perf-1",
            page: 1,
            perPage: 20,
            excludeVR: false,
            excludeCompilations: false
        )
        
        // Assert
        XCTAssertEqual(result.count, 10)
    }
    
    // MARK: - Search Performers Tests
    
    func testSearchPerformers_ReturnsEmpty() async throws {
        // Arrange
        client.mockSearchPerformers = []
        
        // Act
        let results = try await client.searchPerformers(term: "test")
        
        // Assert
        XCTAssertTrue(results.isEmpty)
    }
    
    func testSearchPerformers_ThrowsOnError() async {
        client.shouldThrowError = true
        
        do {
            _ = try await client.searchPerformers(term: "test")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Fetch Performer Details Tests
    
    func testFetchPerformerDetails_ThrowsWhenNotFound() async {
        // Arrange
        client.mockPerformerDetails = nil
        
        // Act & Assert
        do {
            _ = try await client.fetchPerformerDetails(performerId: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is StashDBError)
        }
    }
    
    // MARK: - Fetch Scene Details Tests
    
    func testFetchSceneDetails_ThrowsWhenNotFound() async {
        // Arrange
        client.mockSceneDetails = nil
        
        // Act & Assert
        do {
            _ = try await client.fetchSceneDetails(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is StashDBError)
        }
    }
    
    // MARK: - Fetch Scenes Tests
    
    func testFetchScenes_ReturnsScenes() async throws {
        // Arrange
        client.mockScenes = []
        
        // Act
        let scenes = try await client.fetchScenes(ids: ["id-1", "id-2"])
        
        // Assert
        XCTAssertTrue(scenes.isEmpty)
    }
}
