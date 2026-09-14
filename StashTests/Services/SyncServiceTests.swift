import XCTest
import Combine
@testable import Stash

@MainActor
final class SyncServiceTests: XCTestCase {
    var syncService: SyncService!
    var mockSceneRepository: MockSceneRepository!
    var mockPerformerRepository: MockPerformerRepository!
    var mockTagRepository: MockTagRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockSceneRepository = MockSceneRepository()
        mockPerformerRepository = MockPerformerRepository()
        mockTagRepository = MockTagRepository()
        
        syncService = SyncService(
            sceneRepository: mockSceneRepository,
            performerRepository: mockPerformerRepository,
            tagRepository: mockTagRepository
        )
        cancellables = []
    }
    
    override func tearDown() {
        syncService = nil
        mockSceneRepository = nil
        mockPerformerRepository = nil
        mockTagRepository = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testPrefetchAppData_WhenCacheEmpty_ShouldSyncEverything() async throws {
        // Given: Empty caches (mockScenes is used for cache)
        mockSceneRepository.mockScenes = []
        mockPerformerRepository.mockPerformers = []
        mockTagRepository.mockTags = []
        
        // Mock remote data
        mockSceneRepository.remoteScenes = [Scene(id: "1", title: "Scene 1")]
        mockPerformerRepository.remotePerformers = [Performer(id: "1", name: "Perf 1", image_path: nil)]
        mockTagRepository.remoteTags = [Tag(id: "1", name: "Tag 1", scene_count: 5)]
        
        // Expectations
        let syncCompletionExpectation = expectation(description: "Sync should complete")
        
        // Monitor isSyncing: true -> false
        var hasStartedSyncing = false
        
        syncService.$isSyncing
            .sink { isSyncing in
                if isSyncing {
                    hasStartedSyncing = true
                } else if hasStartedSyncing {
                    syncCompletionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        // When
        await syncService.prefetchAppData(forceRefresh: false)
        
        // Then
        await fulfillment(of: [syncCompletionExpectation], timeout: 2.0)
        
        XCTAssertEqual(syncService.progress, 1.0)
        XCTAssertTrue(syncService.message.contains("Synced"))
    }
    
    func testPrefetchAppData_WhenCacheUpToDate_ShouldNotSync() async throws {
        // Given: Caches with data
        let existingScene = Scene(id: "1", title: "Scene 1")
        mockSceneRepository.mockScenes = [existingScene]
        mockPerformerRepository.mockPerformers = [Performer(id: "1", name: "Perf 1", image_path: nil)]
        mockTagRepository.mockTags = [Tag(id: "1", name: "Tag 1", scene_count: 5)]
        
        // Ensure shouldRefreshCache returns false (default in Mock)
        
        // When
        await syncService.prefetchAppData(forceRefresh: false)
        
        // Then
        XCTAssertFalse(syncService.isSyncing)
        
        // When cache is up to date, message is set to 'Checking for updates...' at start.
        // If itemsToSync is empty, it returns early without changing message.
        XCTAssertEqual(syncService.message, "Checking for updates...")
    }
    
    func testFullSync_ShouldCallFullSyncOnRepos() async throws {
        // Given
        mockSceneRepository.remoteScenes = [Scene(id: "2", title: "Scene 2")]
        
        // When
        await syncService.fullSync()
        
        // Then
        // Verify Full Sync completed
        XCTAssertFalse(syncService.isSyncing)
        XCTAssertEqual(syncService.progress, 1.0)
        XCTAssertEqual(syncService.message, "Full sync complete")
    }
}
