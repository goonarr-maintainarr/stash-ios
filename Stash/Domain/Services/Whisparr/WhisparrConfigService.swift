import Foundation
import os

/// Service responsible for managing Whisparr configuration and settings.
///
/// This service handles fetching quality profiles, root folders, and other configuration data.
class WhisparrConfigService: @unchecked Sendable {
    private let apiClient: WhisparrClientProtocol
    private let settings: any SettingsStoreProtocol
    
    nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrConfigService")
    
    init(apiClient: WhisparrClientProtocol, settings: any SettingsStoreProtocol) {
        self.apiClient = apiClient
        self.settings = settings
    }
    
    
    // MARK: - Configuration Fetch Operations
    
    /// Fetches available quality profiles from Whisparr.
    ///
    /// - Returns: An array of `WhisparrQualityProfile`.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchQualityProfiles() async throws -> [WhisparrQualityProfile] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let profiles = try await apiClient.fetchQualityProfiles(
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return profiles
        } catch {
            throw error
        }
    }
    
    /// Fetches available root folders from Whisparr.
    ///
    /// - Returns: An array of `WhisparrRootFolder`.
    /// - Throws: `RepositoryError` if configuration is invalid.
    func fetchRootFolders() async throws -> [WhisparrRootFolder] {
        try settings.validateWhisparrConfiguration()
        
        guard let settingsStore = settings as? SettingsStore else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        do {
            let folders = try await apiClient.fetchRootFolders(
                url: settingsStore.whisparrUrl,
                apiKey: settingsStore.whisparrApiKey
            )
            
            return folders
        } catch {
            throw error
        }
    }
}
