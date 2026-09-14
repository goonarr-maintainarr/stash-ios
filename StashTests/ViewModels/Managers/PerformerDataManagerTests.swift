import XCTest
@testable import Stash

@MainActor
final class PerformerDataManagerTests: XCTestCase {
    var manager: PerformerDataManager!
    var mockPerformerRepo: MockPerformerRepository!
    var mockDatabase: StashDatabase!
    var mockSettings: SettingsStore!
    
    override func setUp() async throws {
        mockPerformerRepo = MockPerformerRepository()
        mockDatabase = StashDatabase()
        mockSettings = SettingsStore.shared
        manager = PerformerDataManager(repository: mockPerformerRepo, database: mockDatabase, settings: mockSettings)
    }
    
    override func tearDown() async throws {
        manager = nil
        mockPerformerRepo = nil
        mockDatabase = nil
        mockSettings = nil
    }
    
    // MARK: - Fetch Performer Details
    
    func testFetchPerformerDetails_Success_ReturnsPerformer() async throws {
        // Arrange
        let testPerformer = Performer.testPerformer(id: "123", name: "Test Performer")
        mockPerformerRepo.mockPerformers = [testPerformer]
        
        // Act
        let result = try await manager.fetchPerformerDetails(id: "123")
        
        // Assert
        XCTAssertEqual(result.0.id, "123")
        XCTAssertEqual(result.0.name, "Test Performer")
    }
    
    func testFetchPerformerDetails_NotFound_Throws() async {
        // Arrange
        mockPerformerRepo.mockPerformers = []
        
        // Act & Assert
        do {
            _ = try await manager.fetchPerformerDetails(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    func testFetchPerformerDetails_ForceRefresh_ReturnsFreshPerformer() async throws {
        // Arrange
        let testPerformer = Performer.testPerformer(id: "123", name: "Fresh Performer")
        mockPerformerRepo.mockPerformers = [testPerformer]
        
        // Act
        let result = try await manager.fetchPerformerDetails(id: "123", forceRefresh: true)
        
        // Assert
        XCTAssertEqual(result.0.name, "Fresh Performer")
    }
    
    func testFetchPerformerDetails_CacheHit_ReturnsCachedImmediatelyAndTriggersRefresh() async throws {
        // Arrange
        let cachedPerformer = Performer.testPerformer(id: "123", name: "Cached Performer")
        let freshPerformer = Performer.testPerformer(id: "123", name: "Fresh Performer")
        
        mockPerformerRepo.mockPerformers = [cachedPerformer]
        mockPerformerRepo.remotePerformers = [freshPerformer]
        
        let expectation = XCTestExpectation(description: "Fresh data callback triggered")
        
        // Act
        let result = try await manager.fetchPerformerDetails(id: "123") { freshPerformer, freshScenes in
            XCTAssertEqual(freshPerformer.name, "Fresh Performer")
            expectation.fulfill()
        }
        
        // Assert
        XCTAssertEqual(result.0.name, "Cached Performer")
        
        // Wait for background refresh callback
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
