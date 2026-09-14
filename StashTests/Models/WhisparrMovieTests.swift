import XCTest
@testable import Stash

final class WhisparrSceneTests: XCTestCase {
    
    // MARK: - JSON Decoding Tests
    
    func testDecode_MinimalScene_Succeeds() throws {
        let json = """
        {
            "id": 123,
            "title": "Test Scene",
            "code": null,
            "overview": "A test scene",
            "releaseDate": null,
            "year": 2024,
            "runtime": 30,
            "studioTitle": "Test Studio",
            "studioForeignId": null,
            "foreignId": "stash:abc-123",
            "hasFile": true,
            "monitored": true,
            "sizeOnDisk": 1000000000,
            "rootFolderPath": "/movies",
            "path": "/movies/test-scene",
            "qualityProfileId": 1,
            "genres": ["adult"],
            "images": [],
            "credits": [],
            "sceneFile": null,
            "statistics": null,
            "itemType": "scene",
            "added": "2024-01-01T00:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let scene = try decoder.decode(WhisparrScene.self, from: data)
        
        XCTAssertEqual(scene.id, 123)
        XCTAssertEqual(scene.title, "Test Scene")
        XCTAssertEqual(scene.year, 2024)
        XCTAssertEqual(scene.runtime, 30)
        XCTAssertTrue(scene.hasFile)
        XCTAssertTrue(scene.monitored)
        XCTAssertEqual(scene.foreignId, "stash:abc-123")
    }
    
    func testDecode_WithCredits_Succeeds() throws {
        let json = """
        {
            "id": 456,
            "title": "Scene With Credits",
            "code": null,
            "overview": null,
            "releaseDate": null,
            "year": 2024,
            "runtime": 45,
            "studioTitle": null,
            "studioForeignId": null,
            "foreignId": "stash:def-456",
            "hasFile": false,
            "monitored": true,
            "sizeOnDisk": 0,
            "rootFolderPath": null,
            "path": null,
            "qualityProfileId": null,
            "genres": [],
            "images": [
                {"coverType": "screenshot", "url": "/local.jpg", "remoteUrl": "https://example.com/image.jpg"}
            ],
            "credits": [
                {
                    "performer": {
                        "name": "Jane Doe",
                        "gender": "Female",
                        "foreignId": "performer-123",
                        "images": []
                    },
                    "type": "performer",
                    "order": 0
                }
            ],
            "sceneFile": null,
            "statistics": null,
            "itemType": "scene",
            "added": "2024-06-01T12:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let scene = try decoder.decode(WhisparrScene.self, from: data)
        
        XCTAssertEqual(scene.id, 456)
        XCTAssertEqual(scene.credits.count, 1)
        XCTAssertEqual(scene.credits.first?.performer.name, "Jane Doe")
        XCTAssertEqual(scene.images.count, 1)
        XCTAssertEqual(scene.imageUrl, "https://example.com/image.jpg")
    }
    
    // MARK: - Computed Properties Tests
    
    func testPerformerNames_JoinsCredits() {
        let scene = WhisparrScene.testScene(
            credits: [
                WhisparrCredit(
                    performer: WhisparrPerformer(name: "Alice", gender: "Female", foreignId: "p1", images: nil),
                    type: "performer",
                    order: 0
                ),
                WhisparrCredit(
                    performer: WhisparrPerformer(name: "Bob", gender: "Male", foreignId: "p2", images: nil),
                    type: "performer",
                    order: 1
                )
            ]
        )
        
        XCTAssertEqual(scene.performerNames, "Alice, Bob")
    }
    
    func testImageUrl_ReturnsScreenshot() {
        let scene = WhisparrScene.testScene(
            images: [
                WhisparrImage(coverType: "poster", url: nil, remoteUrl: "https://poster.jpg"),
                WhisparrImage(coverType: "screenshot", url: nil, remoteUrl: "https://screenshot.jpg")
            ]
        )
        
        XCTAssertEqual(scene.imageUrl, "https://screenshot.jpg")
    }
    
    func testImageUrl_ReturnsNil_WhenNoScreenshot() {
        let scene = WhisparrScene.testScene(images: [])
        XCTAssertNil(scene.imageUrl)
    }
    
    // MARK: - With Method Tests
    
    func testWith_UpdatesMonitored() {
        let original = WhisparrScene.testScene(monitored: false)
        let updated = original.with(monitored: true)
        
        XCTAssertFalse(original.monitored)
        XCTAssertTrue(updated.monitored)
        XCTAssertEqual(original.id, updated.id)
    }
    
    func testWith_UpdatesQualityProfileId() {
        let original = WhisparrScene.testScene(qualityProfileId: 1)
        let updated = original.with(qualityProfileId: 5)
        
        XCTAssertEqual(original.qualityProfileId, 1)
        XCTAssertEqual(updated.qualityProfileId, 5)
    }
}
