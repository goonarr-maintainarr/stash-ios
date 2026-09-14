import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StudioFetchService")

/// Service responsible for fetching Studio data from the API and coordinating with the cache.
class StudioFetchService: @unchecked Sendable {
    
    private let apiClient: StashClientProtocol
    private let database: StashDatabase
    private let settings: SettingsStoreProtocol
    private let cacheService: StudioCacheService
    
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: SettingsStoreProtocol,
        cacheService: StudioCacheService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.cacheService = cacheService
    }
    
    // MARK: - API Fetching
    
    func getStudios(
        searchText: String,
        page: Int,
        perPage: Int,
        sortBy: String,
        sortDirection: String,
        forceRefresh: Bool
    ) async throws -> (studios: [Studio], count: Int) {
        
        // If not forcing refresh and simple query, try cache first (optional optimization)
        // For list views, often we fetch from API to get latest.
        
        let url = try settings.validateStashConfiguration()
        
        let query = StashQueries.findStudios(
            searchText: searchText,
            page: page,
            perPage: perPage,
            sort: sortBy,
            direction: sortDirection
        )
        
        let result: FindStudiosResultDTO = try await fetch(query: query, url: url)
        let (studios, count) = result.findStudios.toDomain()
        
        // Cache the page
        try await cacheService.cacheStudios(studios)
        
        return (studios, count)
    }
    
    func getStudio(id: String, forceRefresh: Bool) async throws -> Studio? {
        if !forceRefresh, let cached = try await cacheService.getCachedStudio(id: id) {
            return cached
        }
        
        let url = try settings.validateStashConfiguration()
        let query = StashQueries.findStudio(id: id)
        
        let result: FindStudioResultDTO = try await fetch(query: query, url: url)
        
        if let studio = result.findStudio?.toDomain() {
            try await cacheService.cacheStudios([studio])
            return studio
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    private func fetch<T: Decodable>(query: String, url: URL) async throws -> T {
        return try await apiClient.fetch(
            query: query,
            variables: nil,
            url: url,
            apiKey: settings.apiKey
        )
    }
}
