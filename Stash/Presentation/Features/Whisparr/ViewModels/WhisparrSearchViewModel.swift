import os
import Foundation
import SwiftUI
import Observation
import Combine

/// A ViewModel responsible for managing search operations against the Whisparr API.
///
/// `WhisparrSearchViewModel` handles text-based searching for scenes, debouncing inputs,
/// and filtering results based on items already present in the user's Whisparr library.

private let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSearchViewModel")

@MainActor
@Observable
class WhisparrSearchViewModel {
    
    // MARK: - ViewState
    
    /// Represents the current state of the search view.
    enum ViewState: Equatable {
        /// No search performed yet.
        case idle
        /// Search is in progress.
        case searching
        /// Search completed with results.
        case results([WhisparrSearchResult])
        /// Search completed with no results.
        case empty
        /// An error occurred during search.
        case error(String)
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.searching, .searching), (.empty, .empty):
                return true
            case let (.results(r1), .results(r2)):
                return r1.map { $0.foreignId } == r2.map { $0.foreignId }
            case let (.error(e1), .error(e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }
    
    /// The current state of the search view.
    var state: ViewState = .idle
    
    /// The current search text entered by the user.
    var searchText = "" {
        didSet {
            // Cancel previous search
            searchTask?.cancel()
            
            // Debounce by delaying the search
            searchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if !Task.isCancelled {
                    await performSearch(term: searchText)
                }
            }
        }
    }
    
    // MARK: - Computed Properties for Compatibility
    
    /// The search results (empty if not in results state).
    var results: [WhisparrSearchResult] {
        if case .results(let items) = state { return items }
        return []
    }
    
    /// Indicates if a search is currently in progress.
    var isSearching: Bool {
        if case .searching = state { return true }
        return false
    }
    
    /// Error message, if any.
    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }
    
    private let repository: WhisparrRepositoryProtocol
    private let settings: SettingsStore
    private var searchTask: Task<Void, Never>?
    private var libraryForeignIds: Set<String> = []
    
    /// Initializes the `WhisparrSearchViewModel`.
    ///
    /// - Parameters:
    ///   - repository: The Whisparr repository.
    ///   - settings: The user settings store.
    init(repository: WhisparrRepositoryProtocol? = nil, settings: SettingsStore? = nil) {
        self.settings = settings ?? .shared
        self.repository = repository ?? WhisparrRepository(settings: self.settings)
        
        // Fetch library on init
        Task {
            await fetchLibraryForeignIds()
        }
    }
    
    /// Fetches the IDs of all items in the user's Whisparr library.
    ///
    /// This is used to filter search results so that users don't see items they already own.
    private func fetchLibraryForeignIds() async {
        do {
            let movies = try await repository.getCachedScenes()
            
            // Extract all foreignIds from library
            libraryForeignIds = Set(movies.compactMap { $0.foreignId })
        } catch {
            // Silent fail - if we can't fetch library, we just won't filter
            logger.error("Failed to fetch Whisparr library for filtering: \(error)")
        }
    }
    
    /// Performs a search for items matching the given term.
    ///
    /// - Parameter term: The search query.
    private func performSearch(term: String) async {
        // Cancel any existing search
        searchTask?.cancel()
        
        // Clear results if search is empty
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else {
            state = .idle
            return
        }
        
        searchTask = Task { @MainActor in
            state = .searching
            
            do {
                let searchResults = try await repository.searchScenes(term: term)
                
                if !Task.isCancelled {
                    // Filter out results that are already in library
                    let filteredResults = searchResults.filter { result in
                        !libraryForeignIds.contains(result.foreignId)
                    }
                    
                    if filteredResults.isEmpty {
                        state = .empty
                    } else {
                        state = .results(filteredResults)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    state = .error(error.localizedDescription)
                }
            }
        }
        
        await searchTask?.value
    }
}
