import Foundation
import Combine
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SyncService")

@MainActor
protocol SyncServiceProtocol: AnyObject {
    var isSyncing: Bool { get }
    var progress: Double { get }
    var message: String { get }
    var errorMessage: String? { get }
    
    var isSyncingPublisher: Published<Bool>.Publisher { get }
    var progressPublisher: Published<Double>.Publisher { get }
    var messagePublisher: Published<String>.Publisher { get }
    var errorMessagePublisher: Published<String?>.Publisher { get }
    
    func prefetchAppData(forceRefresh: Bool) async
    func fullSync() async
}

@MainActor
class SyncService: ObservableObject, SyncServiceProtocol {
    @Published var isSyncing = false
    @Published var progress: Double = 0.0
    @Published var message: String = ""
    @Published var errorMessage: String?
    
    var isSyncingPublisher: Published<Bool>.Publisher { $isSyncing }
    var progressPublisher: Published<Double>.Publisher { $progress }
    var messagePublisher: Published<String>.Publisher { $message }
    var errorMessagePublisher: Published<String?>.Publisher { $errorMessage }
    
    private let sceneRepository: any SceneRepositoryProtocol
    private let performerRepository: any PerformerRepositoryProtocol
    private let tagRepository: any TagRepositoryProtocol
    
    init(
        sceneRepository: any SceneRepositoryProtocol,
        performerRepository: any PerformerRepositoryProtocol,
        tagRepository: any TagRepositoryProtocol
    ) {
        self.sceneRepository = sceneRepository
        self.performerRepository = performerRepository
        self.tagRepository = tagRepository
    }
    
