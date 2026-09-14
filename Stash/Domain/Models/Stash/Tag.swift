import Foundation
import GRDB

struct Tag: Identifiable, Codable, Equatable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    let id: String
    let name: String
    let scene_count: Int?
    let description: String?
    
    // MARK: - GRDB
    
    static let databaseTableName = "tags"
    
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let scene_count = Column("scene_count")
        static let description = Column("description")
    }
}

struct TagResult: Decodable {
    let findTags: TagConnection
}

struct TagDetailResult: Decodable {
    let findTag: Tag
}

struct TagConnection: Decodable {
    let tags: [Tag]
    let count: Int
}
