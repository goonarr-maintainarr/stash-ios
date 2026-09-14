import Foundation
import os

/// Service responsible for triggering Stash server tasks.
///
/// This service handles scan and generation task operations.
class SettingsTaskService: @unchecked Sendable {
    private let client: StashClientProtocol
    private let settings: SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SettingsTaskService")
    
    init(client: StashClientProtocol, settings: SettingsStoreProtocol) {
        self.client = client
        self.settings = settings
    }
    
    // MARK: - Task Operations
    
    /// Triggers a metadata scan on the Stash server.
    ///
    /// - Parameter options: The scan options to use.
    /// - Throws: An error if the server URL is not configured or the request fails.
    func triggerScan(options: ScanOptions) async throws {
        
        guard let url = settings.url else {
            throw NSError(domain: "SettingsRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Server URL not configured"])
        }
        
        
        let query = StashQueries.metadataScan(options: options)
        
        guard let settingsStore = settings as? SettingsStore else {
            throw NSError(domain: "SettingsRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Settings not available"])
        }
        
        do {
            let _: JSONValue = try await client.fetch(query: query, variables: [:], url: url, apiKey: settingsStore.apiKey)
        } catch {
            throw error
        }
    }
    
    /// Triggers metadata generation on the Stash server.
    ///
    /// - Parameter options: The generation options to use.
    /// - Throws: An error if the server URL is not configured or the request fails.
    func triggerGeneration(options: GenerationOptions) async throws {
        
        guard let url = settings.url else {
            throw NSError(domain: "SettingsRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Server URL not configured"])
        }
        
        
        let query = StashQueries.metadataGenerate(options: options)
        
        guard let settingsStore = settings as? SettingsStore else {
            throw NSError(domain: "SettingsRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Settings not available"])
        }
        
        do {
            let _: JSONValue = try await client.fetch(query: query, variables: [:], url: url, apiKey: settingsStore.apiKey)
        } catch {
            throw error
        }
    }
}

// Helper for generic fetch where we don't care about result content
struct JSONValue: Decodable {}
