import XCTest
@testable import Stash

final class SceneModelTests: XCTestCase {
    
    // MARK: - JSON Decoding Tests
    
    func testDecode_MinimalScene_Succeeds() throws {
        let json = """
        {
            "id": "scene-123",
            "title": "Test Scene",
            "details": "A test scene description",
            "date": "2024-01-15",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z",
            "rating100": 80,
            "o_counter": 5,
            "paths": null,
            "files": null,
            "performers": null,
            "tags": null,
            "studio": null,
            "stash_ids": null,
            "scene_markers": null,
            "o_history": null,
            "play_history": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let scene = try JSONDecoder().decode(Scene.self, from: data)
        
        XCTAssertEqual(scene.id, "scene-123")
        XCTAssertEqual(scene.title, "Test Scene")
        XCTAssertEqual(scene.details, "A test scene description")
        XCTAssertEqual(scene.rating100, 80)
        XCTAssertEqual(scene.o_counter, 5)
    }
    
    func testDecode_WithPaths_Succeeds() throws {
        let json = """
        {
            "id": "scene-456",
            "title": "Scene With Paths",
            "details": null,
            "date": null,
            "created_at": null,
            "updated_at": null,
            "rating100": null,
            "o_counter": null,
            "paths": {
                "screenshot": "/screenshots/scene-456.jpg",
                "preview": "/previews/scene-456.mp4",
                "stream": "/stream/scene-456.mp4"
            },
            "files": null,
            "performers": null,
            "tags": null,
            "studio": null,
            "stash_ids": null,
            "scene_markers": null,
            "o_history": null,
            "play_history": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let scene = try JSONDecoder().decode(Scene.self, from: data)
        
        XCTAssertEqual(scene.paths?.screenshot, "/screenshots/scene-456.jpg")
        XCTAssertEqual(scene.paths?.preview, "/previews/scene-456.mp4")
        XCTAssertEqual(scene.paths?.stream, "/stream/scene-456.mp4")
    }
    
    func testDecode_WithFiles_Succeeds() throws {
        let json = """
        {
            "id": "scene-789",
            "title": "Scene With Files",
            "details": null,
            "date": null,
            "created_at": null,
            "updated_at": null,
            "rating100": null,
            "o_counter": null,
            "paths": null,
            "files": [
                {
                    "size": 1000000000,
                    "duration": 1800.5,
                    "video_codec": "h264",
                    "audio_codec": "aac",
                    "width": 1920,
                    "height": 1080
                }
            ],
            "performers": null,
            "tags": null,
            "studio": null,
            "stash_ids": null,
            "scene_markers": null,
            "o_history": null,
            "play_history": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let scene = try JSONDecoder().decode(Scene.self, from: data)
        
        XCTAssertEqual(scene.files?.count, 1)
        XCTAssertEqual(scene.files?.first?.size, 1000000000)
        XCTAssertEqual(scene.files?.first?.duration, 1800.5)
        XCTAssertEqual(scene.files?.first?.video_codec, "h264")
        XCTAssertEqual(scene.files?.first?.width, 1920)
        XCTAssertEqual(scene.files?.first?.height, 1080)
    }
    
    func testDecode_WithStashIds_Succeeds() throws {
        let json = """
        {
            "id": "scene-stash",
            "title": "Scene With Stash IDs",
            "details": null,
            "date": null,
            "created_at": null,
            "updated_at": null,
            "rating100": null,
            "o_counter": null,
            "paths": null,
            "files": null,
            "performers": null,
            "tags": null,
            "studio": null,
            "stash_ids": [
                {
                    "stash_id": "abc-123-def",
                    "endpoint": "https://stashdb.org/graphql"
                }
            ],
            "scene_markers": null,
            "o_history": null,
            "play_history": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let scene = try JSONDecoder().decode(Scene.self, from: data)
        
        XCTAssertEqual(scene.stash_ids?.count, 1)
        XCTAssertEqual(scene.stash_ids?.first?.stash_id, "abc-123-def")
        XCTAssertEqual(scene.stash_ids?.first?.endpoint, "https://stashdb.org/graphql")
    }
    
    func testDecode_WithHistory_Succeeds() throws {
        let json = """
        {
            "id": "scene-history",
            "title": "Scene With History",
            "details": null,
            "date": null,
            "created_at": null,
            "updated_at": null,
            "rating100": null,
            "o_counter": 3,
            "paths": null,
            "files": null,
            "performers": null,
            "tags": null,
            "studio": null,
            "stash_ids": null,
            "scene_markers": null,
            "o_history": ["2024-01-01T10:00:00Z", "2024-01-02T11:00:00Z", "2024-01-03T12:00:00Z"],
            "play_history": ["2024-01-01T09:00:00Z", "2024-01-02T10:00:00Z"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let scene = try JSONDecoder().decode(Scene.self, from: data)
        
        XCTAssertEqual(scene.o_history?.count, 3)
        XCTAssertEqual(scene.play_history?.count, 2)
    }
    
    // MARK: - Memberwise Initializer Tests
    
    func testInit_AllNilDefaults() {
        let scene = Scene(id: "test-id")
        
        XCTAssertEqual(scene.id, "test-id")
        XCTAssertNil(scene.title)
        XCTAssertNil(scene.details)
        XCTAssertNil(scene.date)
        XCTAssertNil(scene.rating100)
        XCTAssertNil(scene.o_counter)
        XCTAssertNil(scene.performers)
        XCTAssertNil(scene.tags)
    }
    
    func testInit_WithOptionalValues() {
        let scene = Scene(
            id: "test-id",
            title: "Test Title",
            rating100: 90,
            o_counter: 10
        )
        
        XCTAssertEqual(scene.title, "Test Title")
        XCTAssertEqual(scene.rating100, 90)
        XCTAssertEqual(scene.o_counter, 10)
    }
    
    // MARK: - Equatable Tests
    
    func testEquality_SameId_AreEqual() {
        let scene1 = Scene(id: "same-id", title: "Title 1")
        let scene2 = Scene(id: "same-id", title: "Title 1")
        
        XCTAssertEqual(scene1, scene2)
    }
    
    func testEquality_DifferentId_AreNotEqual() {
        let scene1 = Scene(id: "id-1", title: "Same Title")
        let scene2 = Scene(id: "id-2", title: "Same Title")
        
        XCTAssertNotEqual(scene1, scene2)
    }
}
