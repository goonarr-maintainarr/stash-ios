import Foundation
import Combine
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "HomeStashDBManager")

/// Manages StashDB favorites loading and caching for home page.
@MainActor
class HomeStashDBManager {
    
    // MARK: - Dependencies
    
    private let stashDBRepository: StashDBRepositoryProtocol
    private let settings: SettingsStore
    
    // MARK: - Initialization
    
    init(stashDBRepository: StashDBRepositoryProtocol, settings: SettingsStore) {
        self.stashDBRepository = stashDBRepository
        self.settings = settings
        logger.debug("🔧 HomeStashDBManager initialized")
    }
    
    // MARK: - StashDB Favorites
    
    /// Loads StashDB favorites category from cache instantly if available.
    func loadCachedFavoritesCategory() async -> SceneCategory? {
        guard !settings.stashDBApiKey.isEmpty else {
            logger.info("⏭️ No StashDB API key configured")
            return nil
        }
        
        logger.info("📦 Loading StashDB favorites from cache...")
        
        if let cachedScenes = await stashDBRepository.getCachedFavoriteScenes(), !cachedScenes.isEmpty {
            var category = SceneCategory(
                title: "Scenes from StashDB Favorites",
                sortType: .date,
                sortDirection: "DESC",
                count: cachedScenes.count,
                type: .stashDBScenes
            )
            category.stashDBScenes = cachedScenes
            logger.info("✅ Loaded StashDB favorites from cache: \(cachedScenes.count) scenes")
            return category
        }
        
        logger.info("⚠️ No cached StashDB favorites available")
        return nil
    }
    
    /// Builds StashDB favorites category by fetching from API.
    func buildStashDBFavoritesCategory() async -> SceneCategory? {
        guard !settings.stashDBApiKey.isEmpty else {
            logger.info("⏭️ No StashDB API key configured, skipping favorites category")
            return nil
        }
        
        logger.info("🔄 Fetching StashDB favorites from API...")
        
        do {
            // Use repository to fetch and filter scenes
            guard let filteredScenes = try await stashDBRepository.fetchFavoriteScenesFromStashDB(
                excludeVR: settings.excludeVRFromStashDB,
                excludeCompilations: settings.excludeCompilationsFromStashDB,
                excludeOwned: true
            ), !filteredScenes.isEmpty else {
                logger.info("⏭️ No favorite scenes available or all already owned")
                return nil
            }
            
            logger.info("✅ Fetched \(filteredScenes.count) StashDB favorite scenes")
            
            // Save to cache for next launch
            await stashDBRepository.cacheFavoriteScenes(filteredScenes)
            logger.info("💾 Cached \(filteredScenes.count) StashDB favorite scenes")
            
            // Create category with filtered StashDB scenes
            var category = SceneCategory(
                title: "Scenes from StashDB Favorites",
                sortType: .date,
                sortDirection: "DESC",
                count: filteredScenes.count,
                type: .stashDBScenes
            )
            // Store all filtered scenes, but the carousel will only show first 10
            category.stashDBScenes = filteredScenes
            
            return category
            
        } catch {
            logger.error("❌ Failed to build StashDB favorites category: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// Updates or inserts StashDB favorites category in the categories array.
    func updateFavoritesCategory(_ category: SceneCategory, in categories: inout [SceneCategory]) {
        logger.info("🔄 Updating StashDB favorites category with \(category.stashDBScenes.count) scenes")
        
        // Try to update existing category
        if let index = categories.firstIndex(where: { $0.title == "Scenes from StashDB Favorites" }) {
            categories[index] = category
            logger.info("✅ Updated existing StashDB favorites category at index \(index)")
        } else {
            // Insert after sort-based categories (position 5)
            let insertionIndex = min(5, categories.count)
            categories.insert(category, at: insertionIndex)
            logger.info("✅ Inserted StashDB favorites category at index \(insertionIndex)")
        }
    }
    
    /// Removes StashDB favorites placeholder if no favorites found.
    func removePlaceholderIfNeeded(from categories: inout [SceneCategory]) {
        logger.info("🗑️ Removing StashDB favorites placeholder")
        categories.removeAll { category in
            category.title == "Scenes from StashDB Favorites" && category.stashDBScenes.isEmpty
        }
    }
}
