import Foundation
import GRDB

/// Domain model for Performer. API decoding uses PerformerDTO, but Codable is needed for Scene serialization.
struct Performer: Identifiable, Codable, Equatable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    let id: String
    let name: String?
    let disambiguation: String?
    let urls: [String]?
    let gender: String?
    let birthdate: String?
    let death_date: String?
    let ethnicity: String?
    let country: String?
    let eye_color: String?
    let hair_color: String?
    let height_cm: Int?
    let weight: Int?
    let measurements: String?
    let fake_tits: String?
    let penis_length: Double?
    let circumcised: String?
    let career_length: String?
    let tattoos: String?
    let piercings: String?
    let alias_list: [String]?
    let favorite: Bool?
    let image_path: String?
    let details: String?
    let scene_count: Int?
    let image_count: Int?
    let gallery_count: Int?
    let group_count: Int?
    let o_counter: Int?
    let rating100: Int?
    let created_at: String?
    let updated_at: String?
    let stash_ids: [StashID]?
    let tags: [PerformerTag]?
    
    struct StashID: Codable, Equatable, Identifiable, Hashable, Sendable {
        var id: String { stash_id }
        let stash_id: String
        let endpoint: String
    }
    
    struct PerformerTag: Codable, Equatable, Identifiable, Hashable, Sendable {
        let id: String
        let name: String
    }
    

    
    init(
        id: String,
        name: String? = nil,
        disambiguation: String? = nil,
        urls: [String]? = nil,
        gender: String? = nil,
        birthdate: String? = nil,
        death_date: String? = nil,
        ethnicity: String? = nil,
        country: String? = nil,
        eye_color: String? = nil,
        hair_color: String? = nil,
        height_cm: Int? = nil,
        weight: Int? = nil,
        measurements: String? = nil,
        fake_tits: String? = nil,
        penis_length: Double? = nil,
        circumcised: String? = nil,
        career_length: String? = nil,
        tattoos: String? = nil,
        piercings: String? = nil,
        alias_list: [String]? = nil,
        favorite: Bool? = nil,
        image_path: String? = nil,
        details: String? = nil,
        scene_count: Int? = nil,
        image_count: Int? = nil,
        gallery_count: Int? = nil,
        group_count: Int? = nil,
        o_counter: Int? = nil,
        rating100: Int? = nil,
        created_at: String? = nil,
        updated_at: String? = nil,
        stash_ids: [StashID]? = nil,
        tags: [PerformerTag]? = nil
    ) {
        self.id = id
        self.name = name
        self.disambiguation = disambiguation
        self.urls = urls
        self.gender = gender
        self.birthdate = birthdate
        self.death_date = death_date
        self.ethnicity = ethnicity
        self.country = country
        self.eye_color = eye_color
        self.hair_color = hair_color
        self.height_cm = height_cm
        self.weight = weight
        self.measurements = measurements
        self.fake_tits = fake_tits
        self.penis_length = penis_length
        self.circumcised = circumcised
        self.career_length = career_length
        self.tattoos = tattoos
        self.piercings = piercings
        self.alias_list = alias_list
        self.favorite = favorite
        self.image_path = image_path
        self.details = details
        self.scene_count = scene_count
        self.image_count = image_count
        self.gallery_count = gallery_count
        self.group_count = group_count
        self.o_counter = o_counter
        self.rating100 = rating100
        self.created_at = created_at
        self.updated_at = updated_at
        self.stash_ids = stash_ids
        self.tags = tags
    }
    
    // MARK: - GRDB
    
    static let databaseTableName = "performers"
    
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let scene_count = Column("scene_count")
    }
    
    // Custom encoding to database
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["name"] = name
        container["disambiguation"] = disambiguation
        container["gender"] = gender
        container["birthdate"] = birthdate
        container["death_date"] = death_date
        container["ethnicity"] = ethnicity
        container["country"] = country
        container["eye_color"] = eye_color
        container["hair_color"] = hair_color
        container["height_cm"] = height_cm
        container["weight"] = weight
        container["measurements"] = measurements
        container["fake_tits"] = fake_tits
        container["penis_length"] = penis_length
        container["circumcised"] = circumcised
        container["career_length"] = career_length
        container["tattoos"] = tattoos
        container["piercings"] = piercings
        container["favorite"] = favorite
        container["image_path"] = image_path
        container["details"] = details
        container["scene_count"] = scene_count
        container["image_count"] = image_count
        container["gallery_count"] = gallery_count
        container["group_count"] = group_count
        container["o_counter"] = o_counter
        container["rating100"] = rating100
        container["created_at"] = created_at
        container["updated_at"] = updated_at
        
        let encoder = JSONEncoder()
        if let stashIds = stash_ids {
            container["stash_idsJSON"] = try String(data: encoder.encode(stashIds), encoding: .utf8)
        }
        
        if let aliases = alias_list {
            container["alias_listJSON"] = try String(data: encoder.encode(aliases), encoding: .utf8)
        }
        
        if let tags = tags {
            container["tagsJSON"] = try String(data: encoder.encode(tags), encoding: .utf8)
        }
        
        if let urls = urls {
            container["urlsJSON"] = try String(data: encoder.encode(urls), encoding: .utf8)
        }
    }
    
    // Custom decoding from database
    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        disambiguation = row["disambiguation"]
        gender = row["gender"]
        birthdate = row["birthdate"]
        death_date = row["death_date"]
        ethnicity = row["ethnicity"]
        country = row["country"]
        eye_color = row["eye_color"]
        hair_color = row["hair_color"]
        height_cm = row["height_cm"]
        weight = row["weight"]
        measurements = row["measurements"]
        fake_tits = row["fake_tits"]
        penis_length = row["penis_length"]
        circumcised = row["circumcised"]
        career_length = row["career_length"]
        tattoos = row["tattoos"]
        piercings = row["piercings"]
        favorite = row["favorite"]
        image_path = row["image_path"]
        details = row["details"]
        scene_count = row["scene_count"]
        image_count = row["image_count"]
        gallery_count = row["gallery_count"]
        group_count = row["group_count"]
        o_counter = row["o_counter"]
        rating100 = row["rating100"]
        created_at = row["created_at"]
        updated_at = row["updated_at"]
        
        let decoder = JSONDecoder()
        if let stashIdsJSON: String = row["stash_idsJSON"] {
            stash_ids = try? decoder.decode([StashID].self, from: Data(stashIdsJSON.utf8))
        } else {
            stash_ids = nil
        }
        
        if let aliasJSON: String = row["alias_listJSON"] {
            alias_list = try decoder.decode([String].self, from: Data(aliasJSON.utf8))
        } else {
            alias_list = nil
        }
        
        if let tagsJSON: String = row["tagsJSON"] {
            tags = try? decoder.decode([PerformerTag].self, from: Data(tagsJSON.utf8))
        } else {
            tags = nil
        }
        
        if let urlsJSON: String = row["urlsJSON"] {
            urls = try? decoder.decode([String].self, from: Data(urlsJSON.utf8))
        } else {
            urls = nil
        }
    }
    
    var age: Int? {
        guard let birthdate = birthdate else { return nil }
        return DateFormatters.calculateAge(from: birthdate, deathDate: death_date)
    }
}
