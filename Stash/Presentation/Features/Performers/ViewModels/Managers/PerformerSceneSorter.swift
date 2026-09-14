import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerSceneSorter")

/// Manages scene sorting for performer detail view.
@MainActor
@Observable
class PerformerSceneSorter {
    
    /// The criteria used to sort the performer's scenes.
    var sortType: SceneSortType = .date
    
    /// The direction of the sort ("ASC" or "DESC").
    var sortDirection: String = "DESC"
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 PerformerSceneSorter initialized")
    }
    
    // MARK: - Sorting
    
    /// Sorts scenes based on current sort type and direction.
    ///
    /// - Parameter scenes: The scenes to sort.
    /// - Returns: Sorted array of scenes.
    func sortScenes(_ scenes: [Scene]) -> [Scene] {
        let ascending = sortDirection == "ASC"
        let sortedScenes: [Scene]
        
        logger.debug("🔀 Sorting \(scenes.count) scenes by \(String(describing: self.sortType)) (\(self.sortDirection))")
        
        switch sortType {
        case .createdAt:
            sortedScenes = scenes.sorted { ascending ? ($0.created_at ?? "") < ($1.created_at ?? "") : ($0.created_at ?? "") > ($1.created_at ?? "") }
        case .date:
            sortedScenes = scenes.sorted { ascending ? ($0.date ?? "") < ($1.date ?? "") : ($0.date ?? "") > ($1.date ?? "") }
        case .rating:
            sortedScenes = scenes.sorted { ascending ? ($0.rating100 ?? 0) < ($1.rating100 ?? 0) : ($0.rating100 ?? 0) > ($1.rating100 ?? 0) }
        case .oCounter:
            sortedScenes = scenes.sorted { ascending ? ($0.o_counter ?? 0) < ($1.o_counter ?? 0) : ($0.o_counter ?? 0) > ($1.o_counter ?? 0) }
        case .random:
            sortedScenes = scenes.shuffled()
        case .updatedAt:
            sortedScenes = scenes.sorted { ascending ? ($0.updated_at ?? "") < ($1.updated_at ?? "") : ($0.updated_at ?? "") > ($1.updated_at ?? "") }
        }
        
        logger.info("✅ Sorted \(sortedScenes.count) scenes")
        return sortedScenes
    }
}
