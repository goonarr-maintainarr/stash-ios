import Foundation
import os

/// Repository for managing settings-related operations.
///
/// This repository acts as a coordinator, delegating operations to specialized service classes
/// for better separation of concerns and maintainability.
class SettingsRepository: SettingsRepositoryProtocol {
    
    // Service layer
    private let connectionService: SettingsConnectionService
    private let taskService: SettingsTaskService
    private let uiService: SettingsUIService
    
    init(client: StashClientProtocol, settings: SettingsStoreProtocol) {
        self.connectionService = SettingsConnectionService(client: client, settings: settings)
        self.taskService = SettingsTaskService(client: client, settings: settings)
        self.uiService = SettingsUIService(client: client, settings: settings)
    }
    
    // MARK: - Connection Testing
    
    func testStashConnection(url: URL, apiKey: String) async throws {
        try await connectionService.testStashConnection(url: url, apiKey: apiKey)
    }
    
    func testStashDBConnection(apiKey: String) async throws {
        try await connectionService.testStashDBConnection(apiKey: apiKey)
    }
    
    // MARK: - Task Operations
    
    func triggerScan(options: ScanOptions) async throws {
        try await taskService.triggerScan(options: options)
    }
    
    func triggerGeneration(options: GenerationOptions) async throws {
        try await taskService.triggerGeneration(options: options)
    }
    
    // MARK: - UI Configuration
    
    func fetchTaggerConfig() async throws -> TaggerConfig {
        try await uiService.fetchTaggerConfig()
    }
    
    func saveTaggerConfig(_ config: TaggerConfig) async throws {
        try await uiService.saveTaggerConfig(config)
    }
}
