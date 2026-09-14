import Foundation
import Combine

protocol SettingsRepositoryProtocol: Sendable {
    func testStashConnection(url: URL, apiKey: String) async throws
    func testStashDBConnection(apiKey: String) async throws
    func triggerScan(options: ScanOptions) async throws
    func triggerGeneration(options: GenerationOptions) async throws
    
    // MARK: - UI Configuration
    
    func fetchTaggerConfig() async throws -> TaggerConfig
    func saveTaggerConfig(_ config: TaggerConfig) async throws
}
