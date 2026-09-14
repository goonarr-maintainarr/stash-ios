import Foundation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "HomeCategoryBuilder")

/// Manages building and populating home page categories.
class HomeCategoryBuilder: @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let tagRepository: any TagRepositoryProtocol
    private let settings: SettingsStore
    
    // MARK: - Initialization
    
    init(tagRepository: any TagRepositoryProtocol, settings: SettingsStore) {
        self.tagRepository = tagRepository
        self.settings = settings
        logger.debug("🔧 HomeCategoryBuilder initialized")
    }
    
    // MARK: - Category Building
    
    // MARK: - Category Building
    
    /// Builds sort-based categories (Recently Added, Top Rated, etc.) based on enabled settings.
    func buildSortBasedCategories() async -> [SceneCategory] {
        var categories: [SceneCategory] = []
        
        if await settings.showRandomCategory {
            categories.append(SceneCategory(title: "Random", sortType: .random))
        }
        if await settings.showRecentlyAddedCategory {
            categories.append(SceneCategory(title: "Recently Added", sortType: .createdAt))
        }
        if await settings.showRecentlyReleasedCategory {
            categories.append(SceneCategory(title: "Recently Released", sortType: .date))
        }
        if await settings.showTopRatedCategory {
            categories.append(SceneCategory(title: "Top Rated", sortType: .rating))
        }
        if await settings.showMostViewedCategory {
            categories.append(SceneCategory(title: "Most Viewed", sortType: .oCounter))
        }
        
        return categories
    }
    
    /// Builds tag-based categories from followed tags.
    func buildTagCategories() async throws -> [SceneCategory] {
        let followedTagIds = await settings.followedTagIds
        guard !followedTagIds.isEmpty else { return [] }
        
        do {
            // Load all tags from cache
            let allTags = try await tagRepository.getCachedTags() // This is fast for reasonable tag counts
            let followedIdSet = Set(followedTagIds)
            
            // Filter and map directly
            return allTags
                .filter { followedIdSet.contains($0.id) }
                .map { tag in
                    SceneCategory(
                        title: tag.name,
                        sortType: .date,
                        tagIds: [tag.id],
                        count: tag.scene_count
                    )
                }
        } catch {
            logger.error("❌ Failed to load tags for categories: \(error.localizedDescription)")
            throw AppError.repository(.syncFailed("Failed to load tags"))
        }
    }
    
    /// Builds a placeholder StashDB favorites category.
    func buildStashDBPlaceholderCategory() async -> SceneCategory? {
        let apiKey = await settings.stashDBApiKey
        guard !apiKey.isEmpty else { return nil }
        
        return SceneCategory(
            title: "Scenes from StashDB Favorites",
            sortType: .date,
            sortDirection: "DESC",
            count: 0,
            type: .stashDBScenes
        )
    }
}
