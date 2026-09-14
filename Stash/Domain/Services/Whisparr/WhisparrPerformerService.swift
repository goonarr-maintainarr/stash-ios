import Foundation
import os

@MainActor
final class WhisparrPerformerService {
    private nonisolated static let logger = Logger(subsystem: "com.stash.app", category: "WhisparrPerformerService")
    
    static let shared = WhisparrPerformerService(
        settingsStore: SettingsStore.shared,
        stashDatabase: .shared
    )
    
    // Dependencies
    private let settingsStore: SettingsStoreProtocol
    private let stashDatabase: StashDatabase
    
    init(settingsStore: SettingsStoreProtocol, stashDatabase: StashDatabase) {
        self.settingsStore = settingsStore
        self.stashDatabase = stashDatabase
    }
    
    static func create() -> WhisparrPerformerService {
        WhisparrPerformerService(
            settingsStore: SettingsStore.shared,
            stashDatabase: .shared
        )
    }
    
    /// Fetches detailed performer information from StashDB for the given credits.
    ///
    /// - Parameter credits: List of Whisparr credits (performers).
    /// - Returns: A dictionary of `StashDBPerformer` objects keyed by their foreign ID (Stash ID).
    func fetchPerformerDetails(for credits: [WhisparrCredit]) async -> [String: StashDBPerformer] {
        let client = StashDBClient(apiKey: settingsStore.stashDBApiKey, baseURL: settingsStore.stashDBUrl)
        var details: [String: StashDBPerformer] = [:]
        
        await withTaskGroup(of: (String, StashDBPerformer?).self) { group in
            for credit in credits {
                group.addTask {
                    do {
                        let performer = try await client.fetchPerformerDetails(performerId: credit.performer.foreignId)
                        return (credit.performer.foreignId, performer)
                    } catch {
                        if (error as? URLError)?.code == .cancelled || error is CancellationError {
                            // Ignore cancellation
                        } else {
                            Self.logger.error("Failed to fetch performer details for \(credit.performer.name ?? "Unknown"): \(error)")
                        }
                        return (credit.performer.foreignId, nil)
                    }
                }
            }
            
            for await (performerId, performer) in group {
                if let performer = performer {
                    details[performerId] = performer
                }
            }
        }
        
        return details
    }
    

}
