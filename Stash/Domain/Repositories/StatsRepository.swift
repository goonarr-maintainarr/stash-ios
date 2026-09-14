import Foundation

/// Repository for fetching library statistics from Stash
final class StatsRepository: StatsRepositoryProtocol {
    
    private let graphQLClient: any StashClientProtocol
    private let settings: SettingsStoreProtocol
    
    init(graphQLClient: any StashClientProtocol, settings: SettingsStoreProtocol) {
        self.graphQLClient = graphQLClient
        self.settings = settings
    }
    
    func fetchStats() async throws -> Stats {
        guard let url = settings.url else {
            throw StatsError.serverNotConfigured
        }
        
        return try await graphQLClient.fetchStats(url: url, apiKey: settings.apiKey)
    }
}

// MARK: - Stats Errors

enum StatsError: LocalizedError {
    case serverNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .serverNotConfigured:
            return "Stash server not configured"
        }
    }
}
