import Foundation
import os

nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrClient")

// MARK: - Protocol

/// Protocol defining the Whisparr API client interface.
/// Whisparr is a scene collection manager (fork of Radarr) that uses "Movie" terminology internally.
/// This client maps "Movie" → "Scene" to align with domain terminology.
protocol WhisparrClientProtocol {
    func fetchScenes(url: String, apiKey: String, since: Date?) async throws -> [WhisparrScene]
    func fetchScene(id: Int, url: String, apiKey: String) async throws -> WhisparrScene
    func fetchCutoffUnmet(url: String, apiKey: String) async throws -> [WhisparrScene]
    func lookupScene(stashId: String, url: String, apiKey: String) async throws -> WhisparrLookupScene?
    func addScene(lookupScene: WhisparrLookupScene, url: String, apiKey: String, qualityProfileId: Int, rootFolderPath: String, tags: [Int]) async throws -> WhisparrScene
    func fetchRootFolders(url: String, apiKey: String) async throws -> [WhisparrRootFolder]
    func fetchQualityProfiles(url: String, apiKey: String) async throws -> [WhisparrQualityProfile]
    func fetchLogs(url: String, apiKey: String) async throws -> [WhisparrLog]
    func fetchQueue(url: String, apiKey: String) async throws -> [WhisparrQueueItem]
    func executeCommand(command: WhisparrSearchCommand, url: String, apiKey: String) async throws
    func fetchReleases(sceneId: Int, term: String?, url: String, apiKey: String) async throws -> [WhisparrRelease]
    func downloadRelease(release: WhisparrRelease, sceneId: Int, url: String, apiKey: String) async throws
    func deleteSceneFile(fileId: Int, url: String, apiKey: String) async throws
    func refreshDownloads(url: String, apiKey: String) async throws
    func searchScenes(term: String, url: String, apiKey: String) async throws -> [WhisparrSearchResult]
    func removeQueueItem(id: Int, url: String, apiKey: String, removeFromClient: Bool, blocklist: Bool) async throws
    func refreshScene(sceneId: Int, url: String, apiKey: String) async throws
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, url: String, apiKey: String) async throws -> WhisparrScene
    func updateSceneUsingEditor(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, moveFiles: Bool?, url: String, apiKey: String) async throws -> WhisparrScene
    func deleteScene(sceneId: Int, deleteFiles: Bool, addImportExclusion: Bool, url: String, apiKey: String) async throws
    func fetchHistory(sceneId: Int, url: String, apiKey: String) async throws -> [WhisparrHistoryEvent]
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String, url: String, apiKey: String) async throws -> WhisparrHistoryResponse
    func fetchCommands(url: String, apiKey: String) async throws -> [WhisparrCommand]
    func fetchCommand(id: Int, url: String, apiKey: String) async throws -> WhisparrCommand
}

// MARK: - Implementation

/// Whisparr API client for managing scene collections.
class WhisparrClient: WhisparrClientProtocol {
    
    // MARK: - Configuration
    
    private let session: URLSession
    private let settings: any SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(settings: any SettingsStoreProtocol) {
        self.session = URLSession(configuration: GraphQLClientConfiguration.whisparrConfiguration())
        self.settings = settings
    }
    
    // MARK: - Private Helpers
    
