import Observation
import Foundation
import os

/// Manages performer-related operations for scenes.
@MainActor
class ScenePerformerManager {
    
    // MARK: - Dependencies
    
    private let performerRepository: any PerformerRepositoryProtocol
    private let stashDBRepository: StashDBRepositoryProtocol
    private let settings: SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(
        performerRepository: any PerformerRepositoryProtocol,
        stashDBRepository: StashDBRepositoryProtocol,
        settings: SettingsStoreProtocol
    ) {
        self.performerRepository = performerRepository
        self.stashDBRepository = stashDBRepository
        self.settings = settings
    }
    
    // MARK: - Performer Operations
    
    /// Searches StashDB for a performer to find their image/details.
    ///
    /// - Parameter name: The name of the performer to search for.
    /// - Returns: A `StashDBPerformer` with images and metadata, or `nil`.
    func fetchPerformerImages(name: String) async throws -> StashDBPerformer? {
        // Search StashDB using the configured endpoint
        let results = try await stashDBRepository.searchPerformers(
            term: name,
            endpoint: settings.stashDBUrl,
            apiKey: settings.stashDBApiKey
        )
        
        // Return first result (usually best match)
        return results.first
    }
    
    /// Creates a new performer in the system.
    ///
    /// - Parameters:
    ///   - name: The name of the performer.
    ///   - image: Optional base64 image or URL.
    ///   - details: Optional biography details.
    ///   - gender: Optional gender string.
    ///   - birth_date: Optional birth date YYYY-MM-DD.
    ///   - ethnicity: Optional ethnicity.
    ///   - country: Optional country.
    ///   - eye_color: Optional eye color.
    ///   - hair_color: Optional hair color.
    ///   - height: Optional height in cm.
    ///   - measurements: Optional measurements string (e.g. "36-24-36").
    ///   - breast_type: Optional breast type.
    ///   - career_start_year: Optional start year.
    ///   - career_end_year: Optional end year.
    ///   - tattoos: Optional tattoo description.
    ///   - piercings: Optional piercing description.
    /// - Returns: The ID of the created performer.
    func createPerformer(
        name: String,
        image: String?,
        details: String?,
        gender: String?,
        birth_date: String?,
        ethnicity: String?,
        country: String?,
        eye_color: String?,
        hair_color: String?,
        height: Int?,
        measurements: String?,
        breast_type: String?,
        career_start_year: Int?,
        career_end_year: Int?,
        tattoos: String?,
        piercings: String?
    ) async throws -> String {
        // Convert breast_type to fake_tits boolean string
        // StashDB uses "NATURAL", "FAKE", "NA" - convert to Yes/No for local Stash
        var fakeTitsStr: String? = nil
        if let breastType = breast_type?.uppercased() {
            if breastType.contains("FAKE") || breastType.contains("AUGMENTED") {
                fakeTitsStr = "Yes"
            } else if breastType.contains("NATURAL") {
                fakeTitsStr = "No"
            }
            // If "NA" or unknown, leave as nil
        }
        
        // Convert career years to career_length string format
        var careerLengthStr: String? = nil
        if let start = career_start_year, let end = career_end_year {
            careerLengthStr = "\(start)-\(end)"
        } else if let start = career_start_year {
            careerLengthStr = "\(start)-"
        } else if let end = career_end_year {
            careerLengthStr = "-\(end)"
        }
        
        let input = PerformerCreateInput(
            name: name,
            image: image,
            details: details,
            gender: gender,
            birthDate: birth_date,
            ethnicity: ethnicity,
            country: country,
            eyeColor: eye_color,
            hairColor: hair_color,
            height: height,
            measurements: measurements,
            fakeTits: fakeTitsStr,
            careerLength: careerLengthStr,
            tattoos: tattoos,
            piercings: piercings
        )
        
        let id = try await performerRepository.createPerformer(input: input)
        Logger.scenes.info("✅ Created performer \(name) with ID: \(id)")
        return id
    }
    
    /// Validates scraped performers and returns a set of performer names that don't exist in the system.
    ///
    /// - Parameter scrapedPerformers: The performers from the scrape result
    /// - Returns: Set of performer names that need to be created
    func validateScrapedPerformers(_ scrapedPerformers: [ScrapedPerformer]) async -> Set<String> {
        var missing = Set<String>()
        
        for performer in scrapedPerformers {
            do {
                // Search for the performer in the local database
                let result = try await performerRepository.getPerformers(
                    searchText: performer.name,
                    page: 1,
                    perPage: 5,
                    sortBy: .name,
                    sortDirection: "ASC",
                    forceRefresh: false
                )
                
                // Check if we have an exact match (case-insensitive)
                let hasExactMatch = result.performers.contains { p in
                    p.name?.lowercased() == performer.name.lowercased()
                }
                
                if !hasExactMatch {
                    // Performer doesn't exist, needs creation
                    missing.insert(performer.name)
                    Logger.scenes.info("⚠️ Performer '\(performer.name)' not found in system")
                }
            } catch {
                // If search fails, assume performer doesn't exist
                Logger.scenes.error("❌ Error searching for performer \(performer.name): \(error.localizedDescription)")
                missing.insert(performer.name)
            }
        }
        
        Logger.scenes.info("🔍 Validated \(scrapedPerformers.count) performers: \(missing.count) need creation")
        return missing
    }
}
