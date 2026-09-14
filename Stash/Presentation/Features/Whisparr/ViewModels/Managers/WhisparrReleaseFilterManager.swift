import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrReleaseFilterManager")

/// Filter criteria for Whisparr releases.
struct WhisparrReleaseFilters {
    /// Filter by specific protocol (e.g., "torrent", "usenet").
    var protocolType: String?
    /// Filter by specific indexer name.
    var indexer: String?
    /// Whether to show rejected releases (releases that don't meet profile criteria).
    var showRejected: Bool = true // Default to true so users can see all results initially
    /// Text search query to filter releases by title.
    var searchQuery: String = ""
    
    /// Indicates if any filters are currently active.
    var isFiltering: Bool {
        protocolType != nil || indexer != nil || !searchQuery.isEmpty || !showRejected
    }
}

/// Manages filtering logic for Whisparr releases.
@MainActor
@Observable
class WhisparrReleaseFilterManager {
    
    // MARK: - State
    
    /// The active filter configuration.
    var filters: WhisparrReleaseFilters
    
    /// List of available protocols found in the fetched releases.
    var availableProtocols: [String] = []
    
    /// List of available indexers found in the fetched releases.
    var availableIndexers: [String] = []
    
    // MARK: - Initialization
    
    init() {
        let showRejected = UserDefaults.standard.object(forKey: "WhisparrFilterShowRejected") as? Bool ?? true
        self.filters = WhisparrReleaseFilters(showRejected: showRejected)
        
        logger.debug("🔧 WhisparrReleaseFilterManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Extracts unique filter options (protocols, indexers) from the raw release list.
    func extractFilterOptions(from releases: [WhisparrRelease]) {
        let protocols = Set(releases.compactMap { $0.protocol }).sorted()
        let indexers = Set(releases.compactMap { $0.indexer }).sorted()
        
        availableProtocols = protocols
        availableIndexers = indexers
        
        logger.debug("🏷️ Extracted \(protocols.count, privacy: .public) protocols, \(indexers.count, privacy: .public) indexers")
    }
    
    /// Applies current filters to the given releases.
    func applyFilters(to releases: [WhisparrRelease]) -> [WhisparrRelease] {
        var result = releases
        
        // 1. Filter by Search Query
        if !filters.searchQuery.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(filters.searchQuery) }
            logger.debug("🔍 Filtered by search query: '\(self.filters.searchQuery, privacy: .public)' -> \(result.count, privacy: .public) releases")
        }
        
        // 2. Filter by Protocol
        if let proto = filters.protocolType {
            result = result.filter { $0.protocol == proto }
            logger.debug("📡 Filtered by protocol: '\(proto, privacy: .public)' -> \(result.count, privacy: .public) releases")
        }
        
        // 3. Filter by Indexer
        if let idx = filters.indexer {
            result = result.filter { $0.indexer == idx }
            logger.debug("🔍 Filtered by indexer: '\(idx, privacy: .public)' -> \(result.count, privacy: .public) releases")
        }
        
        // 4. Filter Rejected
        if !filters.showRejected {
            let beforeCount = result.count
            result = result.filter { $0.rejected == false || $0.rejected == nil }
            logger.debug("❌ Filtered out rejected releases: \(beforeCount, privacy: .public) -> \(result.count, privacy: .public)")
        }
        
        logger.info("✅ Filtered to \(result.count, privacy: .public) releases (Total: \(releases.count, privacy: .public))")
        
        return result
    }
    
    /// Updates the "Show Rejected" filter preference.
    func updateShowRejected(_ show: Bool) {
        filters.showRejected = show
        UserDefaults.standard.set(show, forKey: "WhisparrFilterShowRejected")
        logger.debug("🔄 Updated showRejected filter to: \(show, privacy: .public)")
    }
}
