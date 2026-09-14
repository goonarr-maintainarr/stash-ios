import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneSyncService")

/// Service responsible for scene synchronization between API and local cache.
///
/// Handles:
/// - Incremental sync (timestamp-based)
/// - Full sync with deletion cleanup
/// - Changed scenes sync
/// - Batch operations with parallel processing
class SceneSyncService: StashService, @unchecked Sendable {

    // MARK: - Dependencies

    let apiClient: StashClientProtocol
    private let database: StashDatabase
    let settings: any SettingsStoreProtocol
    private let cacheService: SceneCacheService
    private let imagePrefetchManager: ImagePrefetchService

    // MARK: - Initialization

    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: any SettingsStoreProtocol,
        cacheService: SceneCacheService,
        imagePrefetchManager: ImagePrefetchService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.cacheService = cacheService
        self.imagePrefetchManager = imagePrefetchManager
    }

    // MARK: - Public Methods

    /// Synchronizes only new or updated scenes using timestamps.
    func syncNewScenes(progressHandler: (@MainActor (Int, Int) -> Void)?, checkForDeletions: Bool = true) async throws -> [Scene] {
        let url = try settings.validateStashConfiguration()

        logger.info("🔄 Starting incremental sync (Timestamp Diff Strategy)...")

        // 1. Get local timestamps
        let localTimestamps = try await database.fetchSceneTimestamps()
        logger.info("📦 Loaded \(localTimestamps.count) local scenes")

        // 2. Fetch all remote timestamps (lightweight)
        struct TSResult: Codable {
            struct TSScenes: Codable {
                let count: Int
                let scenes: [SceneTS]
            }
            struct SceneTS: Codable {
                let id: String
                let updated_at: String?
            }
            let findScenes: TSScenes
        }

        let remoteTimestamps = try await fetchRemoteTimestamps(
            queryBuilder: { StashQueries.findSceneTimestamps(page: $0, perPage: $1) },
            url: url,
            transform: { (result: TSResult) in
                (result.findScenes.count, result.findScenes.scenes.map { ($0.id, $0.updated_at) })
            },
            perPage: 250,
            progressHandler: progressHandler
        )
        logger.info("🌍 Fetched \(remoteTimestamps.count) remote scenes")

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
        if checkForDeletions {
            let remoteIds = Set(remoteTimestamps.keys)
            let localIds = Set(localTimestamps.keys)
            idsToDelete = localIds.subtracting(remoteIds)
        }

        logger.info("📊 Diff results: \(idsToFetch.count) scenes to update/add, \(idsToDelete.count) scenes to delete")

        // 4. Batch fetch updates
        if !idsToFetch.isEmpty {
            let batchSize = 40 // Stash usually handles 40-50 well
            let chunks = stride(from: 0, to: idsToFetch.count, by: batchSize).map {
                Array(idsToFetch[$0..<min($0 + batchSize, idsToFetch.count)])
            }

            logger.info("📥 Fetching \(idsToFetch.count) scenes in \(chunks.count) parallel batches...")

            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, batchIds) in chunks.enumerated() {
                    group.addTask { [self] in

                        let query = StashQueries.findScenesBatch(ids: batchIds)

                        // Decode dynamic response: "scene0": {...}, "scene1": {...}
                        let resultMap: [String: SceneDTO?] = try await self.fetchWithErrorWrapping(
                            query: query,
                            variables: nil,
                            url: url
                        )

                        let fetchedScenes = resultMap.values.compactMap { $0?.toDomain() }


                        // Save batch to cache
                        if !fetchedScenes.isEmpty {
                            try await self.cacheService.cacheScenes(fetchedScenes)
                            // Prefetch images for immediate availability
                            self.prefetchImages(for: fetchedScenes, count: fetchedScenes.count)
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
            try await database.removeDeletedScenes(keeping: Set(remoteTimestamps.keys))
            logger.info("🗑️ Removed \(idsToDelete.count) deleted scenes from cache")
        }

        logger.info("✅ Sync complete")
        return try await cacheService.getCachedScenes()
    }

    /// Performs a full synchronization, ensuring local cache mirrors the remote server completely.
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?, getAllScenes: () async throws -> [Scene]) async throws -> (scenes: [Scene], removedCount: Int) {
        logger.info("🔄 Starting full sync with deletion cleanup...")

        // Get current cache count before sync
        let cachedBefore = try await cacheService.getCachedScenes()
        let cachedBeforeCount = cachedBefore.count

        // Fetch all scenes from API using provided closure
        logger.info("📥 Fetching all scenes from API...")
        let allScenes = try await getAllScenes()

        // Remove deleted scenes
        let sceneIds = Set(allScenes.map { $0.id })
        try await database.removeDeletedScenes(keeping: sceneIds)

        // Calculate how many were removed
        let cachedAfter = try await cacheService.getCachedScenes()
        let removedCount = max(0, cachedBeforeCount - cachedAfter.count + (allScenes.count - cachedBeforeCount))

        logger.info("✅ Full sync complete: \(allScenes.count) scenes, \(removedCount) removed")

        return (allScenes, removedCount)
    }

    /// Syncs all scenes that have been updated on the server since our last local sync.
    func syncChangedScenes() async throws -> [Scene] {
        let url = try settings.validateStashConfiguration()

        logger.info("🔄 Checking for changed scenes...")

        // Get the latest updated_at from our local cache
        let lastSyncTime = try await database.getLatestSceneUpdatedAt()

        if let timestamp = lastSyncTime {
            // Query for scenes updated after our latest cached scene
            logger.info("🔄 Syncing scenes updated since: \(timestamp)")

            let query = StashQueries.findScenesUpdatedSince(timestamp: timestamp)

            let result: SceneResultDTO = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )

            let changedScenes = result.findScenes.toDomain().scenes

            if changedScenes.isEmpty {
                logger.info("✅ No scenes changed since last sync")
                return []
            }

            logger.info("🔄 Found \(changedScenes.count) changed scene(s), caching...")

            try await cacheService.cacheScenes(changedScenes)

            return changedScenes
        } else {
            // No local scenes yet, just get the most recent one as a starting point
            logger.info("🔄 No local cache, fetching most recent scene...")

            let query = StashQueries.findScenes(
                searchText: "",
                page: 1,
                perPage: 1,
                sort: "updated_at",
                direction: "DESC"
            )

            let result: SceneResultDTO = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )

            guard let scene = result.findScenes.toDomain().scenes.first else {
                return []
            }

            logger.info("✅ Cached most recent scene as starting point")

            try await cacheService.cacheScenes([scene])
            return [scene]
        }
    }

    /// Prefetches images for a list of scenes.
    private func prefetchImages(for scenes: [Scene], count: Int) {
        let urlsToPrefetch = scenes.prefix(count).compactMap { scene -> URL? in
            settings.createImageUrl(path: scene.paths?.screenshot)
        }

        if !urlsToPrefetch.isEmpty {
            logger.debug("🖼️ Prefetching \(urlsToPrefetch.count) images")
            imagePrefetchManager.prefetch(urls: urlsToPrefetch)
        }
    }
}

