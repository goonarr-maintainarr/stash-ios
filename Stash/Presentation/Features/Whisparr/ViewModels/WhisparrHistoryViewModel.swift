import Foundation
import Observation

/// A ViewModel responsible for managing and displaying Whisparr history records.
///
/// `WhisparrHistoryViewModel` fetching paginated history data from the Whisparr API,
/// such as grabbed releases, imports, and failures.
@MainActor
@Observable
class WhisparrHistoryViewModel {
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    /// The current state of the view.
    var state: ViewState = .idle
    
    /// The list of loaded history records.
    var historyRecords: [WhisparrHistoryRecord] = []
    
    /// The current page number for pagination.
    var page = 1
    
    /// Indicates if there are more pages of history to load.
    var hasMore = true
    
    // MARK: - Computed Properties for Compatibility
    
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }
    
    private let repository: WhisparrRepositoryProtocol
    private let pageSize = 20
    
    /// Initializes the `WhisparrHistoryViewModel`.
    ///
    /// - Parameter repository: The Whisparr repository.
    init(repository: WhisparrRepositoryProtocol? = nil) {
        self.repository = repository ?? WhisparrRepository()
    }
    
    /// Loads history records from the Whisparr API.
    ///
    /// - Parameter reset: If `true`, resets pagination and clears existing records before fetching.
    func loadHistory(reset: Bool = false) async {
        if reset {
            page = 1
            historyRecords = []
            hasMore = true
        }
        
        guard hasMore && !isLoading else { return }
        
        state = .loading
        
        do {
            let response = try await repository.fetchHistory(
                page: page,
                pageSize: pageSize,
                sortKey: "date",
                sortDirection: "descending"
            )
            
            if reset {
                historyRecords = response.records
            } else {
                historyRecords.append(contentsOf: response.records)
            }
            
            // Check if we have more pages
            if response.records.count < pageSize || (response.page * response.pageSize) >= response.totalRecords {
                hasMore = false
            } else {
                page += 1
            }
            
            state = .loaded
        } catch {
            state = .error("Failed to load history: \(error.localizedDescription)")
        }
    }
}
