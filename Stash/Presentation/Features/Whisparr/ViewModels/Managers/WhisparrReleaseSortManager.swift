import Foundation
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrReleaseSortManager")

/// Sorting options available for Whisparr releases.
enum WhisparrReleaseSort: String, CaseIterable, Identifiable {
    /// Sort by age (days since release).
    case age = "Age"
    /// Sort by quality weight.
    case quality = "Quality"
    /// Sort by peer count (seeders).
    case peers = "Peers"
    /// Sort by file size.
    case size = "Size"
    /// Sort by release weight (internal scoring).
    case weight = "Weight"
    /// Sort by custom format score.
    case customScore = "Custom Score"
    
    var id: String { rawValue }
}

/// Manages sorting logic for Whisparr releases.
@MainActor
@Observable
class WhisparrReleaseSortManager {
    
    // MARK: - State
    
    /// The current sort criteria. Persisted to UserDefaults.
    var sort: WhisparrReleaseSort {
        didSet {
            UserDefaults.standard.set(sort.rawValue, forKey: "WhisparrReleaseSort")
            logger.debug("🔀 Sort changed to: \(self.sort.rawValue, privacy: .public)")
        }
    }
    
    /// The sort direction (Ascending/Descending). Persisted to UserDefaults.
    var sortAscending: Bool {
        didSet {
            UserDefaults.standard.set(sortAscending, forKey: "WhisparrReleaseSortAscending")
            let direction = sortAscending ? "Ascending" : "Descending"
            logger.debug("🔄 Sort direction changed to: \(direction, privacy: .public)")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Load persisted sort preferences
        if let savedSort = UserDefaults.standard.string(forKey: "WhisparrReleaseSort"),
           let sortType = WhisparrReleaseSort(rawValue: savedSort) {
            self.sort = sortType
        } else {
            self.sort = .age
        }
        
        self.sortAscending = UserDefaults.standard.object(forKey: "WhisparrReleaseSortAscending") as? Bool ?? false
        
        logger.debug("🔧 WhisparrReleaseSortManager initialized (Sort: \(self.sort.rawValue, privacy: .public), Ascending: \(self.sortAscending, privacy: .public))")
    }
    
    // MARK: - Public Methods
    
    /// Applies current sort settings to the given releases.
    func applySort(to releases: [WhisparrRelease]) -> [WhisparrRelease] {
        var result = releases
        
        switch sort {
        case .age:
            // Age is days since release. 
            // Ascending (true): 0 days ... 1000 days (Newest first)
            // Descending (false): 1000 days ... 0 days (Oldest first)
            // Default expected behavior for "Age" sort is usually Newest First (Smallest Age).
            // However, "Ascending" normally means Small -> Large.
            // If sortAscending is true, we obey strict numeric ascending ($0 < $1).
            // This is actually "Newest First" for Age.
            result.sort { sortAscending ? $0.age < $1.age : $0.age > $1.age }
            let direction = sortAscending ? "Ascending" : "Descending"
            logger.debug("📅 Sorted by age (\(direction, privacy: .public))")
            
        case .quality:
            // Quality Weight: Higher is Better.
            // Ascending (true): 0 ... 100 (Worst first)
            // Descending (false): 100 ... 0 (Best first)
            result.sort { sortAscending ? $0.qualityWeight < $1.qualityWeight : $0.qualityWeight > $1.qualityWeight }
            let direction = sortAscending ? "Ascending" : "Descending"
            logger.debug("⭐ Sorted by quality (\(direction, privacy: .public))")
            
        case .peers:
             // Seeders: Higher is Better.
             result.sort { 
                 let s1 = $0.seeders ?? -1
                 let s2 = $1.seeders ?? -1
                 return sortAscending ? s1 < s2 : s1 > s2
             }
             let direction = sortAscending ? "Ascending" : "Descending"
             logger.debug("👥 Sorted by peers (\(direction, privacy: .public))")
             
        case .size:
            // Size: Higher is Bigger.
            // Ascending: Small -> Big
            // Descending: Big -> Small
            result.sort { sortAscending ? $0.size < $1.size : $0.size > $1.size }
            let direction = sortAscending ? "Ascending" : "Descending"
            logger.debug("💾 Sorted by size (\(direction, privacy: .public))")
            
        case .weight:
            // Release Weight
             result.sort {
                 let w1 = $0.releaseWeight ?? 0
                 let w2 = $1.releaseWeight ?? 0
                 return sortAscending ? w1 < w2 : w1 > w2
             }
             let direction = sortAscending ? "Ascending" : "Descending"
             logger.debug("⚖️ Sorted by weight (\(direction, privacy: .public))")
             
        case .customScore:
            // Custom Format Score
            result.sort {
                let s1 = $0.customFormatScore ?? 0
                let s2 = $1.customFormatScore ?? 0
                return sortAscending ? s1 < s2 : s1 > s2
            }
            let direction = sortAscending ? "Ascending" : "Descending"
            logger.debug("🎯 Sorted by custom score (\(direction, privacy: .public))")
        }
        
        return result
    }
}
