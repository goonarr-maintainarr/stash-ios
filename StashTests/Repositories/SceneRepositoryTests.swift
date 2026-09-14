import XCTest
@testable import Stash

class SceneRepositoryTests: XCTestCase {
    
    var repository: SceneRepository!
    var mockApiClient: MockStashClient!
    var mockSettings: MockSettingsStore!
    var mockDatabase: StashDatabase! // In a real scenario, use a mock or in-memory DB
    
    override func setUp() {
        super.setUp()
        mockApiClient = MockStashClient()
        mockSettings = MockSettingsStore()
        // We'll use the shared DB for now, but ideally this should be a mock or temporary DB
        // For simple fetch tests that mock the API, this is fine as long as we clear cache or use forceRefresh
        mockDatabase = StashDatabase.shared
        
        repository = SceneRepository(
            apiClient: mockApiClient,
            database: mockDatabase,
            settings: mockSettings,
            imagePrefetchManager: ImagePrefetchService.shared
        )
    }
    
    override func tearDown() {
        repository = nil
        mockApiClient = nil
        mockSettings = nil
        super.tearDown()
    }
    
    func testGetScenes_Success() async throws {
        // Arrange
        let mockScene = SceneDTO(
            id: "1", title: "Test Scene", code: nil, details: "Detail", date: "2023-01-01", 
            created_at: "2023-01-01T00:00:00Z", updated_at: "2023-01-01T00:00:00Z", 
            rating100: 80, o_counter: 0, play_count: 0, play_duration: 0, resume_time: 0, organized: false,
            paths: SceneDTO.ScenePathsDTO(screenshot: nil, preview: nil, stream: nil, sprite: nil, vtt: nil), 
            files: [], performers: [], tags: [], studio: nil, stash_ids: [], scene_markers: [], o_history: [], play_history: []
        )
        let mockResult = SceneResultDTO(findScenes: SceneConnectionDTO(scenes: [mockScene], count: 1))
        mockApiClient.mockSceneListResult = mockResult
        
        // Act
        let result = try await repository.getScenes(searchText: "Test", page: 1, perPage: 20)
        
        // Assert
        XCTAssertEqual(result.scenes.count, 1)
        XCTAssertEqual(result.scenes.first?.title, "Test Scene")
        XCTAssertEqual(mockApiClient.fetchCallCount, 1)
    }
    
    func testGetScenes_NetworkError() async {
        // Arrange
        mockApiClient.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await repository.getScenes(forceRefresh: true)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // Add more tests as needed
}
