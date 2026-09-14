import Foundation
import os

/// Service responsible for synchronizing Whisparr data between the server and local database.
///
/// This service handles both full and incremental synchronization, managing data consistency
/// and reporting progress during sync operations.
class WhisparrSyncService: @unchecked Sendable {
    private let apiClient: WhisparrClientProtocol
    private let cacheService: WhisparrCacheService
    private let fetchService: WhisparrFetchService
    private let settings: any SettingsStoreProtocol
    
    // Guard against concurrent sync calls
    private let syncGuard = FetchGuard()
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSyncService")
    
    init(apiClient: WhisparrClientProtocol, cacheService: WhisparrCacheService, fetchService: WhisparrFetchService, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.cacheService = cacheService
        self.fetchService = fetchService
        self.settings = settings
    }
    
    
    // MARK: - Sync Operations
    
    /// Synchronizes scenes from the remote Whisparr server to the local database.
    ///
    /// This method fetches all scenes from the API, updates the local cache, and removes any local scenes
    /// that are no longer present on the server.
    ///
    /// - Parameter progressHandler: A closure to report progress (0.0 to 1.0) and a description.
    /// - Returns: An array of the freshly synced `WhisparrScene` objects.
    /// - Throws: `RepositoryError` if configuration is invalid or network/database errors occur.
    func syncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene] {
        try settings.validateWhisparrConfiguration()
        
        // Prevent concurrent syncs
        let started = await syncGuard.beginIfPossible()
        if !started {
            logger.info("⏭️ Already syncing Whisparr, returning cached data")
            return try await cacheService.getCachedScenes()
        }
        
        defer {
            Task { await syncGuard.end() }
        }
        
        logger.info("🔄 Syncing movies from Whisparr...")
        
        // Report initial progress
        if let handler = progressHandler {
            await handler(0.3, "Fetching movies from Whisparr...")
        }
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        // Fetch all movies from API
        let movies = try await apiClient.fetchScenes(
            url: settingsStore.whisparrUrl,
            apiKey: settingsStore.whisparrApiKey,
            since: nil
        )
        
        logger.info("📦 Received \(movies.count) movies from Whisparr")
        
        // Report save progress
        if let handler = progressHandler {
            await handler(0.6, "Saving \(movies.count) movies...")
        }
        
        // Save to database
        try await cacheService.saveScenes(movies)
        
        // Clean up deleted movies
        let movieIds = Set(movies.map { $0.id })
        try await cacheService.removeDeletedScenes(keeping: movieIds)
        
        // Report completion
        if let handler = progressHandler {
            await handler(0.8, "Loading movies...")
        }
        
        logger.info("✅ Whisparr sync complete")
        
        return movies
    }
    
    /// Incrementally synchronizes scenes from Whisparr by scanning the global history.
    ///
    /// This method retrieves the history of recent events from the API and identifies scenes that have
    /// been added, updated, or deleted since the last successful sync.
    ///
    /// - Parameter progressHandler: A closure to report progress and current activity.
    /// - Returns: An array of `WhisparrScene` objects that were updated or added.
    /// - Throws: `RepositoryError` if configuration is invalid or sync fails.
    func incrementalSyncScenes(progressHandler: (@MainActor (Double, String) -> Void)?) async throws -> [WhisparrScene] {
        try settings.validateWhisparrConfiguration()
        
        // 1. Get last sync date
        guard let lastSyncDate = try await cacheService.getLastSyncDate() else {
            logger.info("❓ No last sync date found, falling back to full sync")
            return try await syncScenes(progressHandler: progressHandler)
        }
        
        
        // Prevent concurrent syncs
        let started = await syncGuard.beginIfPossible()
        if !started {
            logger.info("⏭️ Already syncing Whisparr, returning cached data")
            return try await cacheService.getCachedScenes()
        }
        
        defer {
            Task { await syncGuard.end() }
        }
        
        logger.info("🔄 Starting incremental Whisparr sync since \(lastSyncDate, privacy: .public)...")
        
        if let handler = progressHandler {
            await handler(0.1, "Checking for changes since \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))...")
        }
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        // 2. Scan history for changes
        var movieIdsToUpdate = Set<Int>()
        var movieIdsToDelete = Set<Int>()
        
        var page = 1
        let pageSize = 50
        var hasMorePages = true
        var encounteredOldRecord = false
        
        // Format for parsing ISO8601 strings in history (including fractional seconds)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        
        while hasMorePages {
            logger.debug("📜 Fetching global history page \(page) from Whisparr...")
            
            let response = try await apiClient.fetchHistory(
                 page: page,
                 pageSize: pageSize,
                 sortKey: "date",
                 sortDirection: "descending",
                 url: settingsStore.whisparrUrl,
                 apiKey: settingsStore.whisparrApiKey
            )
            
            let records = response.records
            if records.isEmpty {
                logger.debug("Empty history page received")
                break
            }
            
            
            for record in records {
                guard let recordDate = dateFormatter.date(from: record.date) else {
                    logger.warning("⚠️ Failed to parse history record date: \(record.date, privacy: .public)")
                    continue
                }
                
                // Stop if we hit a record older than or equal to our last sync
                if recordDate <= lastSyncDate {
                    encounteredOldRecord = true
                    logger.debug("Found record from \(recordDate) which is before \(lastSyncDate). Stopping history scan.")
                    break
                }
                
                // Process the change
                if record.eventType == "deleted" {
                    movieIdsToDelete.insert(record.movieId)
                    movieIdsToUpdate.remove(record.movieId)
                    logger.debug("📍 Found deletion for movie ID: \(record.movieId)")
                } else {
                    // For any other event (grabbed, imported, etc), we want to refresh the movie metadata
                    if !movieIdsToDelete.contains(record.movieId) {
                        movieIdsToUpdate.insert(record.movieId)
                        logger.debug("📍 Found update for movie ID: \(record.movieId) (event: \(record.eventType))")
                    }
                }
            }
            
            if encounteredOldRecord || records.count < pageSize {
                hasMorePages = false
            } else {
                page += 1
                // Safety break for long-lost syncs
                if page > 20 { 
                    logger.warning("⚠️ Scanned 20 pages of history without finding last sync date. Stopping.")
                    hasMorePages = false
                }
            }
        }
        
        logger.info("📊 Changes found: \(movieIdsToUpdate.count) updates, \(movieIdsToDelete.count) deletions")
        
        // 3. Apply changes
        var updatedMovies: [WhisparrScene] = []
        
        // Handle deletions
        for id in movieIdsToDelete {
            logger.info("🗑️ Deleting movie \(id) from local cache")
            try await cacheService.deleteScene(id: id)
        }
        
        // Handle updates/additions
        let totalUpdates = movieIdsToUpdate.count
        var currentUpdate = 0
        
        
        for id in movieIdsToUpdate {
            currentUpdate += 1
            let progress = 0.2 + (Double(currentUpdate) / Double(max(1, totalUpdates)) * 0.7)
            
            if let handler = progressHandler {
                await handler(progress, "Updating movie \(currentUpdate)/\(totalUpdates)...")
            }
            
            do {
                logger.info("⏬ Refreshing movie \(id) (\(currentUpdate)/\(totalUpdates))")
                
                let movie = try await apiClient.fetchScene(
                    id: id,
                    url: settingsStore.whisparrUrl,
                    apiKey: settingsStore.whisparrApiKey
                )
                
                // Only keep if it's a scene
                if movie.itemType == "scene" {
                    updatedMovies.append(movie)
                    try await cacheService.saveScenes([movie])
                    logger.debug("✅ Updated movie: \(movie.title, privacy: .public)")
                } else {
                    logger.debug("⏭️ Skipping updated movie \(id) - not a scene (itemType: \(movie.itemType))")
                }
            } catch {
                logger.error("❌ Failed to update movie \(id): \(error.localizedDescription, privacy: .public)")
                // Continue with other updates
            }
        }
        
        // 4. Update sync timestamp
        let now = Date()
        try await cacheService.updateLastSyncDate(now)
        
        logger.info("✅ Incremental Whisparr sync complete. \(updatedMovies.count) items updated, \(movieIdsToDelete.count) deleted.")
        
        if let handler = progressHandler {
            await handler(1.0, "Sync complete")
        }
        
        return updatedMovies
    }
    
    /// Triggers a refresh of the scene data by performing a sync.
    ///
    /// - Throws: An error if sync fails.
    func refreshScenes() async throws {
        let _ = try await syncScenes(progressHandler: nil)
    }
}
