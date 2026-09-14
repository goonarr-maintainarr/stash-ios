import Foundation
import Combine
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "HomeSyncManager")

/// Manages data synchronization for home page.
@MainActor
@Observable
class HomeSyncManager {
    
    // MARK: - State
    
    var syncState: (isSyncing: Bool, progress: Double, message: String) = (false, 0.0, "")
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let syncService: any SyncServiceProtocol
    private let sceneRepository: any SceneRepositoryProtocol
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(syncService: any SyncServiceProtocol, sceneRepository: any SceneRepositoryProtocol) {
        self.syncService = syncService
        self.sceneRepository = sceneRepository
        logger.debug("🔧 HomeSyncManager initialized")
        bindSyncService()
    }
    
    // MARK: - Sync Service Binding
    
    private func bindSyncService() {
        logger.debug("📡 Binding to sync service")
        
        // Combine sync state into published properties
        Publishers.CombineLatest3(
            syncService.isSyncingPublisher,
            syncService.progressPublisher,
            syncService.messagePublisher
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isSyncing, progress, message in
            self?.syncState = (isSyncing, progress, message)
        }
        .store(in: &cancellables)
        
        syncService.errorMessagePublisher
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                logger.error("❌ Sync error: \(error, privacy: .public)")
                self?.errorMessage = error
            }
            .store(in: &cancellables)
        
        logger.info("✅ Sync service bound successfully")
    }
    
    // MARK: - Sync Operations
    
    /// Prefetch all data (scenes and performers) on app launch.
    func prefetchAppData(forceRefresh: Bool = false) async {
        logger.info("📥 Prefetching app data (forceRefresh: \(forceRefresh))")
        await syncService.prefetchAppData(forceRefresh: forceRefresh)
        logger.info("✅ App data prefetch complete")
    }
    
    /// Lightweight sync of scenes that changed since last sync.
    func syncChangedScenes() async {
        logger.info("🔄 Syncing changed scenes...")
        
        do {
            _ = try await sceneRepository.syncChangedScenes()
            logger.info("✅ Changed scenes synced successfully")
        } catch {
            logger.error("❌ Failed to sync changed scenes: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Full sync: fetches all data and removes deleted items.
    func fullSync() async {
        logger.info("🔄 Starting full sync...")
        await syncService.fullSync()
        logger.info("✅ Full sync complete")
    }
}
