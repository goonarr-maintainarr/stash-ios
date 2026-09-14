import Foundation
import Combine

/// Protocol for fetching library statistics
protocol StatsRepositoryProtocol {
    /// Fetches library statistics from the Stash server
    func fetchStats() async throws -> Stats
}
