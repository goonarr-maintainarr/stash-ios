import Foundation

enum SceneListLayout: String, CaseIterable, Identifiable, Codable {
    case list
    case grid
    case compact
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .compact: return "Compact"
        }
    }
    
    var iconName: String {
        switch self {
        case .list: return "rectangle.grid.1x2"
        case .grid: return "square.grid.2x2"
        case .compact: return "list.bullet"
        }
    }
}
