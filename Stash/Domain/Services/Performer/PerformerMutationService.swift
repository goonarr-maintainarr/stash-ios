import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerMutationService")

/// Service responsible for performer mutation operations.
///
/// Handles:
/// - Creating new performers
/// - Updating existing performers  
/// - Deleting performers
class PerformerMutationService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    private let database: StashDatabase
    let settings: any SettingsStoreProtocol
    private let fetchService: PerformerFetchService
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: any SettingsStoreProtocol,
        fetchService: PerformerFetchService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.fetchService = fetchService
    }
    
    // MARK: - Public Methods
    
    /// Creates a new performer in the remote system.
    func createPerformer(input: PerformerCreateInput) async throws -> String {
        let url = try settings.validateStashConfiguration()
        
        logger.info("➕ Creating performer: \(input.name)")
        
        let query = StashQueries.performerCreate(
            name: input.name,
            image: input.image,
            details: input.details,
            gender: input.gender,
            birth_date: input.birthDate,
            ethnicity: input.ethnicity,
            country: input.country,
            eye_color: input.eyeColor,
            hair_color: input.hairColor,
            height: input.height,
            measurements: input.measurements,
            fake_tits: input.fakeTits,
            career_length: input.careerLength,
            tattoos: input.tattoos,
            piercings: input.piercings
        )
        
        struct CreateResult: Decodable {
            struct Payload: Decodable {
                let id: String
            }
            let performerCreate: Payload?
        }
        
        let result: CreateResult = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        guard let id = result.performerCreate?.id else {
            throw AppError.stashAPI(.invalidResponse)
        }
        
        logger.info("✅ Created performer with ID: \(id)")
        
        return id
    }
    
    /// Updates an existing performer in the remote system.
    func updatePerformer(input: PerformerUpdateInput) async throws -> String {
        let url = try settings.validateStashConfiguration()
        
        logger.info("🔄 Updating performer: \(input.id)")
        
        let inputDict: [String: Any?] = [
            "id": input.id,
            "name": input.name,
            "disambiguation": input.disambiguation as Any?,
            "image": input.image as Any?,
            "details": input.details as Any?,
            "gender": input.gender as Any?,
            "birthdate": input.birthDate as Any?,
            "death_date": input.deathDate as Any?,
            "ethnicity": input.ethnicity as Any?,
            "country": input.country as Any?,
            "eye_color": input.eyeColor as Any?,
            "hair_color": input.hairColor as Any?,
            "height_cm": input.height as Any?,
            "weight": input.weight as Any?,
            "measurements": input.measurements as Any?,
            "fake_tits": input.breastType as Any?,
            "career_length": input.careerLength as Any?,
            "career_start_year": input.careerStartYear as Any?,
            "career_end_year": input.careerEndYear as Any?,
            "tattoos": input.tattoos as Any?,
            "piercings": input.piercings as Any?,
            "alias_list": input.aliasList as Any?,
            "favorite": input.favorite as Any?,
            "urls": input.urls as Any?,
            "rating100": input.rating100 as Any?,
            "penis_length": input.penisLength as Any?,
            "circumcised": input.circumcised as Any?
        ]
        
        let cleanedInput = inputDict.compactMapValues { $0 }
        
        struct UpdateResult: Decodable {
            struct Payload: Decodable {
                let id: String
            }
            let performerUpdate: Payload?
        }
        
        let result: UpdateResult = try await fetchWithErrorWrapping(
            query: StashQueries.performerUpdate,
            variables: ["input": cleanedInput],
            url: url
        )
        
        guard let id = result.performerUpdate?.id else {
            throw AppError.stashAPI(.invalidResponse)
        }
        
        logger.info("✅ Updated performer: \(id)")
        
        // Refresh from server and cache
        if let updatedPerformer = try await fetchService.getPerformer(id: id) {
            do {
                try await database.savePerformers([updatedPerformer])
            } catch {
            }
        }
        
        return id
    }
    
    /// Deletes a performer from the remote system and local cache.
    func deletePerformer(id: String) async throws -> Bool {
        let url = try settings.validateStashConfiguration()
        
        logger.info("🗑️ Deleting performer: \(id)")
        
        let mutation = StashQueries.performerDestroy(id: id)
        
        struct PerformerDestroyResult: Decodable {
            let performerDestroy: Bool
        }
        
        let result: PerformerDestroyResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
        
        if result.performerDestroy {
            // Remove from local cache
            do {
                try await database.deletePerformerById(id: id)
                logger.info("✅ Deleted performer \(id) from API and cache")
            } catch {
            }
            return true
        } else {
            return false
        }
    }
    
}

