import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditSceneHistoryManager")

/// Manages O-counter and play history for scene editing.
@MainActor
@Observable
class EditSceneHistoryManager {
    
    // MARK: - Observable Properties
    
    var oHistory: [String]
    var playHistory: [String]
    
    // MARK: - Private Properties
    
    // Track removed history entries for deletion
    private(set) var removedOHistory: [String] = []
    private(set) var removedPlayHistory: [String] = []
    
    // MARK: - Initialization
    
    init(oHistory: [String], playHistory: [String]) {
        self.oHistory = oHistory
        self.playHistory = playHistory
        
        logger.debug("🔧 EditSceneHistoryManager initialized (O: \(oHistory.count), Play: \(playHistory.count))")
    }
    
    // MARK: - Public Methods
    
    /// Removes an O-counter history entry.
    func removeOHistory(at timestamp: String) {
        if let index = oHistory.firstIndex(of: timestamp) {
            oHistory.remove(at: index)
            removedOHistory.append(timestamp)
            logger.info("🗑️ Removed O-counter entry: \(timestamp)")
        }
    }
    
    /// Removes a play history entry.
    func removePlayHistory(at timestamp: String) {
        if let index = playHistory.firstIndex(of: timestamp) {
            playHistory.remove(at: index)
            removedPlayHistory.append(timestamp)
            logger.info("🗑️ Removed play history entry: \(timestamp)")
        }
    }
    
    /// Clears the removed history tracking after successful save.
    func clearRemovedTracking() {
        removedOHistory.removeAll()
        removedPlayHistory.removeAll()
        logger.debug("✅ Cleared removed history tracking")
    }
    
    /// Gets the list of removed O-counter entries.
    func getRemovedOHistory() -> [String] {
        return removedOHistory
    }
    
    /// Gets the list of removed play history entries.
    func getRemovedPlayHistory() -> [String] {
        return removedPlayHistory
    }
}
