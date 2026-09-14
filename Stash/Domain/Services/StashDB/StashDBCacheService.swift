import Foundation
import os

/// Service responsible for caching StashDB data.
///
/// This service handles all cache operations for StashDB data,
/// particularly for favorite scenes.
class StashDBCacheService: @unchecked Sendable {
    private let stashDatabase: StashDatabase
    private let settings: SettingsStoreProtocol
    
    private static let favoritesCacheKey = "stash_db_favorites"
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBCacheService")
    
    init(stashDatabase: StashDatabase, settings: SettingsStoreProtocol) {
        self.stashDatabase = stashDatabase
        self.settings = settings
    }
    
    
    // MARK: - Cache Operations
    
    /// Retrieves cached favorite scenes from the database.
    func getCachedFavoriteScenes() async -> [StashDBScene]? {
        
        do {
            guard let jsonString = try await stashDatabase.fetchCacheMetadata(key: Self.favoritesCacheKey),
                  let data = jsonString.data(using: .utf8) else {
                return nil
            }
            
            let scenes = try JSONDecoder().decode([StashDBScene].self, from: data)
            return scenes
        } catch {
            logger.error("❌ Failed to load StashDB favorites cache: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Caches favorite scenes to the database.
    func cacheFavoriteScenes(_ scenes: [StashDBScene]) async {
        
        Task.detached(priority: .background) { [stashDatabase, logger] in
            do {
                let data = try JSONEncoder().encode(scenes)
                if let jsonString = String(data: data, encoding: .utf8) {
                    try await stashDatabase.saveCacheMetadata(key: Self.favoritesCacheKey, value: jsonString)
                }
            } catch {
                logger.error("❌ Failed to save StashDB favorites cache: \(error.localizedDescription)")
            }
        }
    }
}
