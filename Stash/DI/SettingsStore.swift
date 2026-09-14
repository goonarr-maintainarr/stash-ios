import Foundation
import SwiftUI
import Combine
import os

/// Options for generating metadata in Stash (covers, sprites, previews, etc.)
struct GenerationOptions: Codable, Equatable, Sendable {
    var covers: Bool = true
    var sprites: Bool = true
    var previews: Bool = true
    var imagePreviews: Bool = true
    var markers: Bool = true
    var markerImagePreviews: Bool = true
    var markerScreenshots: Bool = true
    var transcodes: Bool = true
    var forceTranscodes: Bool = false
    var phashes: Bool = true
    var interactiveHeatmapsSpeeds: Bool = true
    var imageThumbnails: Bool = true
    var clipPreviews: Bool = true
    var overwrite: Bool = false
}

/// Options for scanning library files in Stash
struct ScanOptions: Codable, Equatable, Sendable {
    var paths: String = "" // Newline separated for UI
    var rescan: Bool = false
    var scanGenerateCovers: Bool = false
    var scanGeneratePreviews: Bool = false
    var scanGenerateImagePreviews: Bool = false
    var scanGenerateSprites: Bool = false
    var scanGeneratePhashes: Bool = false
    var scanGenerateThumbnails: Bool = false
    var scanGenerateClipPreviews: Bool = false
    
