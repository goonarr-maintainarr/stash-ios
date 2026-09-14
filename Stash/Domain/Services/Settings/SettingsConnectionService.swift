import Foundation
import os

/// Service responsible for testing connections to Stash and StashDB servers.
///
/// This service handles connection validation for both Stash and StashDB APIs.
class SettingsConnectionService: @unchecked Sendable {
    private let client: StashClientProtocol
    private let settings: SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SettingsConnectionService")
    
    init(client: StashClientProtocol, settings: SettingsStoreProtocol) {
        self.client = client
        self.settings = settings
    }
    
    // MARK: - Connection Testing
    
    /// Tests connection to a Stash server.
    ///
    /// - Parameters:
    ///   - url: The Stash server URL.
    ///   - apiKey: The API key for authentication.
    /// - Throws: An error if the connection test fails.
    func testStashConnection(url: URL, apiKey: String) async throws {
        
        let query = StashQueries.testConnection
        
        do {
            let _: SceneResultDTO = try await client.fetch(query: query, variables: [:], url: url, apiKey: apiKey)
        } catch {
            throw error
        }
    }
    
    /// Tests connection to StashDB.
    ///
    /// - Parameter apiKey: The StashDB API key.
    /// - Throws: An error if the connection test fails.
    func testStashDBConnection(apiKey: String) async throws {
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        guard let url = URL(string: settingsStore.stashDBUrl) else {
            throw AppError.network(.invalidURL(settingsStore.stashDBUrl))
        }
        
        
        // Simple query to test connection - fetch user info
        let query = StashQueries.me
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
        
        let body: [String: Any] = [
            "query": query,
            "variables": [:]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.stashDB(.invalidResponse)
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                throw AppError.stashDB(.networkError(.httpError(statusCode: httpResponse.statusCode, response: nil)))
            }
            
        } catch {
            throw error
        }
    }
    
}
