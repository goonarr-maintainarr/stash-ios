import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerScrapeService")

/// Service responsible for performer scraping operations.
///
/// Handles:
/// - Searching for performers
/// - Fetching StashBox configuration
class PerformerScrapeService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    let settings: any SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        settings: any SettingsStoreProtocol
    ) {
        self.apiClient = apiClient
        self.settings = settings
    }
    
    // MARK: - Public Methods
    
    /// Searches for performers using a search term.
    func searchPerformer(term: String) async throws -> [PerformerScrapeResult] {
        let url = try settings.validateStashConfiguration()
        
        logger.info("🔍 Searching for performer: \(term)")
        
        let query = StashQueries.searchPerformer(term: term)
        
        struct SearchResult: Decodable {
            let searchPerformer: [PerformerScrapeResult]?
        }
        
        let result: SearchResult = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        let results = result.searchPerformer ?? []
        logger.info("📦 Found \(results.count) search results")
        
        return results
    }
    
    /// Fetches the StashBox configuration from the API.
    func fetchStashBoxConfiguration() async throws -> StashBoxConfiguration {
        let url = try settings.validateStashConfiguration()
        
        logger.info("⚙️ Fetching StashBox configuration")
        
        let query = StashQueries.configuration
        
        struct ConfigResult: Decodable {
            let configuration: StashBoxConfiguration
        }
        
        let result: ConfigResult = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        logger.info("✅ Fetched StashBox configuration")
        
        return result.configuration
    }
    
}

