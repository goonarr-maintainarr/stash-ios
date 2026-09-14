import Foundation
import Observation

/// Observable state container for TagSelectionViewModel.
/// Encapsulates all published state for @Observable migration.
@MainActor
@Observable
final class TagSelectionState {
    
    // MARK: - View State
    
    var state: ListViewState<Tag> = .loading
    var isFetching: Bool = false // Kept for protocol consistency if needed, though mostly local
    var searchText: String = ""
    var totalCount: Int = 0
    var alertMessage: String? = nil
    
    // MARK: - Data Storage
    
    var allItems: [Tag] = []       // All tags fetched from DB
    var cachedItems: [Tag] = []    // Same as allItems for this VM usually
    var selectedTags: [Tag] = []   // Followed tags
    
    // MARK: - Computed Properties
    
    /// Returns the currently displayed items from the state.
    var items: [Tag] {
        if case .content(let tags) = state { return tags }
        return []
    }
    
    // MARK: - State Mutations
    
    /// Updates the content state with new items.
    func updateContent(_ newItems: [Tag]) {
        if newItems.isEmpty {
            state = .empty
        } else {
            state = .content(newItems)
        }
        totalCount = newItems.count
    }
    
    func removeTag(_ tagId: String) {
        allItems.removeAll { $0.id == tagId }
        cachedItems.removeAll { $0.id == tagId }
        selectedTags.removeAll { $0.id == tagId }
        
        if case .content(var currentItems) = state {
            currentItems.removeAll { $0.id == tagId }
            updateContent(currentItems)
        }
    }
    
    func updateSelectedTags(_ tags: [Tag]) {
        self.selectedTags = tags
    }
}
