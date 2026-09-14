import Foundation

/// Sort options for scene list queries in the Stash API.
enum SceneSortType: String, CaseIterable, Identifiable, Codable, SortableType {
    case random = "random"
    case createdAt = "created_at"
    case date = "date"
    case rating = "rating"
    case oCounter = "o_counter"
    case updatedAt = "updated_at"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .random: return "Random"
        case .createdAt: return "Created At"
        case .updatedAt: return "Updated At"
        case .date: return "Date"
        case .rating: return "Rating"
        case .oCounter: return "O Count"
        }
    }
    
    var iconName: String {
        switch self {
        case .random: return "shuffle"
        case .createdAt: return "calendar.badge.plus"
        case .updatedAt: return "calendar.badge.clock"
        case .date: return "calendar"
        case .rating: return "star"
        case .oCounter: return "o.circle"
        }
    }
    
    var customIconName: String? {
        switch self {
        case .oCounter: return "SweatDrops"
        default: return nil
        }
    }
}
