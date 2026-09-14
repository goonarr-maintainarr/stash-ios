import XCTest
@testable import Stash

final class WhisparrSearchResultTests: XCTestCase {
    
    // MARK: - JSON Decoding Tests
    
    func testDecode_NestedMovieFormat_Succeeds() throws {
        let json = """
        {
            "foreignId": "stash:abc-123",
            "movie": {
                "title": "Test Scene",
                "overview": "A test scene overview",
                "releaseDate": null,
                "year": 2024,
                "runtime": 30,
                "studioTitle": "Test Studio",
                "images": [],
                "credits": []
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(WhisparrSearchResult.self, from: data)
        
        XCTAssertEqual(result.foreignId, "stash:abc-123")
        XCTAssertEqual(result.title, "Test Scene")
        XCTAssertEqual(result.year, 2024)
        XCTAssertEqual(result.runtime, 30)
        XCTAssertEqual(result.studioTitle, "Test Studio")
    }
    
    func testDecode_FlatFormat_Succeeds() throws {
        let json = """
        {
            "foreignId": "stash:def-456",
            "title": "Flat Format Scene",
            "overview": null,
            "releaseDate": null,
            "year": 2023,
            "runtime": 45,
            "studioTitle": null,
            "images": [],
            "credits": []
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(WhisparrSearchResult.self, from: data)
        
        XCTAssertEqual(result.foreignId, "stash:def-456")
        XCTAssertEqual(result.title, "Flat Format Scene")
        XCTAssertEqual(result.year, 2023)
        XCTAssertNil(result.studioTitle)
    }
    
    func testDecode_WithCredits_Succeeds() throws {
        let json = """
        {
            "foreignId": "stash:cred-789",
            "movie": {
                "title": "Scene With Performers",
                "overview": null,
                "releaseDate": null,
                "year": 2024,
                "runtime": 30,
                "studioTitle": null,
                "images": [],
                "credits": [
                    {
                        "performer": {
                            "name": "Jane Doe",
                            "gender": "Female",
                            "foreignId": "perf-1",
                            "images": []
                        },
                        "type": "performer",
                        "order": 0
                    },
                    {
                        "performer": {
                            "name": "John Doe",
                            "gender": "Male",
                            "foreignId": "perf-2",
                            "images": []
                        },
                        "type": "performer",
                        "order": 1
                    }
                ]
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(WhisparrSearchResult.self, from: data)
        
        XCTAssertEqual(result.credits.count, 2)
        // performerNames should only include female performers
        XCTAssertEqual(result.performerNames, "Jane Doe")
    }
    
    // MARK: - Computed Properties Tests
    
    func testId_ReturnsForeignId() throws {
        let json = """
        {
            "foreignId": "stash:unique-id",
            "movie": {
                "title": "Test",
                "overview": null,
                "releaseDate": null,
                "year": 2024,
                "runtime": 30,
                "studioTitle": null,
                "images": [],
                "credits": []
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(WhisparrSearchResult.self, from: data)
        
        XCTAssertEqual(result.id, "stash:unique-id")
    }
    
    func testImageUrl_ReturnsScreenshot() throws {
        let json = """
        {
            "foreignId": "stash:img-test",
            "movie": {
                "title": "Test",
                "overview": null,
                "releaseDate": null,
                "year": 2024,
                "runtime": 30,
                "studioTitle": null,
                "images": [
                    {"coverType": "poster", "url": null, "remoteUrl": "https://poster.jpg"},
                    {"coverType": "screenshot", "url": null, "remoteUrl": "https://screenshot.jpg"}
                ],
                "credits": []
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(WhisparrSearchResult.self, from: data)
        
        XCTAssertEqual(result.imageUrl, "https://screenshot.jpg")
    }
}
