import XCTest
@testable import Stash

class WhisparrRepositoryTests: XCTestCase {
    
    var repository: WhisparrRepository!
    var mockApiClient: MockWhisparrClient!
    
    override func setUp() {
        super.setUp()
        mockApiClient = MockWhisparrClient()
        // We use shared Singletons for DB and Settings because they are not easily mockable in current architecture
        // Limits scope of tests to API delegation
        
        // Note: usage of shared DB might cause side effects, but for lookupScene it should be safe if it doesn't write.
        repository = WhisparrRepository(
            apiClient: mockApiClient,
            database: WhisparrDatabase.shared,
            settings: SettingsStore.shared
        )
    }
    
    override func tearDown() {
        repository = nil
        mockApiClient = nil
        super.tearDown()
    }
    
    // MARK: - lookupScene Tests
    
    func testLookupScene_Success() async throws {
        // Arrange
        let mockScene = WhisparrLookupScene(foreignId: "stash:123", title: "Test Movie", overview: nil, status: nil, studioTitle: "Test Studio", id: nil, monitored: nil)
        mockApiClient.mockLookupResult = mockScene
        
        // Act
        let result = try await repository.lookupScene(stashId: "123")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Test Movie")
        XCTAssertEqual(result?.studioTitle, "Test Studio")
    }
    
    func testLookupScene_ReturnsNil_WhenNotFound() async throws {
        // Arrange
        mockApiClient.mockLookupResult = nil
        
        // Act
        let result = try await repository.lookupScene(stashId: "nonexistent")
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testLookupScene_ThrowsError_WhenClientFails() async {
        // Arrange
        mockApiClient.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await repository.lookupScene(stashId: "123")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected - error was thrown
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - searchScenes Tests
    
    func testSearchScenes_ReturnsResults() async throws {
        // Arrange
        // Use minimal mock search results
        mockApiClient.mockSearchResults = []
        
        // Act
        let result = try await repository.searchScenes(term: "test")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result.count, 0) // Empty results expected from mock
    }
    
    func testSearchScenes_ThrowsError_WhenClientFails() async {
        // Arrange
        mockApiClient.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await repository.searchScenes(term: "test")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected - error was thrown
            XCTAssertTrue(true)
        }
    }
}

