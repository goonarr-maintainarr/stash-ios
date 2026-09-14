import Foundation
import Combine

/// Protocol for Performer repository operations
protocol PerformerRepositoryProtocol: Repository where Entity == Performer {
    /// Fetch performers with pagination and filtering
    func getPerformers(
        searchText: String,
        page: Int,
        perPage: Int,
        sortBy: PerformerSortType,
        sortDirection: String,
        studioId: String?,
        forceRefresh: Bool
    ) async throws -> PerformerRepositoryResult
    
    /// Fetch a single performer by ID, optionally include scenes
    func getPerformer(id: String, forceRefresh: Bool) async throws -> (performer: Performer, scenes: [Scene])?
    
    /// Fetch all scenes for a specific performer
    func getPerformerScenes(performerId: String) async throws -> [Scene]
    
    /// Fetch all performers (for client-side sorting)
    func getAllPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer]
    
    /// Fetch only new/updated performers incrementally
    func syncNewPerformers(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> [Performer]
    
    /// Syncs only performers modified since the last local update (Smart Sync)
    func syncChangedPerformers() async throws -> [Performer]
    
    /// Full sync: fetch all performers and remove deleted ones
    func fullSync(progressHandler: (@MainActor (Int, Int) -> Void)?) async throws -> (performers: [Performer], removedCount: Int)
    
    /// Get performers from cache
    func getCachedPerformers() async throws -> [Performer]
    
    /// Get performer count from cache
    func getCachedPerformerCount() async throws -> Int
    
    /// Get a single performer by ID from cache (efficient lookup)
    func getCachedPerformerById(_ id: String) async throws -> Performer?
    
    /// Check if cache should be refreshed
    func shouldRefreshCache() async throws -> Bool
    
    /// Get last sync date
    func getLastSyncDate() async throws -> Date?
    
    /// Prefetch images for performers
    func prefetchImages(for performers: [Performer], count: Int) async
    
    // MARK: - Scraping & Creation
    
    /// Search for performer details (scraping)
    func searchPerformer(term: String) async throws -> [PerformerScrapeResult]
    
    /// Create a new performer
    func createPerformer(input: PerformerCreateInput) async throws -> String
    
    /// Delete a performer
    func deletePerformer(id: String) async throws -> Bool
    
    /// Update an existing performer
    func updatePerformer(input: PerformerUpdateInput) async throws -> String
    
    /// Fetch StashBox configuration
    func fetchStashBoxConfiguration() async throws -> StashBoxConfiguration
}

extension PerformerRepositoryProtocol {
    func getPerformers(
        searchText: String = "",
        page: Int = 1,
        perPage: Int = 20,
        sortBy: PerformerSortType = .name,
        sortDirection: String = "ASC",
        studioId: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> PerformerRepositoryResult {
        return try await getPerformers(
            searchText: searchText,
            page: page,
            perPage: perPage,
            sortBy: sortBy,
            sortDirection: sortDirection,
            studioId: studioId,
            forceRefresh: forceRefresh
        )
    }
}

/// Input for updating a performer
struct PerformerUpdateInput {
    let id: String
    let name: String
    let disambiguation: String?
    let image: String?
    let details: String?
    let gender: String?
    let birthDate: String?
    let deathDate: String?
    let ethnicity: String?
    let country: String?
    let eyeColor: String?
    let hairColor: String?
    let height: Int?
    let weight: Int?
    let measurements: String?
    let breastType: String? // fake_tits
    let careerLength: String?
    let careerStartYear: Int?
    let careerEndYear: Int?
    let tattoos: String?
    let piercings: String?
    let aliasList: [String]?
    let urls: [String]?
    let rating100: Int?
    let favorite: Bool?
    let penisLength: Double?
    let circumcised: String?
}

/// StashBox configuration result
struct StashBoxConfiguration: Decodable {
    struct Defaults: Decodable {
        let exclude_vr: Bool?
        let exclude_slr: Bool?
    }
    struct Interface: Decodable {
        let wallShowCard: Bool?
    }
    struct General: Decodable {
        let stashBoxes: [StashBoxEndpoint]?
    }
    struct StashBoxEndpoint: Decodable {
        let endpoint: String
        let api_key: String
        let name: String?
    }
    
    let defaults: Defaults?
    let interface: Interface?
    let general: General?
}

/// Result of a performer fetch operation
struct PerformerRepositoryResult {
    let performers: [Performer]
    let totalCount: Int
    let hasMore: Bool
    let source: DataSource
}

/// Input for creating a performer in local Stash.
/// Note: Uses fake_tits (not breast_type) and career_length (not career years)
struct PerformerCreateInput {
    let name: String
    let image: String?
    let details: String?
    let gender: String?
    let birthDate: String?
    let ethnicity: String?
    let country: String?
    let eyeColor: String?
    let hairColor: String?
    let height: Int?
    let measurements: String?
    let fakeTits: String?
    let careerLength: String?
    let tattoos: String?
    let piercings: String?
}

/// Result from searchPerformer query
struct PerformerScrapeResult: Decodable, Sendable {
    let name: String
    let url: String?
    let twitter: String?
    let instagram: String?
    let birth_date: String?
    let ethnicity: String?
    let country: String?
    let eye_color: String?
    let hair_color: String?
    let height: String? // Stash might return string or int, usually string from scrapers? Schema says string?
    let measurements: Measurements? // Or string? 
    let cup_size: String?
    let band_size: Int?
    let breast_type: String?
    let career_start_year: Int?
    let career_end_year: Int?
    let tattoos: [BodyMarking]?
    let piercings: [BodyMarking]?
    let images: [ScrapedImage]?
    
    struct Measurements: Decodable, Sendable {
        let cup_size: String?
        let band_size: Int?
        let waist: Int?
        let hip: Int?
    }
    
    struct BodyMarking: Decodable, Sendable {
        let location: String?
        let description: String?
    }
    
    struct ScrapedImage: Decodable, Sendable {
        let url: String
    }
    
    var allImageUrls: [String] {
        return images?.map { $0.url } ?? []
    }
}
