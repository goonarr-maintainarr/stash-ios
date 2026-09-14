import Foundation
import os

/// Service responsible for executing commands on the Whisparr server.
///
/// This service handles command execution including searches and automated tasks.
class WhisparrCommandService: @unchecked Sendable {
    private let apiClient: WhisparrClientProtocol
    private let settings: any SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrCommandService")
    
    init(apiClient: WhisparrClientProtocol, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.settings = settings
    }
    

    
    // MARK: - Command Execution
    
    /// Executes a generic command on the Whisparr server.
    ///
    /// - Parameter command: The command object to execute.
    /// - Throws: `RepositoryError` if configuration is invalid or request fails.
    func executeCommand(_ command: WhisparrSearchCommand) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            try await apiClient.executeCommand(
                command: command,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
        } catch {
            throw error
        }
    }
    
    /// Triggers an automatic search for a specific scene.
    ///
    /// - Parameter sceneId: The ID of the scene to search for.
    /// - Throws: `RepositoryError` if configuration is invalid or request fails.
    func performAutomaticSearch(sceneId: Int) async throws {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        let command = WhisparrSearchCommand(name: "MoviesSearch", movieIds: [sceneId])
        
        do {
            try await apiClient.executeCommand(
                command: command,
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
        } catch {
            throw error
        }
    }
}
