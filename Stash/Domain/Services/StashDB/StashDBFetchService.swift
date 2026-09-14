import Foundation
import os

/// Service responsible for fetching data from the StashDB API.
///
/// This service handles all API calls to StashDB, including scene details,
/// performer information, and favorites management.
class StashDBFetchService: @unchecked Sendable {
    private let stashDBClient: StashDBClientProtocol
    private let whisparrDatabase: WhisparrDatabase
    private let settings: SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashDBFetchService")
    
    init(stashDBClient: StashDBClientProtocol, whisparrDatabase: WhisparrDatabase, settings: SettingsStoreProtocol) {
        self.stashDBClient = stashDBClient
        self.whisparrDatabase = whisparrDatabase
        self.settings = settings
    }
    
    
    // MARK: - Scene Operations
    
    func fetchSceneDetails(id: String) async throws -> StashDBScene {
        
        do {
            let scene = try await stashDBClient.fetchSceneDetails(id: id)
            return scene
        } catch {
            throw error
        }
    }
    
    func fetchScenes(ids: [String]) async throws -> [StashDBScene] {
        
        do {
            let scenes = try await stashDBClient.fetchScenes(ids: ids)
            return scenes
        } catch {
            throw error
        }
    }
    
    // MARK: - Performer Operations
    
    func fetchPerformerDetails(performerId: String) async throws -> StashDBPerformer {
        
        do {
            let performer = try await stashDBClient.fetchPerformerDetails(performerId: performerId)
            return performer
        } catch {
            throw error
        }
    }
    
    func fetchFavoritePerformersOverview(page: Int, perPage: Int) async throws -> StashDBPerformersData {
        
        do {
            let data = try await stashDBClient.fetchFavoritePerformersOverview(page: page, perPage: perPage)
            return data
        } catch {
            throw error
        }
    }
    
    func fetchPerformerSceneIds(
        performerId: String,
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> [String] {
        
        do {
            let ids = try await stashDBClient.fetchPerformerSceneIds(
                performerId: performerId,
                excludeVR: excludeVR,
                excludeCompilations: excludeCompilations
            )
            return ids
        } catch {
            throw error
        }
    }
    
    func fetchPerformerScenesOverview(
        performerId: String,
        page: Int,
        perPage: Int,
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> StashDBScenesData {
        
        do {
            let data = try await stashDBClient.fetchPerformerScenesOverview(
                performerId: performerId,
                page: page,
                perPage: perPage,
                excludeVR: excludeVR,
                excludeCompilations: excludeCompilations
            )
            return data
        } catch {
            throw error
        }
    }
    
    func searchPerformers(term: String, endpoint: String, apiKey: String) async throws -> [StashDBPerformer] {
        
        // Create a temporary client for this specific endpoint
        let client = await StashDBClient(apiKey: apiKey, baseURL: endpoint, settings: settings)
        
        do {
            let performers = try await client.searchPerformers(term: term)
            return performers
        } catch {
            throw error
        }
    }
    
    // MARK: - Studio Operations
    
    func fetchFavoriteStudios() async throws -> StashDBStudiosData {
        
        do {
            let data = try await stashDBClient.fetchFavoriteStudios()
            return data
        } catch {
            throw error
        }
    }
    
    func fetchScenesByPerformersAndStudiosOverview(
        performerIds: [String],
        studioIds: [String],
        excludeVR: Bool,
        excludeCompilations: Bool
    ) async throws -> StashDBScenesData {
        
        do {
            let data = try await stashDBClient.fetchScenesByPerformersAndStudiosOverview(
                performerIds: performerIds,
                studioIds: studioIds,
                excludeVR: excludeVR,
                excludeCompilations: excludeCompilations
            )
            return data
        } catch {
            throw error
        }
    }
    
    // MARK: - Favorites Logic
    
    func fetchFavoriteScenesFromStashDB(
        excludeVR: Bool,
        excludeCompilations: Bool,
        excludeOwned: Bool
    ) async throws -> [StashDBScene]? {
        
        guard let settingsStore = settings as? SettingsStore else {
            return nil
        }
        
        let apiKey = await settingsStore.stashDBApiKey
        guard !apiKey.isEmpty else {
            logger.info("⏭️ No StashDB API key configured, skipping favorites fetch")
            return nil
        }
        
        logger.info("🌟 Fetching favorite performers and studios from StashDB")
        
        // Fetch favorite performers, studios, and owned IDs in parallel
        async let performersTask = fetchFavoritePerformersOverview(page: 1, perPage: 1000)
        async let studiosTask = fetchFavoriteStudios()
        async let whisparrTask: Set<String>? = excludeOwned ? whisparrDatabase.fetchAllSceneStashIds() : nil
        
        let (performersData, studiosData, whisparrStashIds) = try await (performersTask, studiosTask, whisparrTask)
        
        let performerIds = performersData.performers.map { $0.id }
        logger.info("✅ Found \(performerIds.count) favorite performers")
        
        let studioIds = studiosData.studios.map { $0.id }
        logger.info("✅ Found \(studioIds.count) favorite studios")
        
        // If no favorites, return nil
        if performerIds.isEmpty && studioIds.isEmpty {
            logger.info("⏭️ No favorite performers or studios found")
            return nil
        }
        
        // Fetch scenes from those favorites
        let scenesData = try await fetchScenesByPerformersAndStudiosOverview(
            performerIds: performerIds,
            studioIds: studioIds,
            excludeVR: excludeVR,
            excludeCompilations: excludeCompilations
        )
        
        logger.info("✅ Fetched \(scenesData.scenes.count) scenes from favorites")
        
        var scenes = scenesData.scenes
        
        // Filter out scenes already in Whisparr if requested
        if excludeOwned, let ownedIds = whisparrStashIds {
            let beforeFilter = scenes.count
            scenes = scenes.filter { !ownedIds.contains($0.id) }
            let ownedCount = beforeFilter - scenes.count
            logger.info("🏠 Filtered out \(ownedCount) scenes already in Whisparr, \(scenes.count) remaining")
        }
        
        return scenes.isEmpty ? nil : scenes
    }
}
