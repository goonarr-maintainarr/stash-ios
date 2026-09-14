import XCTest
@testable import Stash

@MainActor
final class SettingsViewModelTests: XCTestCase {
    
    private var store: MockSettingsStore!
    private var repository: MockSettingsRepository!
    private var whisparrRepository: MockWhisparrRepository!
    private var viewModel: SettingsViewModel!
    
    override func setUp() {
        super.setUp()
        store = MockSettingsStore()
        repository = MockSettingsRepository()
        whisparrRepository = MockWhisparrRepository()
        viewModel = SettingsViewModel(
            store: store,
            repository: repository,
            whisparrRepository: whisparrRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        whisparrRepository = nil
        repository = nil
        store = nil
        super.tearDown()
    }
    
    // MARK: - Stash Connection Tests
    
    func testStashConnection_success() async {
        store.url = URL(string: "https://stash.example.com")
        repository.shouldThrowError = false
        
        await viewModel.testStashConnection()
        
        XCTAssertTrue(repository.testStashConnectionCalled)
        XCTAssertTrue(viewModel.testSuccess)
        XCTAssertEqual(viewModel.testMessage, "Connection Successful!")
        XCTAssertFalse(viewModel.isTestingStash)
    }
    
    func testStashConnection_invalidURL() async {
        store.url = nil
        
        await viewModel.testStashConnection()
        
        XCTAssertFalse(repository.testStashConnectionCalled)
        XCTAssertFalse(viewModel.testSuccess)
        XCTAssertEqual(viewModel.testMessage, "Invalid Server URL")
    }
    
    func testStashConnection_failure() async {
        store.url = URL(string: "https://stash.example.com")
        repository.shouldThrowError = true
        
        await viewModel.testStashConnection()
        
        XCTAssertTrue(repository.testStashConnectionCalled)
        XCTAssertFalse(viewModel.testSuccess)
        XCTAssertTrue(viewModel.testMessage?.contains("Failed:") ?? false)
        XCTAssertFalse(viewModel.isTestingStash)
    }
    
    // MARK: - StashDB Connection Tests
    
    func testStashDBConnection_success() async {
        store.stashDBApiKey = "valid-api-key"
        repository.shouldThrowError = false
        
        await viewModel.testStashDBConnection()
        
        XCTAssertTrue(repository.testStashDBCalled)
        XCTAssertTrue(viewModel.testStashDBSuccess)
        XCTAssertEqual(viewModel.testStashDBMessage, "Connection Successful!")
        XCTAssertFalse(viewModel.isTestingStashDB)
    }
    
    func testStashDBConnection_emptyApiKey() async {
        store.stashDBApiKey = ""
        
        await viewModel.testStashDBConnection()
        
        XCTAssertFalse(repository.testStashDBCalled)
        XCTAssertFalse(viewModel.testStashDBSuccess)
        XCTAssertEqual(viewModel.testStashDBMessage, "API Key is required")
    }
    
    func testStashDBConnection_failure() async {
        store.stashDBApiKey = "bad-key"
        repository.shouldThrowError = true
        
        await viewModel.testStashDBConnection()
        
        XCTAssertTrue(repository.testStashDBCalled)
        XCTAssertFalse(viewModel.testStashDBSuccess)
        XCTAssertTrue(viewModel.testStashDBMessage?.contains("Failed:") ?? false)
    }
    
    // MARK: - Whisparr Config Tests
    
    func testLoadWhisparrConfig_success() async {
        store.whisparrUrl = "https://whisparr.example.com"
        store.whisparrApiKey = "key"
        
        whisparrRepository.mockRootFolders = [
            WhisparrRootFolder(id: 1, path: "/data/media", accessible: true, freeSpace: 1000000000)
        ]
        whisparrRepository.mockQualityProfiles = [
            WhisparrQualityProfile(id: 1, name: "HD - 1080p")
        ]
        
        await viewModel.loadWhisparrConfig()
        
        XCTAssertFalse(viewModel.isLoadingWhisparrConfig)
        XCTAssertEqual(viewModel.availableRootFolders.count, 1)
        XCTAssertEqual(viewModel.availableQualityProfiles.count, 1)
        XCTAssertNil(viewModel.whisparrConfigError)
    }
    
    func testLoadWhisparrConfig_emptyConfig_doesNotFetch() async {
        store.whisparrUrl = ""
        store.whisparrApiKey = ""
        
        await viewModel.loadWhisparrConfig()
        
        XCTAssertTrue(viewModel.availableRootFolders.isEmpty)
        XCTAssertTrue(viewModel.availableQualityProfiles.isEmpty)
    }
}
