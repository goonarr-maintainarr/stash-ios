import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneScrapeService")

/// Service responsible for scene scraping from StashBox sources.
///
/// Handles:
/// - Fetching available StashBox configurations
/// - Scraping scene metadata from StashBox
/// - Applying scraped results to existing scenes
/// - Resolving performer and tag references
class SceneScrapeService: StashService, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    let apiClient: StashClientProtocol
    let settings: any SettingsStoreProtocol
    private let fetchService: SceneFetchService
    
    // MARK: - Initialization
    
    init(
        apiClient: StashClientProtocol,
        settings: any SettingsStoreProtocol,
        fetchService: SceneFetchService
    ) {
        self.apiClient = apiClient
        self.settings = settings
        self.fetchService = fetchService
    }
    
    // MARK: - Public Methods
    
    /// Fetches available scraper sources (StashBoxes) from the configuration.
    func fetchStashBoxes() async throws -> [StashBox] {
        let url = try settings.validateStashConfiguration()
        
        let query = StashQueries.configuration
        let result: ConfigurationResponse = try await fetchWithErrorWrapping(
            query: query,
            variables: nil,
            url: url
        )
        return result.configuration.general.stashBoxes
    }
    
    /// Scrapes a scene from a specific StashBox source.
    func scrapeScene(id: String, title: String?, stashBox: StashBox) async throws -> [ScrapedScene] {
        let url = try settings.validateStashConfiguration()
        
        // Prepare variables
        let source: [String: Any] = ["stash_box_endpoint": stashBox.endpoint]
        let searchTerms = title?.trimmingCharacters(in: .whitespaces) ?? ""
        var input: [String: Any] = [
            "query": searchTerms.isEmpty ? " " : searchTerms
        ]
        
        let variables: [String: Any] = [
            "source": source,
            "input": input
        ]
        
        let result: ScrapedSceneResult = try await fetchWithErrorWrapping(
            query: StashQueries.scrapeSingleScene,
            variables: variables,
            url: url
        )
        
        return result.scrapeSingleScene ?? []
    }
    
    /// Scrapes a scene using fragment data (title, date, etc.) to find matches.
    func scrapeSceneByFragment(fragment: SceneFragmentInput, stashBox: StashBox) async throws -> [ScrapedScene] {
        let url = try settings.validateStashConfiguration()
        
        // Prepare variables
        let source: [String: Any] = ["stash_box_endpoint": stashBox.endpoint]
        let sceneInput = fragment.toDictionary()
        
        var input: [String: Any] = ["scene_input": sceneInput]
        
        // Construct a search query for StashBox from fragment fields.
        // Stash server currently requires 'query' or 'scene_id' for StashBox scrapes.
        // We use title and code as the search term.
        var queryComponents: [String] = []
        if let title = fragment.title, !title.isEmpty {
            queryComponents.append(title)
        }
        if let code = fragment.code, !code.isEmpty {
            queryComponents.append(code)
        }
        
        let constructedQuery = queryComponents.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        // If constructedQuery is empty, we must still provide a non-empty string to satisfy StashBox/Stash requirements.
        // Some backend versions might treat "" as null in their internal variable mapping.
        // ThePornDB specifically requires a valid query string to be present alongside scene_input.
        // We use a specific placeholder if empty to ensure it survives whitespace trimming.
        input["query"] = constructedQuery.isEmpty ? "placeholder" : constructedQuery
        
        // Debug Logging
        logger.debug("--- StashBox Fragment Scrape ---")
        
        let variables: [String: Any] = [
            "source": source,
            "input": input
        ]
        
        let result: ScrapedSceneResult = try await fetchWithErrorWrapping(
            query: StashQueries.scrapeSingleScene,
            variables: variables,
            url: url
        )
        
        return result.scrapeSingleScene ?? []
    }
    
    /// Applies the results of a scrape operation to an existing scene.
    ///
    /// This method selectively updates fields based on the provided options,
    /// resolving performer and tag references as needed.
    func applyScrapeResult(to sceneId: String, result: ScrapedScene, options: ScrapeApplyOptions) async throws -> Scene {
        let url = try settings.validateStashConfiguration()
        let config = try await fetchTaggerConfig()
        
        // Log TaggerConfig settings for debugging
        logger.info("⚙️ TaggerConfig: setTags=\(config.setTags), setCoverImage=\(config.setCoverImage), tagOperation=\(config.tagOperation.rawValue)")
        
        // Prepare Data
        let newTitle: String? = options.useTitle ? result.title : nil
        let newDetails: String? = options.useDetails ? result.details : nil
        let newCoverImage: String? = (options.useImage && config.setCoverImage) ? result.image : nil
        let newDirector: String? = options.useDirector ? result.director : nil
        let newCode: String? = options.useCode ? result.code : nil
        
        // Handle URL: prefer single 'url', fallback to first of 'urls'
        var newUrl: String? = nil
        if options.useUrl {
            if let u = result.url {
                newUrl = u
            } else if let urls = result.urls, let first = urls.first {
                newUrl = first
            }
        }
        
        var performerIds: [String]? = nil
        if options.usePerformers, var performers = result.performers {
            // Apply gender filter if configured
            if let allowedGenders = config.performerGenders {
                performers = performers.filter { perf in
                    guard let genderStr = perf.gender, let gender = GenderEnum(from: genderStr) else { return false }
                    return allowedGenders.contains(gender)
                }
            }
            performerIds = await resolvePerformerIds(performers: performers, url: url)
        }
        
        var studioId: String? = nil
        if options.useStudio, let studioName = result.studio?.name {
            studioId = await resolveStudioId(name: studioName, url: url)
        }
        
        var tagIds: [String]? = nil
        if options.useTags && config.setTags, let tags = options.customTags ?? result.tags {
            logger.info("🏷️ Processing \(tags.count) tags from scrape result...")
            // Fetch the current scene to merge with existing tags
            if let currentScene = try await fetchService.getScene(id: sceneId) {
                let resolvedIds = await resolveTagIds(tags: tags, url: url)
                logger.info("🏷️ Resolved \(resolvedIds.count) tag IDs")
                if config.tagOperation == TagOperation.merge {
                    var existingIds = currentScene.tags?.compactMap { $0.id } ?? []
                    let newIds = resolvedIds.filter { !existingIds.contains($0) }
                    existingIds.append(contentsOf: newIds)
                    tagIds = existingIds
                    logger.info("🏷️ Merged to \(tagIds?.count ?? 0) total tags")
                } else {
                    // Overwrite
                    tagIds = resolvedIds
                    logger.info("🏷️ Overwriting with \(tagIds?.count ?? 0) tags")
                }
            }
        }
        
        var organized: Bool? = nil
        if config.markSceneAsOrganizedOnSave {
            organized = true
        }
        
        // Mutation
        let mutation = StashQueries.sceneUpdateDetails(
            id: sceneId,
            title: newTitle,
            details: newDetails,
            performerIds: performerIds,
            tagIds: tagIds,
            coverImage: newCoverImage,
            director: newDirector,
            code: newCode,
            url: newUrl,
            studioId: studioId,
            organized: organized
        )
        
        // Debug logging
        logger.debug("🔍 SCRAPE APPLY: sceneId=\(sceneId), title=\(newTitle ?? "nil"), performers=\(performerIds?.count ?? 0), tags=\(tagIds?.count ?? 0), studio=\(studioId ?? "nil")")
        
        struct UpdateResult: Decodable {
            struct SceneUpdate: Decodable {
                let id: String
            }
            let sceneUpdate: SceneUpdate
        }
        
        let updateResult: UpdateResult = try await fetchWithErrorWrapping(
            query: mutation,
            variables: nil,
            url: url
        )
        
        logger.debug("✅ Mutation succeeded for scene \(updateResult.sceneUpdate.id)")
        
        // Fetch fresh scene data (forceRefresh will update local cache)
        guard let fresh = try await fetchService.getScene(id: sceneId, forceRefresh: true) else {
            logger.error("❌ Failed to fetch fresh scene after mutation!")
            throw AppError.notFound("Scene")
        }
        
        logger.info("✅ Scrape applied: \(fresh.title ?? "Unknown") - Performers: \(fresh.performers?.count ?? 0), Tags: \(fresh.tags?.count ?? 0)")
        
        // Post notification to update other views
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sceneUpdated,
                object: nil,
                userInfo: ["id": sceneId, "source": "scrapeApply"]
            )
        }
        
        return fresh
    }
    
    /// Resolves studio name to ID, creating it if necessary (if configured, but simpler to search first).
    /// For now, only searches. Ideally we would create if missing but Stash behavior varies.
    private func resolveStudioId(name: String, url: URL) async -> String? {
        let query = StashQueries.findStudiosScrape(name: name)
        
        do {
            struct StudioSearchResult: Decodable {
                struct FindStudios: Decodable {
                    struct Studio: Decodable { let id: String; let name: String }
                    let studios: [Studio]
                }
                let findStudios: FindStudios
            }
            
            let result: StudioSearchResult = try await fetchWithErrorWrapping(
                query: query,
                variables: nil,
                url: url
            )
            
            // Exact match preferred
            if let match = result.findStudios.studios.first(where: { $0.name.lowercased() == name.lowercased() }) {
                return match.id
            }
            // Fuzzy match (first result)
            return result.findStudios.studios.first?.id
            
        } catch {
            logger.error("❌ Error resolving studio \(name): \(error.localizedDescription)")
            return nil
        }
    }

    
    /// Resolves performer names to IDs by using stored_id or searching the Stash database.
    private func resolvePerformerIds(performers: [ScrapedPerformer], url: URL) async -> [String] {
        var ids: [String] = []
        var unresolvedNames: [String] = []
        
        for performer in performers {
            // First, check if the server already resolved this performer
            if let storedId = performer.stored_id {
                ids.append(storedId)
                logger.debug("✅ Using stored_id for performer: \(performer.name)")
                continue
            }
            
            // Otherwise, search for the performer by name
            let query = StashQueries.findPerformers(searchText: performer.name, page: 1, perPage: 5, sort: "name", direction: "ASC")
            do {
                let result: PerfSearchResult = try await fetchWithErrorWrapping(
                    query: query,
                    variables: nil,
                    url: url
                )
                
                // Try exact match first (case-insensitive)
                if let exactMatch = result.findPerformers.performers.first(where: {
                    $0.name?.lowercased() == performer.name.lowercased()
                }) {
                    ids.append(exactMatch.id)
                    logger.debug("✅ Exact match for performer: \(performer.name)")
                    continue
                }
                
                // Fallback to first result (fuzzy match from server search)
                if let fuzzyMatch = result.findPerformers.performers.first {
                    ids.append(fuzzyMatch.id)
                    logger.debug("⚠️ Fuzzy match for performer '\(performer.name)' → '\(fuzzyMatch.name ?? "unknown")'")
                    continue
                }
                
                // No match found
                unresolvedNames.append(performer.name)
                logger.warning("❌ Could not resolve performer: \(performer.name)")
                
            } catch {
                unresolvedNames.append(performer.name)
                logger.error("❌ Error finding performer \(performer.name): \(error.localizedDescription)")
            }
        }
        
        if !unresolvedNames.isEmpty {
            logger.warning("⚠️ \(unresolvedNames.count) performers could not be resolved: \(unresolvedNames.joined(separator: ", "))")
        }
        
        return ids
    }
    
    /// Resolves tag names to IDs, creating tags if they don't exist.
    private func resolveTagIds(tags: [ScrapedTag], url: URL) async -> [String] {
        var ids: [String] = []
        for tag in tags {
            let query = StashQueries.findTags(searchText: tag.name, page: 1, perPage: 5)
            do {
                let result: TagSearchResult = try await fetchWithErrorWrapping(
                    query: query,
                    variables: nil,
                    url: url
                )
                
                // Exact match
                if let exactMatch = result.findTags.tags.first(where: { $0.name.lowercased() == tag.name.lowercased() }) {
                    ids.append(exactMatch.id)
                    continue
                }
                
                // Alias match (first result often if searching by exact name logic but stash search is fuzzy)
                if let aliasMatch = result.findTags.tags.first {
                    ids.append(aliasMatch.id)
                    continue
                }
                
                // Create
                if let createdId = await createTagOrFindExisting(name: tag.name, url: url) {
                    ids.append(createdId)
                }
            } catch {
                logger.error("❌ Error resolving tag \(tag.name): \(error.localizedDescription)")
            }
        }
        return ids
    }
    
    /// Creates a new tag or finds an existing one.
    private func createTagOrFindExisting(name: String, url: URL) async -> String? {
         let createMutation = StashQueries.tagCreate(name: name)
         do {
             let createResult: TagCreateResult = try await fetchWithErrorWrapping(
                query: createMutation,
                variables: nil,
                url: url
             )
             return createResult.tagCreate.id
         } catch {
             logger.error("Error creating tag: \(error.localizedDescription)")
         }
         return nil
    }
    
    // MARK: - Private Response Structs
    
    private struct PerfSearchResult: Decodable {
        struct FindPerformers: Decodable {
            let performers: [Performer]
        }
        let findPerformers: FindPerformers
    }
    
    private struct TagSearchResult: Decodable {
        struct FindTags: Decodable {
            let tags: [Tag]
        }
        let findTags: FindTags
    }
    
    private struct TagCreateResult: Decodable {
        struct TagCreate: Decodable {
            let id: String
        }
        let tagCreate: TagCreate
    }
    
    // MARK: - Tagger Configuration
    
    private let taggerConfigKey = "savedTaggerConfig"
    
    /// Fetches the tagger configuration from the server, falling back to local storage.
    func fetchTaggerConfig() async throws -> TaggerConfig {
        let url = try settings.validateStashConfiguration()
        logger.debug("🌐 Fetching tagger configuration from \(url.absoluteString, privacy: .public)")
        
        struct TaggerConfigResponse: Decodable {
            struct Configuration: Decodable {
                struct UI: Decodable {
                    let taggerConfig: TaggerConfig?
                }
                let ui: UI
            }
            let configuration: Configuration
        }
        
        do {
            let result: TaggerConfigResponse = try await fetchWithErrorWrapping(
                query: StashQueries.taggerConfig,
                variables: nil,
                url: url
            )
            
            if let serverConfig = result.configuration.ui.taggerConfig {
                logger.debug("✅ Successfully fetched & synced tagger config from server")
                // Update local cache
                saveToLocal(serverConfig)
                return serverConfig
            }
        } catch {
            logger.warning("⚠️ Failed to fetch tagger config from server: \(error.localizedDescription). Trying local cache.")
        }
        
        // Fallback to local storage
        if let localConfig = loadFromLocal() {
             logger.debug("dw Using locally cached tagger config")
             return localConfig
        }
        
        return .default
    }
    
    /// Saves the tagger configuration to the server and local storage.
    func saveTaggerConfig(_ config: TaggerConfig) async throws {
        // Always save locally first
        saveToLocal(config)
        
        let url = try settings.validateStashConfiguration()
        logger.debug("💾 Saving tagger configuration to \(url.absoluteString, privacy: .public)")
        
        // Convert config to dictionary for Any! GraphQL variable
        let data = try JSONEncoder().encode(config)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        struct EmptyResult: Decodable {}
        
        do {
            let _: EmptyResult = try await fetchWithErrorWrapping(
                query: StashQueries.configureTaggerConfig,
                variables: ["config": dict],
                url: url
            )
            logger.info("✅ Successfully saved tagger configuration to server")
        } catch {
            logger.error("❌ Failed to save tagger configuration to server: \(error.localizedDescription)")
            // We don't throw here because local save succeeded, which is often sufficient for the user session
        }
    }
    
    // MARK: - Local Persistence Helpers
    
    private func saveToLocal(_ config: TaggerConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: taggerConfigKey)
        }
    }
    
    private func loadFromLocal() -> TaggerConfig? {
        guard let data = UserDefaults.standard.data(forKey: taggerConfigKey),
              let config = try? JSONDecoder().decode(TaggerConfig.self, from: data) else {
            return nil
        }
        return config
    }
}
