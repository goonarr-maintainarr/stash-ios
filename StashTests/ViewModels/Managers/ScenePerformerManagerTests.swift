import XCTest
@testable import Stash

@MainActor
final class ScenePerformerManagerTests: XCTestCase {
    var manager: ScenePerformerManager!
    var mockPerformerRepo: MockPerformerRepository!
    var mockStashDBRepo: MockStashDBRepository!
    var mockSettings: MockSettingsStore!
    
    override func setUp() async throws {
        mockPerformerRepo = MockPerformerRepository()
        mockStashDBRepo = MockStashDBRepository()
        mockSettings = MockSettingsStore()
        manager = ScenePerformerManager(
            performerRepository: mockPerformerRepo,
            stashDBRepository: mockStashDBRepo,
            settings: mockSettings
        )
        
        // Setup default settings
        mockSettings.stashDBUrl = "https://stashdb.org"
        mockSettings.stashDBApiKey = "test-api-key"
    }
    
    override func tearDown() async throws {
        manager = nil
        mockPerformerRepo = nil
        mockStashDBRepo = nil
        mockSettings = nil
    }

class MockStashDBRepository: StashDBRepositoryProtocol {
    var searchResults: [StashDBPerformer] = []
    var shouldThrowError = false
    
    func searchPerformers(term: String, endpoint: String, apiKey: String) async throws -> [StashDBPerformer] {
        if shouldThrowError {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        return searchResults
    }
    
    // Stubs for other protocol methods
    func fetchSceneDetails(id: String) async throws -> StashDBScene { fatalError() }
    func fetchScenes(ids: [String]) async throws -> [StashDBScene] { fatalError() }
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer { fatalError() }
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData { fatalError() }
    func fetchPerformerSceneIds(performerId: String, excludeVR: Bool, excludeCompilations: Bool) async throws -> [String] { fatalError() }
    func fetchPerformerScenesOverview(performerId: String, page: Int, perPage: Int, excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData { fatalError() }
    func fetchFavoriteStudios() async throws -> StashDBStudiosData { fatalError() }
    func fetchScenesByPerformersAndStudiosOverview(performerIds: [String], studioIds: [String], excludeVR: Bool, excludeCompilations: Bool) async throws -> StashDBScenesData { fatalError() }
    func fetchFavoriteScenesFromStashDB(excludeVR: Bool, excludeCompilations: Bool, excludeOwned: Bool) async throws -> [StashDBScene]? { return nil }
    func getCachedFavoriteScenes() async -> [StashDBScene]? { return nil }
    func cacheFavoriteScenes(_ scenes: [StashDBScene]) async {}
}
    
    // MARK: - Fetch Performer Images
    
    func testFetchPerformerImages_Success_ReturnsResult() async throws {
        // Arrange
        mockStashDBRepo.searchResults = [
            StashDBPerformer(
                id: "1",
                name: "Test Performer",
                disambiguation: nil,
                gender: "Female",
                birthDate: nil,
                ethnicity: nil,
                country: nil,
                height: nil,
                hairColor: nil,
                eyeColor: nil,
                measurements: nil,
                breastType: nil,
                careerStartYear: nil,
                careerEndYear: nil,
                tattoos: nil,
                piercings: nil,
                sceneCount: 10,
                isFavorite: false,
                images: nil
            )
        ]
        
        // Act
        let result = try await manager.fetchPerformerImages(name: "Test Performer")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test Performer")
    }
    
    func testFetchPerformerImages_NoResults_ReturnsNil() async throws {
        // Arrange
        mockStashDBRepo.searchResults = []
        
        // Act
        let result = try await manager.fetchPerformerImages(name: "Unknown Performer")
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFetchPerformerImages_Error_Throws() async {
        // Arrange
        mockStashDBRepo.shouldThrowError = true
        
        // Act & Assert
        do {
            _ = try await manager.fetchPerformerImages(name: "Test")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Create Performer
    
    func testCreatePerformer_Success_ReturnsId() async throws {
        // Arrange
        mockPerformerRepo.mockCreatePerformerId = "performer-123"
        
        // Act
        let result = try await manager.createPerformer(
            name: "New Performer",
            image: nil,
            details: nil,
            gender: "Female",
            birth_date: nil,
            ethnicity: nil,
            country: nil,
            eye_color: nil,
            hair_color: nil,
            height: nil,
            measurements: nil,
            breast_type: nil,
            career_start_year: nil,
            career_end_year: nil,
            tattoos: nil,
            piercings: nil
        )
        
        // Assert
        XCTAssertEqual(result, "performer-123")
    }
    
    // MARK: - Validate Scraped Performers
    
    func testValidateScrapedPerformers_ReturnsEmptySet() async {
        // Act
        let result = await manager.validateScrapedPerformers([])
        
        // Assert
        XCTAssertTrue(result.isEmpty)
    }
}
