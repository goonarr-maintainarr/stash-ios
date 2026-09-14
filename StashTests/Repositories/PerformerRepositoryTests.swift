import XCTest
@testable import Stash

class PerformerRepositoryTests: XCTestCase {
    
    var repository: PerformerRepository!
    var mockApiClient: MockStashClient!
    var mockSettings: MockSettingsStore!
    var mockDatabase: StashDatabase!
    
    override func setUp() {
        super.setUp()
        mockApiClient = MockStashClient()
        mockSettings = MockSettingsStore()
        mockDatabase = StashDatabase.shared
        
        repository = PerformerRepository(
            apiClient: mockApiClient,
            database: mockDatabase,
            settings: mockSettings,
            imagePrefetchManager: ImagePrefetchService.shared
        )
    }
    
    func testGetPerformers_Success() async throws {
        // Arrange
        let mockPerformer = PerformerDTO(
            id: "1", name: "Test Performer", disambiguation: nil, urls: [], gender: "Female", 
            birthdate: "2000-01-01", death_date: nil, ethnicity: "White", country: "USA", 
            eye_color: "Blue", hair_color: "Blonde", height_cm: 170, weight: 60, measurements: "36-24-36", 
            fake_tits: "No", penis_length: nil, circumcised: nil, career_length: "2020-2023", 
            tattoos: nil, piercings: nil, alias_list: [], favorite: false, image_path: nil, 
            details: "Details", scene_count: 5, image_count: 10, gallery_count: 2, group_count: 0, 
            o_counter: 0, rating100: 90, created_at: "2023-01-01", updated_at: "2023-01-01", 
            stash_ids: [], tags: []
        )
        let mockResult = PerformerResultDTO(findPerformers: PerformerConnectionDTO(performers: [mockPerformer], count: 1))
        mockApiClient.mockPerformerListResult = mockResult
        
        // Act
        let result = try await repository.getPerformers(searchText: "Test", page: 1, perPage: 20)
        
        // Assert
        XCTAssertEqual(result.performers.count, 1)
        XCTAssertEqual(result.performers.first?.name, "Test Performer")
        XCTAssertEqual(mockApiClient.fetchCallCount, 1)
    }
}
