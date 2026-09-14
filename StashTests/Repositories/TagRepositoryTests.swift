import XCTest
@testable import Stash

class TagRepositoryTests: XCTestCase {
    
    var repository: TagRepository!
    var mockApiClient: MockStashClient!
    var mockSettings: MockSettingsStore!
    var mockDatabase: StashDatabase!
    
    override func setUp() {
        super.setUp()
        mockApiClient = MockStashClient()
        mockSettings = MockSettingsStore()
        mockSettings.url = URL(string: "http://localhost:9999")
        mockDatabase = StashDatabase.shared
        
        repository = TagRepository(
            apiClient: mockApiClient,
            database: mockDatabase,
            settings: mockSettings,
            imagePrefetchManager: ImagePrefetchService.shared
        )
    }
    
    func testGetTags_Success() async throws {
        // Arrange
        let mockTag = Tag(id: "1", name: "Test Tag", scene_count: 10)
        let mockResult = TagResultDTO(findTags: TagResultDTO.FindTags(count: 1, tags: [mockTag]))
        mockApiClient.mockTagListResult = mockResult
        
        // Act
        let result = try await repository.getTags(searchText: "Test", page: 1, perPage: 20)
        
        // Assert
        XCTAssertEqual(result.tags.count, 1)
        XCTAssertEqual(result.tags.first?.name, "Test Tag")
        XCTAssertEqual(mockApiClient.fetchCallCount, 1)
    }
}
