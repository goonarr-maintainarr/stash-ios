import Foundation

enum SceneCategoryType: String, Equatable, Hashable, Sendable {
    case localScenes
    case stashDBScenes
}

struct SceneCategory: Identifiable, Hashable, Sendable {
    var id: String { title }
    let title: String
    let sortType: SceneSortType
    let sortDirection: String
    let tagIds: [String]?
    let count: Int?
    let type: SceneCategoryType
    var scenes: [Scene] = []
    var stashDBScenes: [StashDBScene] = []
    
    init(title: String, sortType: SceneSortType, sortDirection: String = "DESC", tagIds: [String]? = nil, count: Int? = nil, type: SceneCategoryType = .localScenes) {
        self.title = title
        self.sortType = sortType
        self.sortDirection = sortDirection
        self.tagIds = tagIds
        self.count = count
        self.type = type
    }
}
