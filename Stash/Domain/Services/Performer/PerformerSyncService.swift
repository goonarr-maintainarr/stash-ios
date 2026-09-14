import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerSyncService")

/// Service responsible for performer synchronization between API and local cache.
///
/// Handles:
/// - Incremental sync (timestamp-based)
/// - Deletion cleanup
class PerformerSyncService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    private let database: StashDatabase
    let settings: any SettingsStoreProtocol
    private let fetchService: PerformerFetchService
    private let cacheService: PerformerCacheService
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: any SettingsStoreProtocol,
        fetchService: PerformerFetchService,
        cacheService: PerformerCacheService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.fetchService = fetchService
        self.cacheService = cacheService
    }
    
    // MARK: - Public Methods
    
    /// Synchronizes only new or updated performers using timestamps.
    func syncNewPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer] {
        logger.info("🔄 Starting incremental performer sync (Timestamp Diff Strategy)...")
        
        // 1. Get local timestamps
        let localTimestamps = try await database.fetchPerformerTimestamps()
        logger.info("📦 Loaded \(localTimestamps.count) local performers")
        
        // 2. Fetch all remote timestamps (lightweight)
        let remoteTimestamps = try await fetchService.fetchRemotePerformerTimestamps(progressHandler: progressHandler)
        logger.info("🌍 Fetched \(remoteTimestamps.count) remote performers")
        
        // 3. Diff to find needed updates
        var idsToFetch: [String] = []
        var idsToDelete: Set<String> = []
        
        
        // Check for updates/adds
        for (id, remoteDate) in remoteTimestamps {
            if let localDate = localTimestamps[id] {
                if localDate != remoteDate {
                    // Timestamps differ, fetch update
                    idsToFetch.append(id)
                }
            } else {
                // Not in local DB, fetch it
                idsToFetch.append(id)
            }
        }
        
        // Check for deletions
        let remoteIds = Set(remoteTimestamps.keys)
        let localIds = Set(localTimestamps.keys)
        idsToDelete = localIds.subtracting(remoteIds)
        
        logger.info("📊 Diff results: \(idsToFetch.count) performers to update/add, \(idsToDelete.count) to delete")
        
        // 4. Batch fetch updates
        if !idsToFetch.isEmpty {
            let batchSize = 40
            let chunks = stride(from: 0, to: idsToFetch.count, by: batchSize).map {
                Array(idsToFetch[$0..<min($0 + batchSize, idsToFetch.count)])
            }
            
            logger.info("📥 Fetching \(idsToFetch.count) performers in \(chunks.count) parallel batches...")
            
            let url = try settings.validateStashConfiguration()
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, batchIds) in chunks.enumerated() {
                    group.addTask { [self] in
                        
                        let query = StashQueries.findPerformersBatch(ids: batchIds)
                        
                        // Decode dynamic response: "performer0": {...}, "performer1": {...}
                        let resultMap: [String: PerformerDTO?] = try await self.fetchWithErrorWrapping(
                            query: query,
                            variables: nil,
                            url: url
                        )
                        
                        let fetchedPerformers = resultMap.values.compactMap { $0?.toDomain() }
                        
                        // Save batch to cache
                        if !fetchedPerformers.isEmpty {
                            try await self.cacheService.cachePerformers(fetchedPerformers)
                        }
                    }
                }
                
                // Wait for all batches to complete
                try await group.waitForAll()
                logger.info("✅ All batches completed")
            }
        }
        
        // 5. Process deletions
        if !idsToDelete.isEmpty {
            try await database.removeDeletedPerformers(keeping: remoteIds)
            logger.info("🗑️ Removed \(idsToDelete.count) deleted performers from cache")
        }
        
        logger.info("✅ Performer sync complete")
        
        return try await cacheService.getCachedPerformers()
    }
    
    /// Synchronizes performers that have been updated since the last local update (Smart Sync).
    /// Used for quick refreshes on view appearance.
    func syncChangedPerformers() async throws -> [Performer] {
        logger.info("🔄 Starting incremental performer sync (Changed Since Strategy)...")
        
        // 1. Get the latest 'updated_at' from local DB
        let lastTimestamp = try await database.getLatestPerformerUpdatedAt()
        
        // If DB is empty, fetch the most recent one to start seeding (or full sync would be better, but this is safe fallback)
        // Actually, if DB is empty, we should probably fetch everything?
        // But this method assumes incremental. If nil, default to "since beginning of time" or just recent?
        // Let's use a very old date if nil, or just handle it.
        // StashQueries with empty timestamp might fail?
        // If nil, fetch 1 page.
        
        let timestampToUse = lastTimestamp ?? "1970-01-01T00:00:00Z"
        logger.debug("📅 Checking for performers updated since: \(timestampToUse)")
        
        // 2. Query API for updates
        let query = StashQueries.findPerformersUpdatedSince(timestamp: timestampToUse)
        let url = try settings.validateStashConfiguration()
        
        let result: PerformerResultDTO = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        let changedPerformers = result.findPerformers.toDomain().performers
        
        guard !changedPerformers.isEmpty else {
            logger.debug("✅ No updated performers found")
            return []
        }
        
        logger.info("📥 Found \(changedPerformers.count) changed performers, merging...")
        
        // 4. Save to cache
        try await cacheService.cachePerformers(changedPerformers)
        logger.info("✅ Cached \(changedPerformers.count) updated performers")
        
        return changedPerformers
    }
    
}

