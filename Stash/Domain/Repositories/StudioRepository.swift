import Foundation
import os
import GRDB

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StudioRepository")

class StudioRepository: BaseRepository, StudioRepositoryProtocol, @unchecked Sendable {
    
    private let cacheService: StudioCacheService
    private let fetchService: StudioFetchService
    private let syncService: StudioSyncService
    
    override init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        imagePrefetchManager: ImagePrefetchService
    ) {
        self.cacheService = StudioCacheService(database: database)
        self.fetchService = StudioFetchService(apiClient: apiClient, database: database, settings: settings, cacheService: cacheService)
        self.syncService = StudioSyncService(apiClient: apiClient, database: database, settings: settings, cacheService: cacheService, fetchService: fetchService)
        
        super.init(apiClient: apiClient, database: database, settings: settings, imagePrefetchManager: imagePrefetchManager)
    }
    
    func getStudios(
        searchText: String,
        page: Int,
        perPage: Int,
        sortBy: String,
        sortDirection: String,
        forceRefresh: Bool
    ) async throws -> (studios: [Studio], count: Int) {
        return try await fetchService.getStudios(
            searchText: searchText,
            page: page,
            perPage: perPage,
            sortBy: sortBy,
            sortDirection: sortDirection,
            forceRefresh: forceRefresh
        )
    }
    
    func getStudio(id: String, forceRefresh: Bool) async throws -> Studio? {
        return try await fetchService.getStudio(id: id, forceRefresh: forceRefresh)
    }
    
    func syncNewStudios(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Studio] {
        return try await syncService.syncNewStudios(progressHandler: progressHandler)
    }
    
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (studios: [Studio], removedCount: Int) {
        return try await syncService.fullSync(progressHandler: progressHandler)
    }
    
    // MARK: - Protocol Conformance
    
    func getAll() async throws -> [Studio] {
        return try await cacheService.getCachedStudios()
    }
    
    func getById(_ id: String) async throws -> Studio? {
        return try await getStudio(id: id, forceRefresh: false)
    }
    
    func refresh() async throws {
        _ = try await syncNewStudios(progressHandler: nil)
    }
}
