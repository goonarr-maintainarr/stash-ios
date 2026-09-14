import XCTest
@testable import Stash

@MainActor
final class EditSceneTagManagerTests: XCTestCase {
    
    private var repository: MockTagRepository!
    private var manager: EditSceneTagManager!
    
    override func setUp() {
        super.setUp()
        repository = MockTagRepository()
        let initialTag = Tag(id: "tag-1", name: "Initial Tag", description: nil, scene_count: 5)
        manager = EditSceneTagManager(initialTags: [initialTag], tagRepository: repository)
    }
    
    override func tearDown() {
        manager = nil
        repository = nil
        super.tearDown()
    }
    
    func testInitialTags() {
        XCTAssertEqual(manager.currentTags.count, 1)
        XCTAssertEqual(manager.currentTags.first?.id, "tag-1")
    }
    
    func testAddTag_appendsTagAndClearsSearch() {
        manager.searchText = "New"
        let newTag = Tag(id: "tag-2", name: "New Tag", description: nil, scene_count: 10)
        
        manager.addTag(newTag)
        
        XCTAssertEqual(manager.currentTags.count, 2)
        XCTAssertEqual(manager.currentTags.last?.id, "tag-2")
        XCTAssertEqual(manager.searchText, "")
        XCTAssertTrue(manager.searchResults.isEmpty)
    }
    
    func testAddTag_duplicateDoesNotAddAgain() {
        let duplicate = Tag(id: "tag-1", name: "Initial Tag", description: nil, scene_count: 5)
        
        manager.addTag(duplicate)
        
        XCTAssertEqual(manager.currentTags.count, 1)
    }
    
    func testRemoveTag_removesExistingTag() {
        manager.removeTag(id: "tag-1")
        XCTAssertTrue(manager.currentTags.isEmpty)
    }
    
    func testRemoveTag_nonExistentTagDoesNothing() {
        manager.removeTag(id: "non-existent")
        XCTAssertEqual(manager.currentTags.count, 1)
    }
}
