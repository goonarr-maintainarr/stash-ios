import XCTest
@testable import Stash

final class SceneDTOTests: XCTestCase {
    
    func testSceneDTO_toDomain_MapsAllFields() {
        // Arrange
        let dto = SceneDTO(
            id: "scene-1",
            title: "Test Scene",
            code: "CODE-123",
            director: "Director Name",
            url: "https://example.com",
            details: "Detailed text",
            date: "2023-01-01",
            created_at: "2023-01-01T12:00:00Z",
            updated_at: "2023-01-02T12:00:00Z",
            rating100: 85,
            o_counter: 5,
            play_count: 3,
            play_duration: 3600.0,
            resume_time: 45.5,
            organized: true
        )
        
        // Act
        let domain = dto.toDomain()
        
        // Assert
        XCTAssertEqual(domain.id, "scene-1")
        XCTAssertEqual(domain.title, "Test Scene")
        XCTAssertEqual(domain.code, "CODE-123")
        XCTAssertEqual(domain.director, "Director Name")
        XCTAssertEqual(domain.url, "https://example.com")
        XCTAssertEqual(domain.details, "Detailed text")
        XCTAssertEqual(domain.date, "2023-01-01")
        XCTAssertEqual(domain.created_at, "2023-01-01T12:00:00Z")
        XCTAssertEqual(domain.updated_at, "2023-01-02T12:00:00Z")
        XCTAssertEqual(domain.rating100, 85)
        XCTAssertEqual(domain.o_counter, 5)
        XCTAssertEqual(domain.resume_time, 45.5, "resume_time should be correctly mapped from DTO")
    }
    
    func testSceneDTO_PartialDEcoding_DoesNotFail() throws {
        // Arrange: Minimal JSON from lightweight sync
        let json = """
        {
            "id": "scene-2",
            "title": "Minimal Scene"
        }
        """.data(using: .utf8)!
        
        // Act
        let dto = try JSONDecoder().decode(SceneDTO.self, from: json)
        let domain = dto.toDomain()
        
        // Assert
        XCTAssertEqual(domain.id, "scene-2")
        XCTAssertEqual(domain.title, "Minimal Scene")
        XCTAssertNil(domain.details)
        XCTAssertNil(domain.resume_time)
    }
}
