import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class StatsViewModel {
    
    enum State: Equatable {
        case idle
        case loading
        case loaded(Stats)
        case error(String)
    }
    
    var state: State = .idle
    
    private let repository: StatsRepositoryProtocol
    
    init(repository: StatsRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Computed Properties
    
    var stats: Stats? {
        if case .loaded(let stats) = state {
            return stats
        }
        return nil
    }
    
    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }
    
    // MARK: - Public Methods
    
    func loadStats() async {
        state = .loading
        
        do {
            let stats = try await repository.fetchStats()
            state = .loaded(stats)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() async {
        await loadStats()
    }
}
