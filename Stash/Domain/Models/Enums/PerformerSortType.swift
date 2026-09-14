import Foundation

/// Sort options for performer list queries in the Stash API.
enum PerformerSortType: String, CaseIterable, Identifiable, SortableType {
    case name = "name"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case sceneCount = "scene_count"
    case oCounter = "o_counter"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .createdAt: return "Created At"
        case .updatedAt: return "Updated At"
        case .sceneCount: return "Scene Count"
        case .oCounter: return "O Count"
        }
    }
    
    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .createdAt: return "calendar.badge.plus"
        case .updatedAt: return "calendar.badge.clock"
        case .sceneCount: return "film"
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
