import XCTest
@testable import Stash

@MainActor
final class TaggerConfigViewModelTests: XCTestCase {
    
    private var repository: MockSceneRepository!
    private var viewModel: TaggerConfigViewModel!
    
    override func setUp() {
        super.setUp()
        repository = MockSceneRepository()
        let config = TaggerConfig()
        viewModel = TaggerConfigViewModel(repository: repository, initialConfig: config)
    }
    
    override func tearDown() {
        viewModel = nil
        repository = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSave_success() async {
        repository.shouldThrowError = false
        
        await viewModel.save()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSave_failure_setsErrorMessage() async {
        repository.shouldThrowError = true
        
        await viewModel.save()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Failed to save configuration") ?? false)
    }
}
