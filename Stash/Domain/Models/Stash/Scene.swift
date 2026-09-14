import Foundation
@preconcurrency import GRDB

struct Scene: Identifiable, Codable, Equatable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    let id: String
    let title: String?
    let details: String?
    let date: String?
    let created_at: String?
    let updated_at: String?
    var rating100: Int?
    var o_counter: Int?
    var resume_time: Double?
    let paths: ScenePaths?
    let files: [SceneFile]?
    let performers: [Performer]?
    let tags: [Tag]?
    var studio: Studio?
    let stash_ids: [StashID]?
    let scene_markers: [SceneMarker]?
    let o_history: [String]?
    let play_history: [String]?
    let director: String?
    let code: String?
    let url: String?
    let urls: [String]?
    
    struct StashID: Codable, Equatable, Hashable, Sendable {
        let stash_id: String
        let endpoint: String
    }
    
    // Explicit memberwise initializer for Codable and preview support
    init(
        id: String,
        title: String? = nil,
        details: String? = nil,
        date: String? = nil,
        created_at: String? = nil,
        updated_at: String? = nil,
        rating100: Int? = nil,
        o_counter: Int? = nil,
        resume_time: Double? = nil,
        paths: ScenePaths? = nil,
        files: [SceneFile]? = nil,
        performers: [Performer]? = nil,
        tags: [Tag]? = nil,
        studio: Studio? = nil,
        stash_ids: [StashID]? = nil,
        scene_markers: [SceneMarker]? = nil,
        o_history: [String]? = nil,
        play_history: [String]? = nil,
        director: String? = nil,
        code: String? = nil,
        url: String? = nil,
        urls: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.date = date
        self.created_at = created_at
        self.updated_at = updated_at
        self.rating100 = rating100
        self.o_counter = o_counter
        self.resume_time = resume_time
        self.paths = paths
        self.files = files
        self.performers = performers
        self.tags = tags
        self.studio = studio
        self.stash_ids = stash_ids
        self.scene_markers = scene_markers
        self.o_history = o_history
        self.play_history = play_history
        self.director = director
        self.code = code
        self.url = url
        self.urls = urls
    }
    
    
    
    
    struct ScenePaths: Codable, Equatable, Hashable, Sendable {
        let screenshot: String?
        let preview: String?
        let stream: String?
        let sprite: String?
        let vtt: String?
    }
    
    struct SceneFile: Codable, Equatable, Hashable, Sendable {
        let path: String?
        let size: Int64?
        let duration: Double?
        let video_codec: String?
        let audio_codec: String?
        let width: Int?
        let height: Int?
    }
    
    // MARK: - GRDB
    
    static let databaseTableName = "scenes"
    
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let details = Column("details")
        static let date = Column("date")
        static let created_at = Column("created_at")
        static let updated_at = Column("updated_at")
        static let rating100 = Column("rating100")
        static let o_counter = Column("o_counter")
        static let resume_time = Column("resume_time")
        static let pathsJSON = Column("pathsJSON")
        static let filesJSON = Column("filesJSON")
        static let performersJSON = Column("performersJSON")
        static let tagsJSON = Column("tagsJSON")
        static let studioJSON = Column("studioJSON")
        static let sceneMarkersJSON = Column("sceneMarkersJSON")
        static let oHistoryJSON = Column("oHistoryJSON")
        static let playHistoryJSON = Column("playHistoryJSON")
        static let director = Column("director")
        static let code = Column("code")
        static let url = Column("url")
        static let urlsJSON = Column("urlsJSON")
    }
    
    // Custom encoding to database
    // Removed @MainActor as Studio is now Sendable and non-isolated
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["title"] = title
        container["details"] = details
        container["date"] = date
        container["created_at"] = created_at
        container["updated_at"] = updated_at
        container["rating100"] = rating100
        container["o_counter"] = o_counter
        container["resume_time"] = resume_time
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Fix: Encode arrays/objects to single JSON strings
        container["pathsJSON"] = try paths.flatMap { try String(data: encoder.encode($0), encoding: .utf8) }
        
        if let files = files {
            container["filesJSON"] = try String(data: encoder.encode(files), encoding: .utf8)
        }
        
        if let performers = performers {
            container["performersJSON"] = try String(data: encoder.encode(performers), encoding: .utf8)
        }
        
        if let tags = tags {
            container["tagsJSON"] = try String(data: encoder.encode(tags), encoding: .utf8)
        }
        
        // Studio is single object, flatMap handles it correctly (Optional map returns Optional String)
        container["studioJSON"] = try studio.flatMap { try String(data: encoder.encode($0), encoding: .utf8) }
        
        if let stashIds = stash_ids {
            container["stash_idsJSON"] = try String(data: encoder.encode(stashIds), encoding: .utf8)
        }
        
        if let markers = scene_markers {
            container["sceneMarkersJSON"] = try String(data: encoder.encode(markers), encoding: .utf8)
        }
        
        if let history = o_history {
            container["oHistoryJSON"] = try String(data: encoder.encode(history), encoding: .utf8)
        }
        
        if let history = play_history {
            container["playHistoryJSON"] = try String(data: encoder.encode(history), encoding: .utf8)
        }
        
        container["director"] = director
        container["code"] = code
        container["url"] = url
        
        if let urls = urls {
             container["urlsJSON"] = try String(data: encoder.encode(urls), encoding: .utf8)
        }
    }
    
    // Custom decoding from database
    init(row: Row) throws {
        id = row["id"]
        title = row["title"]
        details = row["details"]
        date = row["date"]
        created_at = row["created_at"]
        updated_at = row["updated_at"]
        rating100 = row["rating100"]
        o_counter = row["o_counter"]
        resume_time = row["resume_time"]
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let pathsJSON: String = row["pathsJSON"] {
            paths = try? decoder.decode(ScenePaths.self, from: Data(pathsJSON.utf8))
        } else {
            paths = nil
        }
        
        if let filesJSON: String = row["filesJSON"] {
            files = try? decoder.decode([SceneFile].self, from: Data(filesJSON.utf8))
        } else {
            files = nil
        }
        
        if let performersJSON: String = row["performersJSON"] {
            performers = try? decoder.decode([Performer].self, from: Data(performersJSON.utf8))
        } else {
            performers = nil
        }
        
        if let tagsJSON: String = row["tagsJSON"] {
            tags = try? decoder.decode([Tag].self, from: Data(tagsJSON.utf8))
        } else {
            tags = nil
        }
        
        if let studioJSON: String = row["studioJSON"] {
            studio = try? decoder.decode(Studio.self, from: Data(studioJSON.utf8))
        } else {
            studio = nil
        }
        
        if let stashIdsJSON: String = row["stash_idsJSON"] {
            stash_ids = try? decoder.decode([StashID].self, from: Data(stashIdsJSON.utf8))
        } else {
            stash_ids = nil
        }
        
        if let sceneMarkersJSON: String = row["sceneMarkersJSON"] {
            scene_markers = try? decoder.decode([SceneMarker].self, from: Data(sceneMarkersJSON.utf8))
        } else {
            scene_markers = nil
        }
        
        if let oHistoryJSON: String = row["oHistoryJSON"] {
            o_history = try? decoder.decode([String].self, from: Data(oHistoryJSON.utf8))
        } else {
            o_history = nil
        }
        
        if let playHistoryJSON: String = row["playHistoryJSON"] {
            play_history = try? decoder.decode([String].self, from: Data(playHistoryJSON.utf8))
        } else {
            play_history = nil
        }
        
        director = row["director"]
        code = row["code"]
        url = row["url"]
        
        if let urlsJSON: String = row["urlsJSON"] {
             urls = try? decoder.decode([String].self, from: Data(urlsJSON.utf8))
        } else {
             urls = nil
        }
    }
}

extension Scene {
    /// Returns a copy of the scene with the specified resume time.
    func withResumeTime(_ time: Double) -> Scene {
        var copy = self
        copy.resume_time = time
        return copy
    }
}
