import Foundation
import Observation

/// Coordinator for settings-related operations, decoupled from HomeViewModel
@MainActor
@Observable
class SettingsCoordinator {
    var syncState: SyncState = .idle
    
    private let syncService: SyncService
    
    init(syncService: SyncService) {
        self.syncService = syncService
    }
    
    /// Perform full sync of scenes, performers, and tags
    func performFullSync() async {
        syncState = .syncing(progress: 0, message: "Starting sync...")
        
        // Delegate to SyncService and mirror its state
        await syncService.fullSync()
        
        // Check if sync succeeded or failed
        if let error = syncService.errorMessage {
            syncState = .error(error)
        } else {
            syncState = .syncing(progress: 1.0, message: "Sync complete!")
            
            // Reset to idle after brief delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            syncState = .idle
        }
    }
    
    var isSyncing: Bool {
        if case .syncing = syncState {
            return true
        }
        return false
    }
}

/// Sync state enum matching HomeViewModel's state for compatibility
enum SyncState: Equatable {
    case idle
    case syncing(progress: Double, message: String)
    case error(String)
}
