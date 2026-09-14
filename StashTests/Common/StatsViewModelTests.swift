import XCTest
@testable import Stash

@MainActor
final class StatsViewModelTests: XCTestCase {
    
    private var repository: MockStatsRepository!
    private var viewModel: StatsViewModel!
    
    override func setUp() {
        super.setUp()
        repository = MockStatsRepository()
        viewModel = StatsViewModel(repository: repository)
    }
    
    override func tearDown() {
        viewModel = nil
        repository = nil
        super.tearDown()
    }
    
    func testInitialState_isIdle() {
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.stats)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadStats_success_transitionsToLoaded() async {
        let expectedStats = Stats.testStats(scene_count: 500, performer_count: 50)
        repository.mockStats = expectedStats
        repository.shouldThrowError = false
        
        await viewModel.loadStats()
        
        XCTAssertEqual(viewModel.state, .loaded(expectedStats))
        XCTAssertEqual(viewModel.stats?.scene_count, 500)
        XCTAssertEqual(viewModel.stats?.performer_count, 50)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadStats_failure_transitionsToError() async {
        repository.shouldThrowError = true
        repository.errorToThrow = NSError(domain: "StatsTest", code: 42, userInfo: [NSLocalizedDescriptionKey: "Failed to connect"])
        
        await viewModel.loadStats()
        
        XCTAssertEqual(viewModel.state, .error("Failed to connect"))
        XCTAssertNil(viewModel.stats)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.errorMessage, "Failed to connect")
    }
    
    func testRefresh_reloadsStatsSuccessfully() async {
        let initialStats = Stats.testStats(scene_count: 100)
        let updatedStats = Stats.testStats(scene_count: 105)
        
        repository.mockStats = initialStats
        await viewModel.loadStats()
        XCTAssertEqual(viewModel.stats?.scene_count, 100)
        
        repository.mockStats = updatedStats
        await viewModel.refresh()
        XCTAssertEqual(viewModel.stats?.scene_count, 105)
    }
}
