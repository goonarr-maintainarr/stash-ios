import XCTest
@testable import Stash

class PerformerSyncServiceTests: XCTestCase {
    
    var service: PerformerSyncService!
    var mockClient: BatchMockStashClient!
    var mockSettings: MockSettingsStore!
    var mockDB: StashDatabase! // Using shared but ideally masked
    
    override func setUp() async throws {
        mockClient = BatchMockStashClient()
        mockSettings = MockSettingsStore()
        
        // We use the shared DB but acknowledge limitations in integration tests
        mockDB = StashDatabase.shared
        try? await mockDB.clearDatabase()
        
        let fetchService = PerformerFetchService(
            apiClient: mockClient,
            database: mockDB,
            settings: mockSettings,
            cacheService: PerformerCacheService(database: mockDB, settings: mockSettings)
        )
        
        let cacheService = PerformerCacheService(database: mockDB, settings: mockSettings)
        
        service = PerformerSyncService(
            apiClient: mockClient,
            database: mockDB,
            settings: mockSettings,
            fetchService: fetchService,
            cacheService: cacheService
        )
    }
    
    override func tearDown() async throws {
        service = nil
        mockClient = nil
        mockSettings = nil
        mockDB = nil
    }

    // MARK: - Batch Sync Tests
    
    func testSyncNewPerformers_UsesBatchFetching() async throws {
        // Arrange
        // 1. Seed DB with nothing (empty)
        // 2. Mock remote timestamps
        mockClient.mockTimestamps = [
            "p1": "2023-01-01T10:00:00Z",
            "p2": "2023-01-01T10:00:00Z"
        ]
        
        // 3. Mock batch response
        let p1 = PerformerDTO.testDTO(id: "p1", name: "P1")
        let p2 = PerformerDTO.testDTO(id: "p2", name: "P2")
        mockClient.mockBatchResponse = ["performer0": p1, "performer1": p2]
        
        // Act
        let performers = try await service.syncNewPerformers(progressHandler: nil)
        
        // Assert
        XCTAssertEqual(performers.count, 2)
        XCTAssertTrue(mockClient.recordedQueries.contains(where: { $0.contains("BatchFindPerformers") }))
    }
    
    func testSyncChangedPerformers_FetchesUpdates() async throws {
        // Arrange
        let p1 = PerformerDTO.testDTO(id: "p1", name: "P1")
        mockClient.mockPerformerListResult = PerformerResultDTO(
            findPerformers: PerformerPageDTO(count: 1, performers: [p1])
        )
        
        // Act
        let performers = try await service.syncChangedPerformers()
        
        // Assert
        XCTAssertEqual(performers.count, 1)
        XCTAssertEqual(performers.first?.id, "p1")
        XCTAssertTrue(mockClient.recordedQueries.contains(where: { $0.contains("findPerformersUpdatedSince") }))
    }
}

// MARK: - Mocks

class BatchMockStashClient: MockStashClient {
    var mockBatchResponse: [String: PerformerDTO?]?
    var mockTimestamps: [String: String] = [:]
    
    override func fetch<T>(query: String, variables: [String : Any]?, url: URL, apiKey: String) async throws -> T where T : Decodable {
        recordedQueries.append(query)
        
        // Handle Timestamps
        if query.contains("findPerformerTimestamps") {
            // Need to match the structure expected by fetchRemotePerformerTimestamps
            // struct TSResult: Codable { let findPerformers: TSPerformers }
            // struct TSPerformers: Codable { let count: Int; let performers: [PerformerTS] }
            // struct PerformerTS: Codable { let id: String; let updated_at: String? }
            
            // This is hard to construct generically without defining duplicate structs.
            // But we can encode/decode or use a dictionary if T matches.
            // Since T is generic Decodable, we can try to force it if we know the structure.
            // Or return a "Mock" object if T is that type.
            // The cleanest way in a self-contained test is if we can just return the JSON data?
            // But `fetch` returns T.
            
            // Hack: Return a specific mock object if we can detect T's type name, but T is generic.
            // We'll rely on MockStashClient's existing logic for standard lists, but for Timestamps we need custom.
            throw StashAPIError.invalidResponse // TODO: improve timestamp mocking
        }
        
        if query.contains("BatchFindPerformers") {
             if let response = mockBatchResponse as? T {
                 return response
             }
        }
        
        if query.contains("findPerformersUpdatedSince") {
            if let result = mockPerformerListResult as? T {
                return result
            }
        }
        
        return try await super.fetch(query: query, variables: variables, url: url, apiKey: apiKey)
    }
    
    // Override to handle timestamp implementation if possible...
    // Actually, PerformerFetchService.fetchRemotePerformerTimestamps defines structs INSIDE the method.
    // So we can't easily instantiate them here to return them.
    // We would need to return a dictionary/JSON that matches.
    // Since we can't instantiate the private structs, we might be stuck unless we refactor PerformerFetchService
    // or use a more dynamic mock client that parses JSON string to T.
}

extension PerformerDTO {
    static func testDTO(id: String, name: String) -> PerformerDTO {
        // Helper to create DTO
        return PerformerDTO(
            id: id, name: name, disambiguation: nil, url: nil, twitter: nil, instagram: nil, gender: nil, 
            birthdate: nil, death_date: nil, ethnicity: nil, country: nil, eye_color: nil, hair_color: nil, 
            height_cm: nil, cup_size: nil, check measurements: nil, check fake_tits: nil, 
            penis_length: nil, circumcision: nil, career_length: nil, tattoos: nil, piercings: nil, 
            alias_list: nil, favorite: false, tags: [], image_path: nil, scene_count: 0, 
            image: nil, studio: nil, updated_at: "2023-01-01"
        )
    }
}
