import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneMutationService")

/// Service responsible for scene mutations (updates, deletions).
///
/// Handles all write operations including:
/// - Rating updates
/// - O-counter increments
/// - Title/details updates
/// - Scene deletion
/// - History management
class SceneMutationService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    private let database: StashDatabase
    let settings: any SettingsStoreProtocol
    private let fetchService: SceneFetchService
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        database: StashDatabase,
        settings: any SettingsStoreProtocol,
        fetchService: SceneFetchService
    ) {
        self.apiClient = apiClient
        self.database = database
        self.settings = settings
        self.fetchService = fetchService
    }
    
    // MARK: - Public Methods
    
    /// Increments the "O-Counter" (orgasm counter) for a scene.
    func incrementOCounter(for sceneId: String, currentCount: Int?) async throws -> Scene {
        let url = try settings.validateStashConfiguration()
        
        let mutation = StashQueries.sceneIncrementO(id: sceneId)
        
        struct SceneIncrementOResult: Decodable {
            let sceneIncrementO: Int
        }
        
        let _: SceneIncrementOResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
        
        // Refetch the scene to get the updated o_history array
        // (the incrementO mutation only returns the counter, not the full history)
        guard let updatedScene = try await fetchService.getScene(id: sceneId, forceRefresh: true) else {
            throw AppError.notFound("Scene")
        }
        
        // Update both list and details cache
        try await database.saveScenes([updatedScene])
        try await database.saveSceneDetails(updatedScene)
        
        // Post notification to update other views (e.g., home page)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sceneUpdated,
                object: nil,
                userInfo: ["id": sceneId, "source": "incrementOCounter"]
            )
        }
        
        return updatedScene
    }
    
    /// Updates the star rating of a scene.
    func updateRating(for sceneId: String, rating: Int) async throws -> Scene {
        let url = try settings.validateStashConfiguration()
        
        let ratingValue = rating == 0 ? nil : rating
        let mutation = StashQueries.sceneUpdate(id: sceneId, rating100: ratingValue)
        
        struct SceneUpdateResult: Decodable {
            struct SceneUpdate: Decodable {
                let id: String
                let rating100: Int?
            }
            let sceneUpdate: SceneUpdate
        }
        
        let _: SceneUpdateResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
        
        // Update cache (both list and details)
        if var scene = try await fetchService.getScene(id: sceneId) {
            scene.rating100 = ratingValue
            try await database.saveScenes([scene])
            try await database.saveSceneDetails(scene)
            
            // Post notification to update other views (e.g., home page)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .sceneUpdated,
                    object: nil,
                    userInfo: ["id": sceneId, "source": "updateRating"]
                )
            }
            
            return scene
        } else {
            if let fresh = try await fetchService.getScene(id: sceneId, forceRefresh: true) {
                return fresh
            }
            throw AppError.notFound("Scene")
        }
    }
    
    /// Updates the title of a scene.
    func updateTitle(for sceneId: String, title: String) async throws -> Scene {
        let url = try settings.validateStashConfiguration()
        
        let mutation = StashQueries.sceneUpdateTitle(id: sceneId, title: title)
        
        struct SceneUpdateTitleResult: Decodable {
            struct SceneUpdate: Decodable {
                let id: String
                let title: String?
            }
            let sceneUpdate: SceneUpdate
        }
        
        let _: SceneUpdateTitleResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
        
        // Fetch fresh to ensure we get everything right
        if let fresh = try await fetchService.getScene(id: sceneId, forceRefresh: true) {
            return fresh
        }
        throw AppError.notFound("Scene")
    }
    
    /// Updates multiple fields of a scene.
    func updateScene(
        id: String,
        title: String?,
        details: String?,
        performerIds: [String]?,
        tagIds: [String]?,
        coverImage: String?,
        director: String?,
        code: String?,
        url: String?
    ) async throws -> Scene {
        let urlValue = try settings.validateStashConfiguration()
        
        let mutation = StashQueries.sceneUpdateDetails(
            id: id,
            title: title,
            details: details,
            performerIds: performerIds,
            tagIds: tagIds,
            coverImage: coverImage,
            director: director,
            code: code,
            url: url
        )
        
        struct SceneUpdateDetailsResult: Decodable {
            let sceneUpdate: Scene
        }
        
        let result: SceneUpdateDetailsResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: urlValue
        )
        
        // Update local cache (both list and details)
        try await database.saveScenes([result.sceneUpdate])
        try await database.saveSceneDetails(result.sceneUpdate)
        
        return result.sceneUpdate
    }
    
    /// Deletes O-counter history entries for a scene.
    func deleteOHistory(sceneId: String, times: [String]) async throws {
        guard !times.isEmpty else { return }
        let url = try settings.validateStashConfiguration()
        
        let mutation = StashQueries.sceneDeleteO(sceneId: sceneId, times: times)
        
        struct HistoryDeleteResponse: Decodable {
            let count: Int
            let history: [String]
        }
        
        struct HistoryMutationResult: Decodable {
            let sceneDeleteO: HistoryDeleteResponse
        }
        
        let _: HistoryMutationResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
    }
    
    /// Deletes play history entries for a scene.
    func deletePlayHistory(sceneId: String, times: [String]) async throws {
        guard !times.isEmpty else { return }
        let url = try settings.validateStashConfiguration()
        
        let mutation = StashQueries.sceneDeletePlay(sceneId: sceneId, times: times)
        
        struct PlayHistoryDeleteResponse: Decodable {
            let count: Int
            let history: [String]
        }
        
        struct HistoryMutationResult: Decodable {
            let sceneDeletePlay: PlayHistoryDeleteResponse
        }
        
        let _: HistoryMutationResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
    }
    
    /// Deletes a scene and optionally its files or generated content.
    func deleteScene(id: String, deleteFile: Bool, deleteGenerated: Bool) async throws -> Bool {
        let url = try settings.validateStashConfiguration()
        
        let query = StashQueries.sceneDestroy(id: id, deleteFile: deleteFile, deleteGenerated: deleteGenerated)
        
        struct DeleteData: Decodable {
            let sceneDestroy: Bool
        }
        
        let _: DeleteData = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        
        // Delete from local database
        do {
            try await database.deleteSceneById(id: id)
        } catch {
            throw AppError.database(.queryFailed("Failed to delete scene from cache"))
        }
        
        return true
    }
    
    // MARK: - Private Helpers
    
    
    // MARK: - Private Response Structs
    
    private struct SceneIncrementOResult: Decodable {
        let sceneIncrementO: Int?
    }
    
    private struct SceneUpdateResult: Decodable {
        let sceneUpdate: Scene?
    }
    
    private struct SceneUpdateTitleResult: Decodable {
        let sceneUpdate: Scene?
    }
}
