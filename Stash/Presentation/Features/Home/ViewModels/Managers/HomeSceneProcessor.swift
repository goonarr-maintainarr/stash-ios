import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "HomeSceneProcessor")

/// Manages scene filtering, sorting, and detail prefetching for home categories.
@Observable
class HomeSceneProcessor: @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let sceneRepository: any SceneRepositoryProtocol
    private let settings: SettingsStore
    
    // MARK: - Initialization
    
    init(sceneRepository: any SceneRepositoryProtocol, settings: SettingsStore) {
        self.sceneRepository = sceneRepository
        self.settings = settings
        logger.debug("🔧 HomeSceneProcessor initialized")
    }
    
    // MARK: - Scene Filtering & Sorting
    
    /// Filter and sort scenes from cache for a given category.
    nonisolated func filterAndSortScenes(_ scenes: [Scene], for category: SceneCategory, limit: Int) -> [Scene] {
        var filtered = scenes
        
        // Filter by tags if specified
        if let tagIds = category.tagIds, !tagIds.isEmpty {
             logger.debug("🔎 Processing category '\(category.title)' with tags: \(tagIds)")
            
            filtered = scenes.filter { scene in
                guard let sceneTags = scene.tags, !sceneTags.isEmpty else {
                    return false
                }
                let sceneTagIds = Set(sceneTags.map { $0.id })
                // Check if scene has ANY of the required tags
                let hasTag = !Set(tagIds).isDisjoint(with: sceneTagIds)
                return hasTag
            }
            logger.debug("   📝 Found \(filtered.count) scenes for '\(category.title)' out of \(scenes.count) total scenes")
        }
        
        // Sort based on category type
        let sorted: [Scene]
        switch category.sortType {
        case .random:
            sorted = filtered.shuffled()
        case .createdAt:
            sorted = filtered.sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
        case .date:
            sorted = filtered.sorted { ($0.date ?? "") > ($1.date ?? "") }
        case .rating:
            sorted = filtered.sorted { ($0.rating100 ?? 0) > ($1.rating100 ?? 0) }
        case .oCounter:
            sorted = filtered.sorted { ($0.o_counter ?? 0) > ($1.o_counter ?? 0) }
        case .updatedAt:
            sorted = filtered.sorted { ($0.updated_at ?? "") > ($1.updated_at ?? "") }
        }
        
        let result = Array(sorted.prefix(limit))
        return result
    }
    
    
}
