import Foundation
import GRDB

struct Studio: Identifiable, Codable, Equatable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    let id: String
    let name: String
    let urls: [String]?
    let parent_studio: SimpleStudio?
    let child_studios: [SimpleStudio]?
    let aliases: [String]?
    let tags: [Tag]?
    let ignore_auto_tag: Bool?
    let image_path: String?
    
    // Counts
    let scene_count: Int?
    let image_count: Int?
    let gallery_count: Int?
    let performer_count: Int?
    let group_count: Int?
    
    let stash_ids: [StashID]?
    let rating100: Int?
    let favorite: Bool?
    let details: String?
    let created_at: String?
    let updated_at: String?
    let o_counter: Int?
    
    struct StashID: Codable, Equatable, Hashable, Sendable {
        var id: String { stash_id }
        let stash_id: String
        let endpoint: String
    }
    
    // Simplified studio for recursive references to avoid infinite recursion
    struct SimpleStudio: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let image_path: String?
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        name: String,
        urls: [String]? = nil,
        parent_studio: SimpleStudio? = nil,
        child_studios: [SimpleStudio]? = nil,
        aliases: [String]? = nil,
        tags: [Tag]? = nil,
        ignore_auto_tag: Bool? = nil,
        image_path: String? = nil,
        scene_count: Int? = nil,
        image_count: Int? = nil,
        gallery_count: Int? = nil,
        performer_count: Int? = nil,
        group_count: Int? = nil,
        stash_ids: [StashID]? = nil,
        rating100: Int? = nil,
        favorite: Bool? = nil,
        details: String? = nil,
        created_at: String? = nil,
        updated_at: String? = nil,
        o_counter: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.urls = urls
        self.parent_studio = parent_studio
        self.child_studios = child_studios
        self.aliases = aliases
        self.tags = tags
        self.ignore_auto_tag = ignore_auto_tag
        self.image_path = image_path
        self.scene_count = scene_count
        self.image_count = image_count
        self.gallery_count = gallery_count
        self.performer_count = performer_count
        self.group_count = group_count
        self.stash_ids = stash_ids
        self.rating100 = rating100
        self.favorite = favorite
        self.details = details
        self.created_at = created_at
        self.updated_at = updated_at
        self.o_counter = o_counter
    }
    
    // MARK: - GRDB
    
    static let databaseTableName = "studios"
    
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let scene_count = Column("scene_count")
        static let favorite = Column("favorite")
        static let rating100 = Column("rating100")
        static let created_at = Column("created_at")
        static let updated_at = Column("updated_at")
    }
    
    // Custom encoding to database
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["name"] = name
        container["image_path"] = image_path
        container["urlsJSON"] = try urls.flatMap { try String(data: JSONEncoder().encode($0), encoding: .utf8) }
        container["parentStudioJSON"] = try parent_studio.flatMap { try String(data: JSONEncoder().encode($0), encoding: .utf8) }
        container["aliasesJSON"] = try aliases.flatMap { try String(data: JSONEncoder().encode($0), encoding: .utf8) }
        container["tagsJSON"] = try tags.flatMap { try String(data: JSONEncoder().encode($0), encoding: .utf8) }
        container["ignore_auto_tag"] = ignore_auto_tag
        container["scene_count"] = scene_count
        container["image_count"] = image_count
        container["gallery_count"] = gallery_count
        container["performer_count"] = performer_count
        container["group_count"] = group_count
        container["stashIdsJSON"] = try stash_ids.flatMap { try String(data: JSONEncoder().encode($0), encoding: .utf8) }
        container["rating100"] = rating100
        container["favorite"] = favorite
        container["details"] = details
        container["created_at"] = created_at
        container["updated_at"] = updated_at
        container["o_counter"] = o_counter
    }
    
    // Custom decoding from database
    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        image_path = row["image_path"]
        
        // Decode simple types directly
        ignore_auto_tag = row["ignore_auto_tag"]
        scene_count = row["scene_count"]
        image_count = row["image_count"]
        gallery_count = row["gallery_count"]
        performer_count = row["performer_count"]
        group_count = row["group_count"]
        rating100 = row["rating100"]
        favorite = row["favorite"]
        details = row["details"]
        created_at = row["created_at"]
        updated_at = row["updated_at"]
        o_counter = row["o_counter"]
        
        let decoder = JSONDecoder()
        
        if let urlsJSON: String = row["urlsJSON"] {
            urls = try? decoder.decode([String].self, from: Data(urlsJSON.utf8))
        } else { urls = nil }
        
        if let parentStudioJSON: String = row["parentStudioJSON"] {
            parent_studio = try? decoder.decode(SimpleStudio.self, from: Data(parentStudioJSON.utf8))
        } else { parent_studio = nil }
        
        // Note: child_studios might not be persisted in the main table or might need a separate join, 
        // but for now we'll assume it's valid to be nil or loaded separately if not in JSON column.
        // Assuming strictly for simple storage:
        child_studios = nil // Usually not stored in the flat record, requires relationship query
        
        if let aliasesJSON: String = row["aliasesJSON"] {
            aliases = try? decoder.decode([String].self, from: Data(aliasesJSON.utf8))
        } else { aliases = nil }
        
        if let tagsJSON: String = row["tagsJSON"] {
            tags = try? decoder.decode([Tag].self, from: Data(tagsJSON.utf8))
        } else { tags = nil }
        
        if let stashIdsJSON: String = row["stashIdsJSON"] {
            stash_ids = try? decoder.decode([StashID].self, from: Data(stashIdsJSON.utf8))
        } else { stash_ids = nil }
    }
}
