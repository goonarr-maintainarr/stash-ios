import XCTest
@testable import Stash

final class ArraySortingTests: XCTestCase {
    
    // MARK: - Scene Sorting Tests
    
    func testSceneSort_byDate_ascendingAndDescending() {
        let sceneA = Scene.testScene(id: "1", title: "A", date: "2023-01-01")
        let sceneB = Scene.testScene(id: "2", title: "B", date: "2024-06-01")
        let scenes = [sceneB, sceneA]
        
        let asc = scenes.sorted(by: .date, ascending: true)
        XCTAssertEqual(asc.map(\.id), ["1", "2"])
        
        let desc = scenes.sorted(by: .date, ascending: false)
        XCTAssertEqual(desc.map(\.id), ["2", "1"])
    }
    
    func testSceneSort_byRating_ascendingAndDescending() {
        let sceneA = Scene.testScene(id: "1", rating100: 50)
        let sceneB = Scene.testScene(id: "2", rating100: 95)
        let scenes = [sceneB, sceneA]
        
        let asc = scenes.sorted(by: .rating, ascending: true)
        XCTAssertEqual(asc.map(\.id), ["1", "2"])
        
        let desc = scenes.sorted(by: .rating, ascending: false)
        XCTAssertEqual(desc.map(\.id), ["2", "1"])
    }
    
    func testSceneSort_byOCounter_ascendingAndDescending() {
        let sceneA = Scene.testScene(id: "1", o_counter: 2)
        let sceneB = Scene.testScene(id: "2", o_counter: 10)
        let scenes = [sceneB, sceneA]
        
        let asc = scenes.sorted(by: .oCounter, ascending: true)
        XCTAssertEqual(asc.map(\.id), ["1", "2"])
        
        let desc = scenes.sorted(by: .oCounter, ascending: false)
        XCTAssertEqual(desc.map(\.id), ["2", "1"])
    }
    
    func testSceneSort_randomWithCache_preservesCachedOrder() {
        let sceneA = Scene.testScene(id: "1")
        let sceneB = Scene.testScene(id: "2")
        let sceneC = Scene.testScene(id: "3")
        let scenes = [sceneA, sceneB, sceneC]
        
        var cache: [Scene]? = nil
        let firstSort = scenes.sorted(by: .random, ascending: true, randomCache: &cache)
        XCTAssertNotNil(cache)
        
        let secondSort = scenes.sorted(by: .random, ascending: true, randomCache: &cache)
        XCTAssertEqual(firstSort.map(\.id), secondSort.map(\.id))
    }
    
    func testSceneSort_nonRandomClearsCache() {
        let sceneA = Scene.testScene(id: "1")
        let sceneB = Scene.testScene(id: "2")
        let scenes = [sceneA, sceneB]
        
        var cache: [Scene]? = [sceneA, sceneB]
        _ = scenes.sorted(by: .date, ascending: true, randomCache: &cache)
        XCTAssertNil(cache)
    }
    
    // MARK: - Performer Sorting Tests
    
    func testPerformerSort_byName_ascendingAndDescending() {
        let perfA = Performer.testPerformer(id: "1", name: "Alice")
        let perfB = Performer.testPerformer(id: "2", name: "Zara")
        let performers = [perfB, perfA]
        
        let asc = performers.sorted(by: .name, ascending: true)
        XCTAssertEqual(asc.map(\.id), ["1", "2"])
        
        let desc = performers.sorted(by: .name, ascending: false)
        XCTAssertEqual(desc.map(\.id), ["2", "1"])
    }
    
    func testPerformerSort_bySceneCount_ascendingAndDescending() {
        let perfA = Performer.testPerformer(id: "1", scene_count: 5)
        let perfB = Performer.testPerformer(id: "2", scene_count: 50)
        let performers = [perfB, perfA]
        
        let asc = performers.sorted(by: .sceneCount, ascending: true)
        XCTAssertEqual(asc.map(\.id), ["1", "2"])
        
        let desc = performers.sorted(by: .sceneCount, ascending: false)
        XCTAssertEqual(desc.map(\.id), ["2", "1"])
    }
    
    func testPerformerSort_byOCounter_ascendingAndDescending() {
        let perfA = Performer.testPerformer(id: "1", o_counter: 1)
        let perfB = Performer.testPerformer(id: "2", o_counter: 25)
        let performers = [perfB, perfA]
        
        let asc = performers.sorted(by: .oCounter, ascending: true)
        XCTAssertEqual(asc.map(\.id), ["1", "2"])
        
        let desc = performers.sorted(by: .oCounter, ascending: false)
        XCTAssertEqual(desc.map(\.id), ["2", "1"])
    }
}
