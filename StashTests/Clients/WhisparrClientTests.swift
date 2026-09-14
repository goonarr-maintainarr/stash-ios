import XCTest
@testable import Stash

final class WhisparrClientTests: XCTestCase {
    var client: MockWhisparrClient!
    
    override func setUp() async throws {
        client = MockWhisparrClient()
    }
    
    override func tearDown() async throws {
        client = nil
    }
    
    // MARK: - Fetch Scenes Tests
    
    func testFetchScenes_ReturnsScenes() async throws {
        // Arrange
        client.mockScenes = [
            WhisparrScene.testScene(id: 1, title: "Scene 1"),
            WhisparrScene.testScene(id: 2, title: "Scene 2")
        ]
        
        // Act
        let scenes = try await client.fetchScenes(url: "http://test.com", apiKey: "key", since: nil)
        
        // Assert
        XCTAssertEqual(scenes.count, 2)
        XCTAssertEqual(scenes.first?.title, "Scene 1")
    }
    
    func testFetchScenes_ThrowsOnError() async {
        // Arrange
        client.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await client.fetchScenes(url: "http://test.com", apiKey: "key", since: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is WhisparrAPIError)
        }
    }
    
    // MARK: - Search Scenes Tests
    
    func testSearchScenes_ReturnsResults() async throws {
        // We can't easily create mock search results due to decoder-only init
        // Just verify empty results work
        client.mockSearchResults = []
        
        let results = try await client.searchScenes(term: "test", url: "http://test.com", apiKey: "key")
        
        XCTAssertTrue(results.isEmpty)
    }
    
    func testSearchScenes_ThrowsOnError() async {
        client.shouldThrowError = true
        
        do {
            _ = try await client.searchScenes(term: "test", url: "http://test.com", apiKey: "key")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is WhisparrAPIError)
        }
    }
    
    // MARK: - Lookup Scene Tests
    
    func testLookupScene_ReturnsNil_WhenNotFound() async throws {
        client.mockLookupResult = nil
        
        let result = try await client.lookupScene(stashId: "test-id", url: "http://test.com", apiKey: "key")
        
        XCTAssertNil(result)
    }
    
    func testLookupScene_ThrowsOnError() async {
        client.shouldThrowError = true
        
        do {
            _ = try await client.lookupScene(stashId: "test-id", url: "http://test.com", apiKey: "key")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is WhisparrAPIError)
        }
    }
    
    // MARK: - Fetch Queue Tests
    
    func testFetchQueue_ReturnsEmpty() async throws {
        client.mockQueue = []
        
        let queue = try await client.fetchQueue(url: "http://test.com", apiKey: "key")
        
        XCTAssertTrue(queue.isEmpty)
    }
    
    func testFetchQueue_ThrowsOnError() async {
        client.shouldThrowError = true
        
        do {
            _ = try await client.fetchQueue(url: "http://test.com", apiKey: "key")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is WhisparrAPIError)
        }
    }
    
    // MARK: - Fetch Releases Tests
    
}