    /// Helper to convert the newline-separated paths string into an array
    var pathsArray: [String] {
        paths.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Protocol

/// Defines the interface for the application's persistent settings and server configuration.
protocol SettingsStoreProtocol: AnyObject, Sendable {
    // Basic Server Configuration
    var serverUrl: String { get set }
    var apiKey: String { get set }
    var url: URL? { get }
    
    // Whisparr/Radarr Integration
    var whisparrUrl: String { get set }
    var whisparrApiKey: String { get set }
    var whisparrQualityProfileId: Int { get set }
    var whisparrRootFolderPath: String { get set }
    
    // StashDB Integration
    var stashDBApiKey: String { get set }
    var stashDBUrl: String { get }
    var excludeVRFromStashDB: Bool { get set }
    var excludeCompilationsFromStashDB: Bool { get set }
    var excludeOwnedScenesFromStashDB: Bool { get set }
    
    // UI & Behavior Preferences
    var blurNsfw: Bool { get set }
    var followedTagIds: [String] { get }
    var prefetchOnScroll: Bool { get set }
    var showScenePreviews: Bool { get set }
    var muteScenePreviews: Bool { get set }
    var showMarkerPreviews: Bool { get set }
    
    // Maintenance Options
    var generationOptions: GenerationOptions { get set }
    var scanOptions: ScanOptions { get set }
    
    // Status & Feedback
    var isGeneratingContent: Bool { get }
    var generationMessage: String? { get }
    var isScanning: Bool { get }
    var scanMessage: String? { get }
    
    // Actions
    func addFollowedTag(id: String)
    func removeFollowedTag(id: String)
    func createImageUrl(path: String?) -> URL?
    func triggerScan() async
    func triggerGeneration() async
}

// Global logger for settings
nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SettingsStore")

/// Main implementation of `SettingsStoreProtocol` using `@AppStorage` for persistence.
/// This store serves as the single source of truth for user preferences and server connectivity.
@MainActor
final class SettingsStore: ObservableObject, SettingsStoreProtocol {
    public static let shared = SettingsStore()
    
    // MARK: - Stash Server Settings
    @AppStorage("serverUrl") var serverUrl: String = Secrets.serverUrl
    @AppStorage("apiKey") var apiKey: String = Secrets.apiKey
    
    // MARK: - Whisparr Integration Settings
    @AppStorage("whisparrUrl") var whisparrUrl: String = Secrets.whisparrUrl
    @AppStorage("whisparrApiKey") var whisparrApiKey: String = Secrets.whisparrApiKey
    @AppStorage("whisparrQualityProfileId") var whisparrQualityProfileId: Int = Secrets.whisparrQualityProfileId
    @AppStorage("whisparrRootFolderPath") var whisparrRootFolderPath: String = Secrets.whisparrRootFolderPath
    
    // MARK: - StashDB Integration Settings
    @AppStorage("stashDBUrl") var stashDBUrl: String = Secrets.stashDBUrl
    @AppStorage("stashDBApiKey") var stashDBApiKey: String = Secrets.stashDBApiKey
    @AppStorage("excludeVRFromStashDB") var excludeVRFromStashDB: Bool = false
    @AppStorage("excludeCompilationsFromStashDB") var excludeCompilationsFromStashDB: Bool = false
    @AppStorage("excludeOwnedScenesFromStashDB") var excludeOwnedScenesFromStashDB: Bool = true
    
    // MARK: - UI & Behavior Settings
    @AppStorage("followedTagIds") private var followedTagIdsString: String = ""
    @AppStorage("prefetchOnScroll") var prefetchOnScroll: Bool = true
    @AppStorage("showScenePreviews") var showScenePreviews: Bool = false
    @AppStorage("muteScenePreviews") var muteScenePreviews: Bool = true
    @AppStorage("showMarkerPreviews") var showMarkerPreviews: Bool = false
    @AppStorage("blurNsfw") var blurNsfw: Bool = false
    @AppStorage("sceneListLayout") var sceneListLayout: SceneListLayout = .list
    @AppStorage("performerListLayout") var performerListLayout: PerformerLayoutType = .grid2x
    
    // MARK: - Sort Preference Persistence
    @AppStorage("sceneSortType") var sceneSortType: String = "date"
    @AppStorage("sceneSortDirection") var sceneSortDirection: String = "DESC"
    
    @AppStorage("performerSortType") var performerSortType: String = "name"
    @AppStorage("performerSortDirection") var performerSortDirection: String = "ASC"
    
    @AppStorage("studioSortType") var studioSortType: String = "name"
    @AppStorage("studioSortDirection") var studioSortDirection: String = "ASC"
    
    // MARK: - Home Page Settings
    /// Comma-separated list of category IDs in user's preferred order
    @AppStorage("categoryOrder") private var categoryOrderString: String = ""
    
    /// The current order of home page category rows
    var categoryOrder: [String] {
        get {
            guard !categoryOrderString.isEmpty else { return [] }
            return categoryOrderString.split(separator: ",").map { String($0) }
        }
        set {
            categoryOrderString = newValue.joined(separator: ",")
        }
    }
    
    // MARK: - Category Toggle Settings
    @AppStorage("showRandomCategory") var showRandomCategory: Bool = true
    @AppStorage("showRecentlyAddedCategory") var showRecentlyAddedCategory: Bool = true
    @AppStorage("showRecentlyReleasedCategory") var showRecentlyReleasedCategory: Bool = true
    @AppStorage("showTopRatedCategory") var showTopRatedCategory: Bool = true
    @AppStorage("showMostViewedCategory") var showMostViewedCategory: Bool = true
    @AppStorage("showStashDBFavorites") var showStashDBFavorites: Bool = true
    
    
    // MARK: - Complex Type Storage
    @AppStorage("generationOptions") private var generationOptionsData: Data = Data()
    @AppStorage("scanOptions") private var scanOptionsData: Data = Data()
    
    // MARK: - Maintenance Status
    @Published var isGeneratingContent = false
    @Published var generationMessage: String?
    @Published var isScanning = false
    @Published var scanMessage: String?
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // MARK: - Computed Properties
    
    var generationOptions: GenerationOptions {
        get {
            (try? decoder.decode(GenerationOptions.self, from: generationOptionsData)) ?? GenerationOptions()
        }
        set {
            if let data = try? encoder.encode(newValue) {
                generationOptionsData = data
            }
        }
    }
    
    var scanOptions: ScanOptions {
        get {
            (try? decoder.decode(ScanOptions.self, from: scanOptionsData)) ?? ScanOptions()
        }
        set {
            if let data = try? encoder.encode(newValue) {
                scanOptionsData = data
            }
        }
    }
    
    var followedTagIds: [String] {
        followedTagIdsString.isEmpty ? [] : followedTagIdsString.components(separatedBy: ",")
    }
    
    nonisolated var isValid: Bool {
        URL(string: MainActor.assumeIsolated { serverUrl }) != nil
    }
    
    nonisolated var url: URL? {
        URL(string: MainActor.assumeIsolated { serverUrl })
    }
    
    // MARK: - Tag Management
    
    func addFollowedTag(id: String) {
        var current = followedTagIds
        if !current.contains(id) {
            current.append(id)
            followedTagIdsString = current.joined(separator: ",")
            logger.info("➕ Added followed tag: \(id, privacy: .public)")
            NotificationCenter.default.post(name: .followedTagsChanged, object: nil)
        }
    }
    
    func removeFollowedTag(id: String) {
        var current = followedTagIds
        if let index = current.firstIndex(of: id) {
            current.remove(at: index)
            followedTagIdsString = current.joined(separator: ",")
            logger.info("➖ Removed followed tag: \(id, privacy: .public)")
            NotificationCenter.default.post(name: .followedTagsChanged, object: nil)
        }
    }
    
    // MARK: - URL Construction
    
    /// Constructs a fully qualified image URL for the Stash server.
    /// - Parameter path: The relative path to the image.
    /// - Returns: A URL containing the server base and necessary API key.
    nonisolated func createImageUrl(path: String?) -> URL? {
        guard let path = path, !path.isEmpty else { return nil }
        
        // Use assumeIsolated for read-only access to @AppStorage on background threads if safe, 
        // but better to just capture them if possible. Since this is nonisolated, we must be careful.
        let (currentServerUrl, currentApiKey) = MainActor.assumeIsolated { (serverUrl, apiKey) }
        
        guard let serverBase = URL(string: currentServerUrl) else {
            logger.error("❌ Invalid server URL: \(currentServerUrl, privacy: .public)")
            return nil
        }
        
        // Construct base URL by removing /graphql if present
        var baseUrl = serverBase
        if baseUrl.lastPathComponent == "graphql" {
            baseUrl.deleteLastPathComponent()
        }
        
        var finalUrl: URL
        if path.hasPrefix("http") {
             finalUrl = URL(string: path)!
        } else {
             finalUrl = baseUrl.appendingPathComponent(path)
        }
        
        // Append API Key if present
        if !currentApiKey.isEmpty {
            var components = URLComponents(url: finalUrl, resolvingAgainstBaseURL: true)
            let hasApiKey = components?.queryItems?.contains(where: { $0.name == "apikey" }) ?? false
            
            if !hasApiKey {
                var queryItems = components?.queryItems ?? []
                queryItems.append(URLQueryItem(name: "apikey", value: currentApiKey))
                components?.queryItems = queryItems
                if let urlWithKey = components?.url {
                    finalUrl = urlWithKey
                }
            }
        }
        
        return finalUrl
    }
    
    // MARK: - Stash API Tasks
    
    /// Triggers a task-based generation on the Stash server.
    func triggerGeneration() async {
        guard let url = url else {
            generationMessage = "Server URL not configured"
            return
        }
        
        isGeneratingContent = true
        generationMessage = nil
        logger.info("⚡️ Triggering metadata generation...")
        
        do {
            try await performStashTask(url: url, query: StashQueries.metadataGenerate(options: generationOptions))
            generationMessage = "Generation started"
            logger.info("✅ Generation task queued successfully")
        } catch {
            generationMessage = "Failed: \(error.localizedDescription)"
            logger.error("❌ Generation failed: \(error.localizedDescription, privacy: .public)")
        }
        
        isGeneratingContent = false
    }
    
    /// Triggers a file scan on the Stash server.
    func triggerScan() async {
        guard let url = url else {
            scanMessage = "Server URL not configured"
            return
        }
        
        isScanning = true
        scanMessage = nil
        logger.info("🔍 Triggering library scan...")
        
        do {
            try await performStashTask(url: url, query: StashQueries.metadataScan(options: scanOptions))
            logger.info("✅ Scan task queued successfully")
        } catch {
            scanMessage = "Failed: \(error.localizedDescription)"
            logger.error("❌ Scan failed: \(error.localizedDescription, privacy: .public)")
        }
        
        isScanning = false
    }
    
    // MARK: - Private Helpers
    
    /// Generic helper to perform a GraphQL mutation task
    private func performStashTask(url: URL, query: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
        
        let body: [String: Any] = ["query": query, "variables": [:]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppError.network(.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, response: data))
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errors = json["errors"] as? [[String: Any]],
           let firstError = errors.first {
            let message = firstError["message"] as? String ?? "Unknown GraphQL error"
            throw AppError.stashAPI(.graphQLErrors([message]))
        }
    }
}