    private func performRequest<T: Decodable>(
        endpoint: String,
        apiKey: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) async throws -> T {
        guard var components = URLComponents(string: endpoint) else {
            logger.error("Invalid URL format: \(endpoint, privacy: .public)")
            throw AppError.network(.invalidURL(endpoint))
        }
        
        if let queryItems = queryItems {
            var existingItems = components.queryItems ?? []
            existingItems.append(contentsOf: queryItems)
            components.queryItems = existingItems
        }
        
        guard let url = components.url else {
            logger.error("Failed to construct URL from components: \(endpoint)")
            throw AppError.network(.invalidURL(endpoint))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = timeout
        
        if let body = body {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid HTTP response")
            throw AppError.whisparrAPI(.invalidResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let responseString = String(data: data, encoding: .utf8) {
                if httpResponse.statusCode == 400,
                   let errors = try? JSONDecoder().decode([WhisparrValidationError].self, from: data),
                   !errors.isEmpty {
                    throw AppError.whisparrAPI(.validationErrors(errors))
                }
                logger.error("Error response: \(responseString, privacy: .public)")
            }
            
            if httpResponse.statusCode == 401 {
                throw AppError.whisparrAPI(.unauthorizedAPIKey)
            } else if httpResponse.statusCode == 404 {
                throw AppError.whisparrAPI(.notFound)
            }
            
            logger.error("HTTP error: \(httpResponse.statusCode)")
            throw AppError.network(.httpError(statusCode: httpResponse.statusCode, response: data))
        }
        
        do {
            return try JSONDecoder.whisparrDecoder.decode(T.self, from: data)
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("❌ Decoding Error for \(endpoint): \(error)")
                logger.debug("📄 Raw Response: \(responseString, privacy: .public)")
                
                // Print to console for user visibility if needed
                logger.error("Whisparr Decoding Error for \(endpoint): \(error)")
                logger.debug("📄 Raw Response: \(responseString)")
            }
            throw error
        }
    }
    
    private func performVoidRequest(
        endpoint: String,
        apiKey: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) async throws {
        guard var components = URLComponents(string: endpoint) else { 
            throw AppError.network(.invalidURL(endpoint)) 
        }
        if let queryItems = queryItems {
            var existing = components.queryItems ?? []
            existing.append(contentsOf: queryItems)
            components.queryItems = existing
        }
        guard let url = components.url else { 
            throw AppError.network(.invalidURL(endpoint)) 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = timeout
        
        if let body = body {
             request.addValue("application/json", forHTTPHeaderField: "Content-Type")
             request.httpBody = body
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { 
            throw AppError.whisparrAPI(.invalidResponse) 
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AppError.whisparrAPI(.unauthorizedAPIKey)
            } else if httpResponse.statusCode == 404 {
                throw AppError.whisparrAPI(.notFound)
            }
            throw AppError.network(.httpError(statusCode: httpResponse.statusCode, response: nil))
        }
    }
    
    private struct CommandResponse: Codable {
        let id: Int
        let name: String
        let status: String
    }
    
    private func executeWhisparrCommand<T: Encodable>(_ command: T, url: String, apiKey: String, timeout: TimeInterval = 30) async throws -> Int {
        let endpoint = "\(url)/api/v3/command"
        let encoder = JSONEncoder()
        let body = try encoder.encode(command)
        
        let response: CommandResponse = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            method: "POST",
            body: body,
            timeout: timeout
        )
        
        return response.id
    }
    
    // MARK: - Scene Management
    
    func updateScene(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, url: String, apiKey: String) async throws -> WhisparrScene {
        logger.info("🔄 Updating scene: \(scene.title, privacy: .public)")
        logger.info("📊 Input values - monitored: \(monitored), qualityProfileId: \(qualityProfileId), rootFolderPath: \(rootFolderPath)")
        
        let getEndpoint = "\(url)/api/v3/movie/\(scene.id)"
        logger.info("🌐 GET endpoint: \(getEndpoint)")
        guard let getUrl = URL(string: getEndpoint) else {
            throw AppError.network(.invalidURL(getEndpoint))
        }
        
        var getRequest = URLRequest(url: getUrl)
        getRequest.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        getRequest.timeoutInterval = 10
        
        let (data, _) = try await session.data(for: getRequest)
        guard var json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw AppError.whisparrAPI(.invalidResponse)
        }
        
        let originalMonitored = json["monitored"] as? Bool ?? false
        let originalQualityProfileId = json["qualityProfileId"] as? Int ?? -1
        let originalRootFolderPath = json["rootFolderPath"] as? String ?? "nil"
        logger.info("📥 GET response - monitored: \(originalMonitored), qualityProfileId: \(originalQualityProfileId), rootFolderPath: \(originalRootFolderPath)")
        
        json["monitored"] = monitored
        json["qualityProfileId"] = qualityProfileId
        json["rootFolderPath"] = rootFolderPath
        
        logger.info("📤 PUT body - monitored: \(monitored), qualityProfileId: \(qualityProfileId), rootFolderPath: \(rootFolderPath)")
        
        let putBody = try JSONSerialization.data(withJSONObject: json)
        logger.info("🌐 PUT endpoint: \(getEndpoint)")
        let dto: WhisparrMovieDTO = try await performRequest(
            endpoint: getEndpoint,
            apiKey: apiKey,
            method: "PUT",
            body: putBody,
            timeout: 30
        )
        logger.info("📥 PUT response - monitored: \(dto.monitored), qualityProfileId: \(dto.qualityProfileId ?? -1), rootFolderPath: \(dto.rootFolderPath ?? "nil")")
        // Use optimistic update: API returns 202 Accepted with OLD state
        // So we use the values we SENT, not the response
        var updatedScene = dto.toDomain()
        updatedScene = updatedScene.with(monitored: monitored, qualityProfileId: qualityProfileId, rootFolderPath: rootFolderPath)
        logger.info("📊 Using optimistic values - monitored: \(updatedScene.monitored), qualityProfileId: \(updatedScene.qualityProfileId ?? -1), rootFolderPath: \(updatedScene.rootFolderPath ?? "nil")")
        
        struct WhisparrRefreshMovieCommand: Encodable {
            let name: String
            let movieIds: [Int]
        }
        
        _ = try await executeWhisparrCommand(
            WhisparrRefreshMovieCommand(name: "RefreshMovie", movieIds: [scene.id]),
            url: url,
            apiKey: apiKey,
            timeout: 30
        )
        
        logger.info("✅ Updated scene: \(scene.title, privacy: .public)")
        return updatedScene
    }
    
