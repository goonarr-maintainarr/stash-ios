import XCTest
@testable import Stash

final class HomeSceneProcessorTests: XCTestCase {
    
    private var processor: HomeSceneProcessor!
    private var mockRepo: MockSceneRepository!
    
    override func setUp() {
        super.setUp()
        mockRepo = MockSceneRepository()
        processor = HomeSceneProcessor(sceneRepository: mockRepo, settings: SettingsStore.shared)
    }
    
    override func tearDown() {
        processor = nil
        mockRepo = nil
        super.tearDown()
    }
    
    func testFilterAndSortScenes_byRating_sortsDescendingAndAppliesLimit() {
        let scene1 = Scene.testScene(id: "1", rating100: 40)
        let scene2 = Scene.testScene(id: "2", rating100: 90)
        let scene3 = Scene.testScene(id: "3", rating100: 75)
        
        let category = SceneCategory(title: "Top Rated", sortType: .rating)
        let result = processor.filterAndSortScenes([scene1, scene2, scene3], for: category, limit: 2)
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.id), ["2", "3"])
    }
    
    func testFilterAndSortScenes_byDate_sortsDescending() {
        let scene1 = Scene.testScene(id: "1", date: "2022-01-01")
        let scene2 = Scene.testScene(id: "2", date: "2024-05-10")
        let scene3 = Scene.testScene(id: "3", date: "2023-11-20")
        
        let category = SceneCategory(title: "Recently Released", sortType: .date)
        let result = processor.filterAndSortScenes([scene1, scene2, scene3], for: category, limit: 10)
        
        XCTAssertEqual(result.map(\.id), ["2", "3", "1"])
    }
    
    func testFilterAndSortScenes_byOCounter_sortsDescending() {
        let scene1 = Scene.testScene(id: "1", o_counter: 3)
        let scene2 = Scene.testScene(id: "2", o_counter: 15)
        let scene3 = Scene.testScene(id: "3", o_counter: 8)
        
        let category = SceneCategory(title: "Most Viewed", sortType: .oCounter)
        let result = processor.filterAndSortScenes([scene1, scene2, scene3], for: category, limit: 10)
        
        XCTAssertEqual(result.map(\.id), ["2", "3", "1"])
    }
    
    func testFilterAndSortScenes_withTagFilter_onlyIncludesMatchingScenes() {
        let tagA = Tag(id: "tag-1", name: "Tag One", description: nil, scene_count: 5)
        let tagB = Tag(id: "tag-2", name: "Tag Two", description: nil, scene_count: 3)
        
        let matchingScene = Scene.testScene(id: "1", tags: [tagA])
        let nonMatchingScene = Scene.testScene(id: "2", tags: [tagB])
        let noTagsScene = Scene.testScene(id: "3", tags: nil)
        
        let category = SceneCategory(title: "Tag One Scenes", sortType: .date, tagIds: ["tag-1"])
        let result = processor.filterAndSortScenes([matchingScene, nonMatchingScene, noTagsScene], for: category, limit: 10)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "1")
    }
    
    func testFilterAndSortScenes_emptyScenes_returnsEmpty() {
        let category = SceneCategory(title: "Empty", sortType: .date)
        let result = processor.filterAndSortScenes([], for: category, limit: 10)
        XCTAssertTrue(result.isEmpty)
    }
}
