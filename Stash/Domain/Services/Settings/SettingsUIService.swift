import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SettingsUIService")

/// Service responsible for UI-related configuration settings stored on the Stash server.
class SettingsUIService {
    
    // MARK: - Dependencies
    
    private let client: StashClientProtocol
    private let settings: SettingsStoreProtocol
    
    // MARK: - Initialization
    
    init(client: StashClientProtocol, settings: SettingsStoreProtocol) {
        self.client = client
        self.settings = settings
    }
    
    // MARK: - Public Methods
    
    /// Fetches the tagger configuration from the server.
    func fetchTaggerConfig() async throws -> TaggerConfig {
        guard let url = settings.url else {
            throw AppError.repository(.invalidConfiguration)
        }
        
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
            let result: TaggerConfigResponse = try await client.fetch(
                query: StashQueries.taggerConfig,
                variables: nil,
                url: url,
                apiKey: settings.apiKey
            )
            
            let config = result.configuration.ui.taggerConfig ?? .default
            logger.debug("✅ Successfully fetched tagger config")
            return config
        } catch let error as StashAPIError {
            throw AppError.stashAPI(error)
        } catch let error as URLError {
            throw AppError.network(error.toNetworkError())
        } catch {
            throw AppError.unknown(error)
        }
    }
    
    /// Saves the tagger configuration to the server.
    func saveTaggerConfig(_ config: TaggerConfig) async throws {
        guard let url = settings.url else {
            throw AppError.repository(.invalidConfiguration)
        }
        
        logger.debug("💾 Saving tagger configuration to \(url.absoluteString, privacy: .public)")
        
        // Convert config to dictionary for Any! GraphQL variable
        let data = try JSONEncoder().encode(config)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        struct EmptyResult: Decodable {}
        
        do {
            let _: EmptyResult = try await client.fetch(
                query: StashQueries.configureTaggerConfig,
                variables: ["config": dict],
                url: url,
                apiKey: settings.apiKey
            )
            logger.info("✅ Successfully saved tagger configuration")
        } catch let error as StashAPIError {
            throw AppError.stashAPI(error)
        } catch let error as URLError {
            throw AppError.network(error.toNetworkError())
        } catch {
            throw AppError.unknown(error)
        }
    }
}
