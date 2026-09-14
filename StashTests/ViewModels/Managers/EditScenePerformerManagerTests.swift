import XCTest
@testable import Stash

@MainActor
final class EditScenePerformerManagerTests: XCTestCase {
    
    private var repository: MockPerformerRepository!
    private var manager: EditScenePerformerManager!
    
    override func setUp() {
        super.setUp()
        repository = MockPerformerRepository()
        let initialPerformer = Performer.testPerformer(id: "perf-1", name: "Initial Performer")
        manager = EditScenePerformerManager(initialPerformers: [initialPerformer], performerRepository: repository)
    }
    
    override func tearDown() {
        manager = nil
        repository = nil
        super.tearDown()
    }
    
    func testInitialPerformers() {
        XCTAssertEqual(manager.currentPerformers.count, 1)
        XCTAssertEqual(manager.currentPerformers.first?.id, "perf-1")
    }
    
    func testAddPerformer_appendsPerformerAndClearsSearch() {
        manager.searchText = "New"
        let newPerformer = Performer.testPerformer(id: "perf-2", name: "New Performer")
        
        manager.addPerformer(newPerformer)
        
        XCTAssertEqual(manager.currentPerformers.count, 2)
        XCTAssertEqual(manager.currentPerformers.last?.id, "perf-2")
        XCTAssertEqual(manager.searchText, "")
        XCTAssertTrue(manager.searchResults.isEmpty)
    }
    
    func testAddPerformer_duplicateDoesNotAddAgain() {
        let duplicate = Performer.testPerformer(id: "perf-1", name: "Initial Performer")
        
        manager.addPerformer(duplicate)
        
        XCTAssertEqual(manager.currentPerformers.count, 1)
    }
    
    func testRemovePerformer_removesExistingPerformer() {
        manager.removePerformer(id: "perf-1")
        XCTAssertTrue(manager.currentPerformers.isEmpty)
    }
    
    func testRemovePerformer_nonExistentPerformerDoesNothing() {
        manager.removePerformer(id: "non-existent")
        XCTAssertEqual(manager.currentPerformers.count, 1)
    }
}
