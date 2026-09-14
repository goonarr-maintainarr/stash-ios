import Foundation
import Combine

/// Base protocol for all repositories
protocol Repository: Sendable {
    associatedtype Entity: Identifiable
    
    /// Fetch all entities
    func getAll() async throws -> [Entity]
    
    /// Fetch a single entity by ID
    func getById(_ id: String) async throws -> Entity?
    
    /// Refresh data from remote source
    func refresh() async throws
}