    /// Updates a scene using the /api/v3/movie/editor bulk endpoint (supports moveFiles)
    func updateSceneUsingEditor(scene: WhisparrScene, monitored: Bool, qualityProfileId: Int, rootFolderPath: String, moveFiles: Bool?, url: String, apiKey: String) async throws -> WhisparrScene {
        logger.info("📝 Using movie editor endpoint for scene: \(scene.title, privacy: .public)")
        logger.info("📊 Input values - monitored: \(monitored), qualityProfileId: \(qualityProfileId), rootFolderPath: \(rootFolderPath), moveFiles: \(moveFiles?.description ?? "nil")")
        
        let endpoint = "\(url)/api/v3/movie/editor"
        logger.info("🌐 PUT endpoint: \(endpoint)")
        
        let editorRequest = WhisparrMovieEditorRequest(
            movieIds: [scene.id],
            monitored: monitored,
            qualityProfileId: qualityProfileId,
            rootFolderPath: rootFolderPath,
            moveFiles: moveFiles
        )
        
        let encoder = JSONEncoder()
        let body = try encoder.encode(editorRequest)
        
        if let bodyString = String(data: body, encoding: .utf8) {
            logger.info("📤 Request body: \(bodyString)")
        }
        
        // The editor endpoint returns an array of updated movies
        let updatedScenes: [WhisparrMovieDTO] = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            method: "PUT",
            body: body,
            timeout: 30
        )
        
        guard let dto = updatedScenes.first else {
            logger.error("❌ Editor endpoint returned empty array")
            throw AppError.whisparrAPI(.invalidResponse)
        }
        
        let updatedScene = dto.toDomain()
        logger.info("📥 Editor response - monitored: \(updatedScene.monitored), qualityProfileId: \(updatedScene.qualityProfileId ?? -1), rootFolderPath: \(updatedScene.rootFolderPath ?? "nil")")
        
        // Trigger refresh to ensure metadata is updated
        struct WhisparrRefreshMovieCommand: Encodable {
            let name: String
            let movieIds: [Int]
        }
        
