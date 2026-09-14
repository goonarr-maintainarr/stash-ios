import Foundation
import Combine
@testable import Stash

@MainActor
class MockSyncService: ObservableObject, SyncServiceProtocol {
    @Published var isSyncing = false
    @Published var progress: Double = 0.0
    @Published var message: String = ""
    @Published var errorMessage: String?
    
    var isSyncingPublisher: Published<Bool>.Publisher { $isSyncing }
    var progressPublisher: Published<Double>.Publisher { $progress }
    var messagePublisher: Published<String>.Publisher { $message }
    var errorMessagePublisher: Published<String?>.Publisher { $errorMessage }
    
    var prefetchCalled = false
    var fullSyncCalled = false
    
    func prefetchAppData(forceRefresh: Bool) async {
        prefetchCalled = true
    }
    
    func fullSync() async {
        fullSyncCalled = true
    }
}