    /// Prefetch all data (scenes and performers) on app launch
    func prefetchAppData(forceRefresh: Bool = false) async {
        logger.info("🚀 prefetchAppData started (forceRefresh: \(forceRefresh))")
        
        isSyncing = true
        progress = 0.0
        message = "Checking for updates..."
        errorMessage = nil
        
        do {
            // Check staleness concurrenty
            async let sceneCheck = sceneRepository.shouldRefreshCache()
            async let perfCheck = performerRepository.shouldRefreshCache()
            async let tagCheck = tagRepository.shouldRefreshCache()
            
            async let sceneCountTask = sceneRepository.getCachedSceneCount()
            async let perfCountTask = performerRepository.getCachedPerformerCount()
            async let tagCountTask = tagRepository.getCachedTagCount()
            
            let (shouldRefreshScenes, shouldRefreshPerformers, shouldRefreshTags) = try await (sceneCheck, perfCheck, tagCheck)
            let (sceneCount, performerCount, tagCount) = try await (sceneCountTask, perfCountTask, tagCountTask)
            
            // Determine what to sync
            let syncScenes = forceRefresh || shouldRefreshScenes || sceneCount == 0
            let syncPerformers = forceRefresh || shouldRefreshPerformers || performerCount == 0
            let syncTags = forceRefresh || shouldRefreshTags || tagCount == 0
            
            var itemsToSync: [String] = []
            if syncScenes { itemsToSync.append("scenes") }
            if syncPerformers { itemsToSync.append("performers") }
            if syncTags { itemsToSync.append("tags") }
            
            if itemsToSync.isEmpty {
                logger.info("✅ All data is up to date")
                isSyncing = false
                return
            }
            
            logger.info("🔄 Syncing needed for: \(itemsToSync.joined(separator: ", "))")
            message = "Syncing \(itemsToSync.joined(separator: ", "))..."
            
            // Track progress components
            var sceneProgress: Double = 0
            var perfProgress: Double = 0
            var tagProgress: Double = 0
            
            // Weights for total progress (approximate based on typical data size)
            // Scenes are usually the bulk of data
            let sceneWeight = syncScenes ? 0.6 : 0.0
            let perfWeight = syncPerformers ? 0.3 : 0.0
            let tagWeight = syncTags ? 0.1 : 0.0
            let totalWeight = sceneWeight + perfWeight + tagWeight
            
            let updateCombinedProgress = { @MainActor [weak self] in
                guard let self = self else { return }
                guard totalWeight > 0 else { self.progress = 1.0; return }
                let weighted = (sceneProgress * sceneWeight) + (perfProgress * perfWeight) + (tagProgress * tagWeight)
                self.progress = min(weighted / totalWeight, 1.0)
            }
            
            try await withThrowingTaskGroup(of: String.self) { group in
                
                // 1. Sync Scenes
                if syncScenes {
                    group.addTask {
                        logger.info("🎬 Begin syncing scenes")
                        let scenes: [Scene]
                        if sceneCount == 0 {
                            scenes = try await self.sceneRepository.getAllScenes { current, total in
                                Task { @MainActor in
                                    sceneProgress = Double(current) / Double(max(total, 1))
                                    updateCombinedProgress()
                                }
                            }
                        } else {
                            scenes = try await self.sceneRepository.syncNewScenes(progressHandler: { current, total in
                                Task { @MainActor in
                                    sceneProgress = Double(current) / Double(max(total, 1))
                                    updateCombinedProgress()
                                }
                            }, checkForDeletions: true)
                        }
                        
                        let newCount = scenes.count - sceneCount
                        let result = newCount > 0 ? "+\(newCount) scenes" : "scenes up to date"
                        return result
                    }
                }
                
                // 2. Sync Performers
                if syncPerformers {
                    group.addTask {
                        logger.info("👤 Begin syncing performers")
                        let performers: [Performer]
                        if performerCount == 0 {
                            performers = try await self.performerRepository.getAllPerformers { current, total in
                                Task { @MainActor in
                                    perfProgress = Double(current) / Double(max(total, 1))
                                    updateCombinedProgress()
                                }
                            }
                        } else {
                            performers = try await self.performerRepository.syncNewPerformers { current, total in
                                Task { @MainActor in
                                    perfProgress = Double(current) / Double(max(total, 1))
                                    updateCombinedProgress()
                                }
                            }
                        }
                        
                        let newCount = performers.count - performerCount
                        let result = newCount > 0 ? "+\(newCount) performers" : "performers up to date"
                        return result
                    }
                }
                
                // 3. Sync Tags
                if syncTags {
                    group.addTask {
                        logger.info("🏷️ Begin syncing tags")
                        let tags: [Tag]
                        if tagCount == 0 {
                            tags = try await self.tagRepository.getAllTags { current, total in
                                Task { @MainActor in
                                    tagProgress = Double(current) / Double(max(total, 1))
                                    updateCombinedProgress()
                                }
                            }
                        } else {
                            tags = try await self.tagRepository.syncNewTags { current, total in
                                Task { @MainActor in
                                    tagProgress = Double(current) / Double(max(total, 1))
                                    updateCombinedProgress()
                                }
                            }
                        }
                        
                        let newCount = tags.count - tagCount
                        let result = newCount > 0 ? "+\(newCount) tags" : "tags up to date"
                        return result
                    }
                }
                
                // Collect results
                var results: [String] = []
                for try await result in group {
                    results.append(result)
                }
                
                logger.info("✅ Synced: \(results.joined(separator: ", "))")
                self.message = "Synced \(results.joined(separator: ", "))"
            }
            
            progress = 1.0
            try? await Task.sleep(nanoseconds: 500_000_000)
            
        } catch is CancellationError {
            logger.info("⏭️ Prefetch cancelled")
        } catch {
            logger.error("❌ Failed to prefetch data: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to sync data: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    /// Full sync: fetches all data and removes deleted items
    func fullSync() async {
        logger.info("🔄 Full sync started (with deletion cleanup)")
        
        isSyncing = true
        progress = 0.0
        message = "Starting full sync..."
        
        do {
            // Track progress components
            var sceneProgress: Double = 0
            var perfProgress: Double = 0
            var tagProgress: Double = 0
            
            // Weights for total progress - Scenes are usually the bulk
            let sceneWeight: Double = 0.6
            let perfWeight: Double = 0.3
            let tagWeight: Double = 0.1
            
            let updateCombinedProgress = { @MainActor [weak self] (label: String) in
                guard let self = self else { return }
                let weighted = (sceneProgress * sceneWeight) + (perfProgress * perfWeight) + (tagProgress * tagWeight)
                self.progress = min(weighted, 1.0)
                self.message = label
            }
            
            try await withThrowingTaskGroup(of: String.self) { group in
                // 1. Full sync scenes
                group.addTask {
                    let result = try await self.sceneRepository.fullSync(progressHandler: { fetched, total in
                        Task { @MainActor in
                            sceneProgress = Double(fetched) / Double(max(total, 1))
                            updateCombinedProgress("Syncing scenes: \(fetched)/\(total)")
                        }
                    })
                    return result.removedCount > 0 ? 
                        "+\(result.scenes.count) scenes (-\(result.removedCount))" : 
                        "\(result.scenes.count) scenes"
                }
                
                // 2. Full sync performers
                group.addTask {
                    let result = try await self.performerRepository.fullSync(progressHandler: { fetched, total in
                        Task { @MainActor in
                            perfProgress = Double(fetched) / Double(max(total, 1))
                            updateCombinedProgress("Syncing performers: \(fetched)/\(total)")
                        }
                    })
                    return result.removedCount > 0 ? 
                        "+\(result.performers.count) performers (-\(result.removedCount))" : 
                        "\(result.performers.count) performers"
                }
                
                // 3. Full sync tags
                group.addTask {
                    let result = try await self.tagRepository.fullSync(progressHandler: { fetched, total in
                        Task { @MainActor in
                            tagProgress = Double(fetched) / Double(max(total, 1))
                            updateCombinedProgress("Syncing tags: \(fetched)/\(total)")
                        }
                    })
                    return result.removedCount > 0 ? 
                        "+\(result.tags.count) tags (-\(result.removedCount))" : 
                        "\(result.tags.count) tags"
                }
                
                // Collect results
                var results: [String] = []
                for try await result in group {
                    results.append(result)
                }
                
                progress = 1.0
                message = "Full sync complete"
                logger.info("✅ Full sync complete: \(results.joined(separator: ", "))")
            }
            
            // Brief delay for UI
            try? await Task.sleep(nanoseconds: 500_000_000)
            
        } catch {
            logger.error("❌ Full sync failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Full sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
}