        _ = try await executeWhisparrCommand(
            WhisparrRefreshMovieCommand(name: "RefreshMovie", movieIds: [scene.id]),
            url: url,
            apiKey: apiKey,
            timeout: 30
        )
        
        logger.info("✅ Updated scene using editor: \(scene.title, privacy: .public)")
        return updatedScene
    }
    
    // MARK: - Fetching Scenes
    
    func fetchScenes(url: String, apiKey: String, since: Date? = nil) async throws -> [WhisparrScene] {
        let endpoint = "\(url)/api/v3/movie"
        var queryItems: [URLQueryItem]?
        
        if let since = since {
            let formatter = ISO8601DateFormatter()
            queryItems = [URLQueryItem(name: "since", value: formatter.string(from: since))]
        }
        
        let allMovies: [WhisparrMovieDTO] = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            queryItems: queryItems,
            timeout: 300
        )
        
        let scenes = allMovies.filter { $0.itemType == "scene" }
        return scenes.map { $0.toDomain() }
    }
    
    func fetchScene(id: Int, url: String, apiKey: String) async throws -> WhisparrScene {
        let endpoint = "\(url)/api/v3/movie/\(id)"
        let dto: WhisparrMovieDTO = try await performRequest(endpoint: endpoint, apiKey: apiKey, timeout: 10)
        logger.debug("📊 fetchScene API returned monitored: \(dto.monitored)")
        return dto.toDomain()
    }
    
    func fetchCutoffUnmet(url: String, apiKey: String) async throws -> [WhisparrScene] {
        var allScenes: [WhisparrScene] = []
        var currentPage = 1
        var hasMore = true
        
        while hasMore {
            let endpoint = "\(url)/api/v3/wanted/cutoff"
            let queryItems = [
                URLQueryItem(name: "page", value: "\(currentPage)"),
                URLQueryItem(name: "pageSize", value: "100"),
                URLQueryItem(name: "monitored", value: "true")
            ]
            
            struct CutoffResponse: Codable {
                let page: Int
                let pageSize: Int
                let totalRecords: Int
                let records: [WhisparrMovieDTO]
            }
            
            let cutoffResponse: CutoffResponse = try await performRequest(
                endpoint: endpoint,
                apiKey: apiKey,
                queryItems: queryItems
            )
            
            allScenes.append(contentsOf: cutoffResponse.records.map { $0.toDomain() })
            
            let totalPages = (cutoffResponse.totalRecords + cutoffResponse.pageSize - 1) / cutoffResponse.pageSize
            hasMore = currentPage < totalPages
            currentPage += 1
        }
        
        return allScenes
    }
    
    // MARK: - Scene Lookup & Addition
    
    func lookupScene(stashId: String, url: String, apiKey: String) async throws -> WhisparrLookupScene? {
        let endpoint = "\(url)/api/v3/lookup/scene"
        let queryItems = [URLQueryItem(name: "term", value: "stash:\(stashId)")]
        
        struct LookupResponse: Codable {
            let foreignId: String
            let movie: WhisparrLookupScene
        }
        
        let lookupResults: [LookupResponse] = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            queryItems: queryItems
        )
        
        if let first = lookupResults.first {
            return first.movie
        } else {
            logger.warning("No scene found in lookup")
            return nil
        }
    }
    
    func addScene(lookupScene: WhisparrLookupScene, url: String, apiKey: String, qualityProfileId: Int, rootFolderPath: String, tags: [Int]) async throws -> WhisparrScene {
        let endpoint = "\(url)/api/v3/movie"
        logger.info("➕ Adding scene: \(lookupScene.title, privacy: .public)")
        
        let payload: [String: Any] = [
            "title": lookupScene.title,
            "studio": lookupScene.studioTitle ?? "",
            "foreignId": lookupScene.foreignId,
            "monitored": true,
            "qualityProfileId": qualityProfileId,
            "rootFolderPath": rootFolderPath,
            "tags": tags,
            "addOptions": [
                "searchForMovie": true
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        let dto: WhisparrMovieDTO = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            method: "POST",
            body: jsonData,
            timeout: 30
        )
        
        return dto.toDomain()
    }
    
    // MARK: - Configuration
    
    func fetchRootFolders(url: String, apiKey: String) async throws -> [WhisparrRootFolder] {
        let baseUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = "\(baseUrl)/api/v3/rootfolder"
        logger.info("Fetching root folders")
        return try await performRequest(endpoint: endpoint, apiKey: apiKey, timeout: 10)
    }
    
    func fetchQualityProfiles(url: String, apiKey: String) async throws -> [WhisparrQualityProfile] {
        let baseUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = "\(baseUrl)/api/v3/qualityprofile"
        logger.info("Fetching quality profiles")
        return try await performRequest(endpoint: endpoint, apiKey: apiKey, timeout: 10)
    }
    
    // MARK: - Logs & Queue
    
    func fetchLogs(url: String, apiKey: String) async throws -> [WhisparrLog] {
        let endpoint = "\(url)/api/v3/log"
        logger.info("Fetching logs")
        
        struct LogResponse: Codable {
            let records: [WhisparrLog]
        }
        
        let response: LogResponse = try await performRequest(endpoint: endpoint, apiKey: apiKey, timeout: 10)
        return response.records
    }
    
    func fetchQueue(url: String, apiKey: String) async throws -> [WhisparrQueueItem] {
        let endpoint = "\(url)/api/v3/queue"
        let queryItems = [
            URLQueryItem(name: "pageSize", value: "100"),
            URLQueryItem(name: "includeMovie", value: "true")
        ]
        logger.info("Fetching queue")
        
        let response: WhisparrQueueResponse = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            queryItems: queryItems,
            timeout: 10
        )
        logger.info("Fetched \(response.records.count) queue items")
        
        return response.records
    }
    
    // MARK: - Commands
    
    func executeCommand(command: WhisparrSearchCommand, url: String, apiKey: String) async throws {
        logger.info("⚡ Executing command: \(command.name, privacy: .public)")
        _ = try await executeWhisparrCommand(command, url: url, apiKey: apiKey, timeout: 30)
    }
    
    // MARK: - Releases & Downloads
    
    func fetchReleases(sceneId: Int, term: String? = nil, url: String, apiKey: String) async throws -> [WhisparrRelease] {
        let endpoint = "\(url)/api/v3/release"
        var queryItems = [URLQueryItem(name: "movieId", value: String(sceneId))]
        
        if let term = term, !term.isEmpty {
             queryItems.append(URLQueryItem(name: "term", value: term))
        }
        
        let releases: [WhisparrRelease] = try await performRequest(endpoint: endpoint, apiKey: apiKey, queryItems: queryItems, timeout: 30)
        return releases
    }
    
    func downloadRelease(release: WhisparrRelease, sceneId: Int, url: String, apiKey: String) async throws {
        let endpoint = "\(url)/api/v3/release"
        logger.info("📥 Downloading release: \(release.title, privacy: .public)")
        
        let payload: [String: Any] = [
            "guid": release.guid,
            "indexerId": release.indexerId,
            "movieId": sceneId
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        try await performVoidRequest(endpoint: endpoint, apiKey: apiKey, method: "POST", body: jsonData, timeout: 30)
        logger.info("✅ Queued download: \(release.title, privacy: .public)")
    }
    
    func deleteSceneFile(fileId: Int, url: String, apiKey: String) async throws {
        let endpoint = "\(url)/api/v3/moviefile/\(fileId)"
        logger.info("🗑️ Deleting scene file ID: \(fileId)")
        try await performVoidRequest(endpoint: endpoint, apiKey: apiKey, method: "DELETE", timeout: 30)
    }
    
    func refreshDownloads(url: String, apiKey: String) async throws {
        logger.debug("Triggering download refresh")
        let command = WhisparrSearchCommand(name: "RefreshMonitoredDownloads", movieIds: [])
        _ = try await executeWhisparrCommand(command, url: url, apiKey: apiKey, timeout: 10)
    }
    
    // MARK: - Search
    
    func searchScenes(term: String, url: String, apiKey: String) async throws -> [WhisparrSearchResult] {
        let endpoint = "\(url)/api/v3/lookup/scene"
        let queryItems = [URLQueryItem(name: "term", value: term)]
        
        struct SearchResponse: Codable {
            let foreignId: String
            let movie: WhisparrSearchResult
        }
        
        let searchResponses: [SearchResponse] = try await performRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            queryItems: queryItems,
            timeout: 30
        )
        
        return searchResponses.map { $0.movie }
    }
    
    // MARK: - Queue Management
    
    func removeQueueItem(id: Int, url: String, apiKey: String, removeFromClient: Bool = true, blocklist: Bool = false) async throws {
        let endpoint = "\(url)/api/v3/queue/\(id)"
        let queryItems = [
            URLQueryItem(name: "removeFromClient", value: String(removeFromClient)),
            URLQueryItem(name: "blocklist", value: String(blocklist))
        ]
        logger.info("🗑️ Removing queue item ID: \(id)")
        try await performVoidRequest(endpoint: endpoint, apiKey: apiKey, method: "DELETE", queryItems: queryItems, timeout: 30)
    }
    
    func refreshScene(sceneId: Int, url: String, apiKey: String) async throws {
        struct RefreshCommand: Codable {
            let name: String
            let movieIds: [Int]
        }
        
        let command = RefreshCommand(name: "RefreshMovie", movieIds: [sceneId])
        _ = try await executeWhisparrCommand(command, url: url, apiKey: apiKey, timeout: 10)
    }
    
    // MARK: - Deletion
    
    func deleteScene(sceneId: Int, deleteFiles: Bool, addImportExclusion: Bool, url: String, apiKey: String) async throws {
        let endpoint = "\(url)/api/v3/movie/\(sceneId)"
        let queryItems = [
            URLQueryItem(name: "deleteFiles", value: String(deleteFiles)),
            URLQueryItem(name: "addImportExclusion", value: String(addImportExclusion))
        ]
        
        logger.info("🗑️ Deleting scene ID: \(sceneId)")
        try await performVoidRequest(endpoint: endpoint, apiKey: apiKey, method: "DELETE", queryItems: queryItems, timeout: 30)
        logger.info("✅ Deleted scene ID: \(sceneId)")
    }
    
    // MARK: - History
    
    func fetchHistory(sceneId: Int, url: String, apiKey: String) async throws -> [WhisparrHistoryEvent] {
        let endpoint = "\(url)/api/v3/history/movie"
        let queryItems = [URLQueryItem(name: "movieId", value: String(sceneId))]
        return try await performRequest(endpoint: endpoint, apiKey: apiKey, queryItems: queryItems, timeout: 10)
    }
    
    func fetchHistory(page: Int, pageSize: Int, sortKey: String, sortDirection: String, url: String, apiKey: String) async throws -> WhisparrHistoryResponse {
        let endpoint = "\(url)/api/v3/history"
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "sortKey", value: sortKey),
            URLQueryItem(name: "sortDirection", value: sortDirection),
            URLQueryItem(name: "includeMovie", value: "true")
        ]
        return try await performRequest(endpoint: endpoint, apiKey: apiKey, queryItems: queryItems, timeout: 10)
    }
    
    // MARK: - Commands
    
    func fetchCommands(url: String, apiKey: String) async throws -> [WhisparrCommand] {
        let endpoint = "\(url)/api/v3/command"
        let commands: [WhisparrCommand] = try await performRequest(endpoint: endpoint, apiKey: apiKey, timeout: 10)
        return commands
    }
    
    func fetchCommand(id: Int, url: String, apiKey: String) async throws -> WhisparrCommand {
        let endpoint = "\(url)/api/v3/command/\(id)"
        let command: WhisparrCommand = try await performRequest(endpoint: endpoint, apiKey: apiKey, timeout: 10)
        return command
    }
}

