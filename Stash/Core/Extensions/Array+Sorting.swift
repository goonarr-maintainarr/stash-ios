import Foundation

// MARK: - Scene Sorting

// MARK: - Scene Sorting

extension Array where Element == Scene {
    /// Sorts scenes by the specified sort type and direction.
    ///
    /// - Parameters:
    ///   - sortType: The field to sort by.
    ///   - ascending: If true, sorts in ascending order; otherwise descending.
    ///   - randomCache: Optional cached random order to maintain consistency.
    /// - Returns: A sorted array of scenes.
    func sorted(by sortType: SceneSortType, ascending: Bool, randomCache: inout [Scene]?) -> [Scene] {
        // Handle random sort separately to preserve cached order
        if sortType == .random {
            if let cached = randomCache {
                return cached
            } else {
                let shuffled = self.shuffled()
                randomCache = shuffled
                return shuffled
            }
        }
        
        // Clear random cache for non-random sorts
        randomCache = nil
        
        return sorted(by: sortType, ascending: ascending)
    }
    
    /// Sorts scenes by the specified sort type and direction.
    ///
    /// - Parameters:
    ///   - sortType: The field to sort by.
    ///   - ascending: If true, sorts in ascending order; otherwise descending.
    /// - Returns: A sorted array of scenes.
    func sorted(by sortType: SceneSortType, ascending: Bool) -> [Scene] {
        switch sortType {
        case .createdAt:
            return sorted {
                let val1 = $0.created_at ?? ""
                let val2 = $1.created_at ?? ""
                return ascending ? val1 < val2 : val1 > val2
            }
        case .date:
            return sorted {
                let val1 = $0.date ?? ""
                let val2 = $1.date ?? ""
                return ascending ? val1 < val2 : val1 > val2
            }
        case .rating:
            return sorted {
                let val1 = $0.rating100 ?? 0
                let val2 = $1.rating100 ?? 0
                return ascending ? val1 < val2 : val1 > val2
            }
        case .oCounter:
            return sorted {
                let val1 = $0.o_counter ?? 0
                let val2 = $1.o_counter ?? 0
                return ascending ? val1 < val2 : val1 > val2
            }
        case .updatedAt:
            return sorted {
                let val1 = $0.updated_at ?? ""
                let val2 = $1.updated_at ?? ""
                return ascending ? val1 < val2 : val1 > val2
            }
        case .random:
            return shuffled()
        }
    }
}

// MARK: - Performer Sorting

extension Array where Element == Performer {
    /// Sorts performers by the specified sort type and direction.
    ///
    /// - Parameters:
    ///   - sortType: The field to sort by.
    ///   - ascending: If true, sorts in ascending order; otherwise descending.
    /// - Returns: A sorted array of performers.
    func sorted(by sortType: PerformerSortType, ascending: Bool) -> [Performer] {
        switch sortType {
        case .name:
            return sorted {
                let val1 = $0.name ?? ""
                let val2 = $1.name ?? ""
                return ascending ? val1 < val2 : val1 > val2
            }
        case .sceneCount:
            return sorted {
                let val1 = $0.scene_count ?? 0
                let val2 = $1.scene_count ?? 0
                return ascending ? val1 < val2 : val1 > val2
            }
        case .oCounter:
            return sorted {
                let val1 = $0.o_counter ?? 0
                let val2 = $1.o_counter ?? 0
                return ascending ? val1 < val2 : val1 > val2
            }
        case .createdAt:
            return sorted {
                let val1 = $0.created_at ?? ""
                let val2 = $1.created_at ?? ""
                return ascending ? val1 < val2 : val1 > val2
            }
        case .updatedAt:
            return sorted {
                let val1 = $0.updated_at ?? ""
                let val2 = $1.updated_at ?? ""
                return ascending ? val1 < val2 : val1 > val2
            }
        }
    }
}

// MARK: - Whisparr Scene Sorting

extension Array where Element == WhisparrScene {
    /// Sorts Whisparr scenes by the specified sort type and direction.
    ///
    /// - Parameters:
    ///   - sortType: The field to sort by.
    ///   - ascending: If true, sorts in ascending order; otherwise descending.
    /// - Returns: A sorted array of Whisparr scenes.
    func sorted(by sortType: WhisparrSortType, ascending: Bool) -> [WhisparrScene] {
        switch sortType {
        case .title:
            return sorted {
                let val1 = $0.title
                let val2 = $1.title
                return ascending ? val1 < val2 : val1 > val2
            }
        case .year:
            return sorted {
                let val1 = $0.year
                let val2 = $1.year
                return ascending ? val1 < val2 : val1 > val2
            }
        case .dateAdded:
            return sorted {
                let val1 = $0.added
                let val2 = $1.added
                return ascending ? val1 < val2 : val1 > val2
            }
        case .fileSize:
            let getSize: (WhisparrScene) -> Int64 = { scene in
                scene.sceneFile?.size ?? 0
            }
            return sorted {
                let val1 = getSize($0)
                let val2 = getSize($1)
                return ascending ? val1 < val2 : val1 > val2
            }
        case .releaseDate:
            return sorted {
                let val1 = $0.releaseDate ?? Date.distantPast
                let val2 = $1.releaseDate ?? Date.distantPast
                return ascending ? val1 < val2 : val1 > val2
            }
        }
    }
}
