import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "PerformerStashIDManager")

/// Manages StashID selection for navigation.
@MainActor
@Observable
class PerformerStashIDManager {
    
    /// The currently selected StashID for navigation.
    var selectedStashID: Performer.StashID?
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 PerformerStashIDManager initialized")
    }
    
    // MARK: - StashID Management
    
    /// Selects a StashID for navigation.
    func selectStashID(_ stashID: Performer.StashID) {
        logger.info("🔗 Selected StashID: \(stashID.stash_id, privacy: .public)")
        self.selectedStashID = stashID
    }
    
    /// Clears the selected StashID.
    func clearSelection() {
        logger.debug("🗑️ Cleared StashID selection")
        self.selectedStashID = nil
    }
}
