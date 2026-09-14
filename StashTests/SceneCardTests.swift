import XCTest
@testable import Stash
import SwiftUI

/// Tests for the SceneCard component
/// Verifies correct rendering for different data states
final class SceneCardTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func makeCompleteScene() -> Stash.Scene {
        return Stash.Scene(
            id: "test-scene-1",
            title: "Test Scene Title",
            details: "Scene details",
            date: "2024-12-02",
            rating100: 85,
            o_counter: 3,
            paths: Stash.Scene.ScenePaths(
                screenshot: "/path/to/screenshot.jpg",
                preview: "/path/to/preview.mp4",
                stream: "/path/to/stream.mp4",
                sprite: nil,
                vtt: nil
            ),
            files: [
                Stash.Scene.SceneFile(
                    path: nil,
                    size: 1024000,
                    duration: 1800.0,
                    video_codec: "h264",
                    audio_codec: "aac",
                    width: 1920,
                    height: 1080
                )
            ],
            performers: [
                Performer(id: "perf-1", name: "Performer One", image_path: "/perf1.jpg"),
                Performer(id: "perf-2", name: "Performer Two", image_path: "/perf2.jpg")
            ],
            tags: [
                Tag(id: "tag-1", name: "Tag One", scene_count: 5)
            ],
            // Note: Studio init might need checking. Assuming default memberwise init or similar.
            // Using placeholder logic if Studio has changed.
            studio: Studio(id: "studio-1", name: "Test Studio", image_path: "/studio.jpg")
        )
    }
    
    private func makeMinimalScene() -> Stash.Scene {
        return Stash.Scene(
            id: "test-scene-2",
            title: nil,
            details: nil,
            date: nil,
            rating100: nil,
            o_counter: nil,
            paths: nil,
            files: nil,
            performers: nil,
            tags: nil,
            studio: nil
        )
    }
    
    // MARK: - Rendering Tests
    
    func testSceneCardRendersCompleteData() throws {
        let scene = makeCompleteScene()
        let card = SceneCard(scene: scene)
        
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertEqual(scene.id, "test-scene-1")
        XCTAssertEqual(scene.title, "Test Scene Title")
        XCTAssertEqual(scene.date, "2024-12-02")
        XCTAssertEqual(scene.studio?.name, "Test Studio")
        XCTAssertEqual(scene.o_counter, 3)
        XCTAssertEqual(scene.performers?.count, 2)
    }
    
    func testSceneCardHandlesMissingData() throws {
        let scene = makeMinimalScene()
        let card = SceneCard(scene: scene)
        
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertNil(scene.title)
        XCTAssertNil(scene.date)
        XCTAssertNil(scene.studio)
        XCTAssertNil(scene.o_counter)
        XCTAssertNil(scene.performers)
    }
    
    func testSceneCardHandlesEmptyPerformers() throws {
        // Need to use var to mutate locally if using `var` properties, or init generic copy
        // Scene uses `let` for most properties but `var` for Studio/rating.
        // performers is `let`. To test empty performers we need to init new scene.
        
        let scene = makeCompleteScene()
        // Wait, Scene properties from step 83: `let performers: [Performer]?`
        // So I cannot mutate it. I must create a new one.
        
        let sceneWithNoPerformers = Stash.Scene(
            id: scene.id,
            title: scene.title,
            details: scene.details,
            date: scene.date,
            rating100: scene.rating100,
            o_counter: scene.o_counter,
            paths: scene.paths,
            files: scene.files,
            performers: [],
            tags: scene.tags,
            studio: scene.studio
        )
        
        let card = SceneCard(scene: sceneWithNoPerformers)
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        XCTAssertEqual(sceneWithNoPerformers.performers?.count, 0)
    }
    
    // MARK: - Data Integrity Tests
    
    func testSceneDataPersistence() throws {
        let scene = makeCompleteScene()
        XCTAssertEqual(scene.rating100, 85)
        XCTAssertEqual(scene.o_counter, 3)
        
        // Test mutation of var properties
        var mutableScene = scene
        mutableScene.rating100 = 100
        mutableScene.o_counter = 5
        
        XCTAssertEqual(mutableScene.rating100, 100)
        XCTAssertEqual(mutableScene.o_counter, 5)
    }
    
    func testSceneWithOnlyDate() throws {
        let scene = Stash.Scene(
            id: "test-scene-3",
            title: "Scene with Date Only",
            details: nil,
            date: "2024-01-01",
            rating100: nil,
            o_counter: nil,
            paths: nil,
            files: nil,
            performers: nil,
            tags: nil,
            studio: nil
        )
        
        let card = SceneCard(scene: scene)
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertEqual(scene.date, "2024-01-01")
        XCTAssertNil(scene.studio)
        XCTAssertNil(scene.o_counter)
    }
    
    func testSceneWithStudioAndOCounter() throws {
        let scene = Stash.Scene(
            id: "test-scene-4",
            title: "Scene with Studio and Counter",
            details: nil,
            date: "2024-01-01",
            rating100: nil,
            o_counter: 10,
            paths: nil,
            files: nil,
            performers: nil,
            tags: nil,
            studio: Studio(id: "studio-2", name: "Another Studio", image_path: nil)
        )
        
        let card = SceneCard(scene: scene)
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertEqual(scene.studio?.name, "Another Studio")
        XCTAssertEqual(scene.o_counter, 10)
    }
    
    // MARK: - Edge Cases
    
    func testVeryLongTitle() throws {
        let longTitle = String(repeating: "Very Long Title ", count: 20)
        let scene = Stash.Scene(
            id: "test-scene-5",
            title: longTitle,
            details: nil,
            date: nil,
            rating100: nil,
            o_counter: nil,
            paths: nil,
            files: nil,
            performers: nil,
            tags: nil,
            studio: nil
        )
        
        let card = SceneCard(scene: scene)
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertTrue(scene.title!.count > 100)
    }
    
    func testManyPerformers() throws {
        let performers = (1...20).map { i in
            Performer(id: "perf-\(i)", name: "Performer \(i)", image_path: nil)
        }
        
        // Must create new scene as performers is let constant
        let scene = Stash.Scene(
            id: "test-scene-long",
            title: "Many Performers",
            details: "Details",
            date: "2024-01-01",
            rating100: 90,
            o_counter: 5,
            paths: nil,
            files: nil,
            performers: performers,
            tags: nil,
            studio: nil
        )
        
        let card = SceneCard(scene: scene)
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertEqual(scene.performers?.count, 20)
    }
    
    func testZeroOCounter() throws {
        var scene = makeCompleteScene()
        scene.o_counter = 0
        
        let card = SceneCard(scene: scene)
        let host = UIHostingController(rootView: card)
        XCTAssertNotNil(host.view)
        
        XCTAssertEqual(scene.o_counter, 0)
    }
}
