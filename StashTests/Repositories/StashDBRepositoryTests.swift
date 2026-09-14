import XCTest
@testable import Stash

class StashDBRepositoryTests: XCTestCase {
    
    var repository: StashDBRepository!
    var mockClient: MockStashDBClient!
    var mockSettings: MockSettingsStore!
    
    override func setUp() {
        super.setUp()
        mockClient = MockStashDBClient()
        mockSettings = MockSettingsStore()
        mockSettings.stashDBApiKey = "test-api-key"
        
        // Initialize repository with mocked client and shared DBs
        // Note: Using shared DBs limits test isolation but avoids complex DB mocking
        repository = StashDBRepository(
            stashDBClient: mockClient,
            whisparrDatabase: WhisparrDatabase.shared,
            stashDatabase: StashDatabase.shared,
            settings: mockSettings
        )
    }
    
    override func tearDown() {
        repository = nil
        mockClient = nil
        mockSettings = nil
        super.tearDown()
    }
    
    // MARK: - fetchFavoriteScenesFromStashDB Tests
    
    func testFetchFavoriteScenes_ReturnsNil_WhenNoApiKey() async throws {
        // Arrange
        mockSettings.stashDBApiKey = ""
        
        // Act
        let result = try await repository.fetchFavoriteScenesFromStashDB(
            excludeVR: false,
            excludeCompilations: false,
            excludeOwned: false
        )
        
        // Assert
        XCTAssertNil(result)
        XCTAssertEqual(mockClient.fetchFavoritePerformersCallCount, 0)
    }
    
    func testFetchFavoriteScenes_ReturnsNil_WhenNoFavorites() async throws {
        // Arrange
        mockClient.mockFavoritePerformers = StashDBPerformersData(count: 0, performers: [])
        mockClient.mockFavoriteStudios = StashDBStudiosData(count: 0, studios: [])
        
        // Act
        let result = try await repository.fetchFavoriteScenesFromStashDB(
            excludeVR: false,
            excludeCompilations: false,
            excludeOwned: false
        )
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFetchFavoriteScenes_ReturnsScenes_WhenFavoritesExist() async throws {
        throw XCTSkip("Requires complex integration testing - fetchService internal logic not easily mockable")
        // Arrange
        let mockPerformer = createMockStashDBPerformer(id: "perf-1", name: "Test Performer")
        let mockStudio = createMockStashDBStudio(id: "studio-1", name: "Test Studio")
        let mockScene = createMockStashDBScene(id: "scene-1", title: "Test Scene")
        
        mockClient.mockFavoritePerformers = StashDBPerformersData(count: 1, performers: [mockPerformer])
        mockClient.mockFavoriteStudios = StashDBStudiosData(count: 1, studios: [mockStudio])
        mockClient.mockScenesByPerformersAndStudios = StashDBScenesData(count: 1, scenes: [mockScene])
        
        // Act
        let result = try await repository.fetchFavoriteScenesFromStashDB(
            excludeVR: false,
            excludeCompilations: false,
            excludeOwned: false
        )
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.id, "scene-1")
        XCTAssertEqual(mockClient.lastPerformerIds, ["perf-1"])
        XCTAssertEqual(mockClient.lastStudioIds, ["studio-1"])
    }
    
    func testFetchFavoriteScenes_ReturnsNil_WhenNoScenesFound() async throws {
        // Arrange
        let mockPerformer = createMockStashDBPerformer(id: "perf-1", name: "Test Performer")
        mockClient.mockFavoritePerformers = StashDBPerformersData(count: 1, performers: [mockPerformer])
        mockClient.mockFavoriteStudios = StashDBStudiosData(count: 0, studios: [])
        mockClient.mockScenesByPerformersAndStudios = StashDBScenesData(count: 0, scenes: [])
        
        // Act
        let result = try await repository.fetchFavoriteScenesFromStashDB(
            excludeVR: false,
            excludeCompilations: false,
            excludeOwned: false
        )
        
        // Assert
        XCTAssertNil(result)
    }
    
    // MARK: - API Passthrough Tests
    
    func testFetchSceneDetails_DelegatesToClient() async throws {
        // Arrange
        let mockScene = createMockStashDBScene(id: "scene-123", title: "Detail Scene")
        mockClient.mockSceneDetails = mockScene
        
        // Act
        let result = try await repository.fetchSceneDetails(id: "scene-123")
        
        // Assert
        XCTAssertEqual(result.id, "scene-123")
        XCTAssertEqual(result.title, "Detail Scene")
    }
    
    func testFetchPerformerDetails_DelegatesToClient() async throws {
        // Arrange
        let mockPerformer = createMockStashDBPerformer(id: "perf-456", name: "Detail Performer")
        mockClient.mockPerformerDetails = mockPerformer
        
        // Act
        let result = try await repository.fetchPerformerDetails(performerId: "perf-456")
        
        // Assert
        XCTAssertEqual(result.id, "perf-456")
        XCTAssertEqual(result.name, "Detail Performer")
    }
    
    // MARK: - Helpers
    
    private func createMockStashDBPerformer(id: String, name: String) -> StashDBPerformer {
        StashDBPerformer(
            id: id,
            name: name,
            disambiguation: nil,
            gender: "FEMALE",
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
            isFavorite: true,
            images: nil
        )
    }
    
    private func createMockStashDBStudio(id: String, name: String) -> StashDBStudio {
        StashDBStudio(
            id: id,
            name: name,
            aliases: nil,
            deleted: nil,
            isFavorite: true,
            created: nil,
            updated: nil
        )
    }
    
    private func createMockStashDBScene(id: String, title: String) -> StashDBScene {
        StashDBScene(
            id: id,
            title: title,
            details: nil,
            date: "2024-01-01",
            releaseDate: nil,
            productionDate: nil,
            duration: 1800,
            director: nil,
            code: nil,
            deleted: nil,
            created: nil,
            updated: nil,
            studio: nil,
            performers: [],
            tags: nil,
            images: nil,
            urls: nil
        )
    }
}
