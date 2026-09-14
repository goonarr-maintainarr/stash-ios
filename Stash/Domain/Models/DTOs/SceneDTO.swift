import Foundation

// MARK: - Scene DTO (API Response)

/// Data Transfer Object for Scene GraphQL API responses.
/// This struct matches the exact shape of the Stash GraphQL API response.
/// Use `toDomain()` to convert to the domain `Scene` model.
struct SceneDTO: Decodable {
    let id: String
    let title: String?
    let code: String?
    let director: String?
    let url: String?
    let urls: [String]?
    let details: String?
    let date: String?
    let created_at: String?
    let updated_at: String?
    let rating100: Int?
    let o_counter: Int?
    let play_count: Int?
    let play_duration: Double?
    let resume_time: Double?
    let organized: Bool?
    let paths: ScenePathsDTO?
    let files: [SceneFileDTO]?
    let performers: [PerformerDTO]?
    let tags: [TagDTO]?
    let studio: StudioDTO?
    let stash_ids: [StashIDDTO]?
    let scene_markers: [SceneMarkerDTO]?
    let o_history: [String]?
    let play_history: [String]?
    
    init(
        id: String, title: String? = nil, code: String? = nil, director: String? = nil, url: String? = nil, urls: [String]? = nil,
        details: String? = nil, date: String? = nil, created_at: String? = nil, updated_at: String? = nil,
        rating100: Int? = nil, o_counter: Int? = nil, play_count: Int? = nil,
        play_duration: Double? = nil, resume_time: Double? = nil, organized: Bool? = nil,
        paths: ScenePathsDTO? = nil, files: [SceneFileDTO]? = nil, performers: [PerformerDTO]? = nil,
        tags: [TagDTO]? = nil, studio: StudioDTO? = nil, stash_ids: [StashIDDTO]? = nil,
        scene_markers: [SceneMarkerDTO]? = nil, o_history: [String]? = nil, play_history: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.code = code
        self.director = director
        self.url = url
        self.urls = urls
        self.details = details
        self.date = date
        self.created_at = created_at
        self.updated_at = updated_at
        self.rating100 = rating100
        self.o_counter = o_counter
        self.play_count = play_count
        self.play_duration = play_duration
        self.resume_time = resume_time
        self.organized = organized
        self.paths = paths
        self.files = files
        self.performers = performers
        self.tags = tags
        self.studio = studio
        self.stash_ids = stash_ids
        self.scene_markers = scene_markers
        self.o_history = o_history
        self.play_history = play_history
    }
    
    struct StashIDDTO: Decodable {
        let stash_id: String
        let endpoint: String
    }
    
    struct ScenePathsDTO: Decodable {
        let screenshot: String?
        let preview: String?
        let stream: String?
        let sprite: String?
        let vtt: String?
    }
    
    struct SceneFileDTO: Decodable {
        let id: String?
        let path: String?
        let size: Int64?
        let duration: Double?
        let video_codec: String?
        let audio_codec: String?
        let width: Int?
        let height: Int?
        let frame_rate: Double?
        let bit_rate: Int?
    }
    
    struct TagDTO: Decodable {
        let id: String
        let name: String
        let scene_count: Int?
    }
    
    struct StudioDTO: Decodable {
        let id: String
        let name: String
        let image_path: String?
    }
    
    struct SceneMarkerDTO: Decodable {
        let id: String
        let title: String
        let seconds: Double
        let stream: String?
        let preview: String?
        let primary_tag: PrimaryTagDTO?
        let tags: [TagDTO]?
        
        struct PrimaryTagDTO: Decodable {
            let id: String
            let name: String
        }
    }
    
    /// Convert API DTO to domain model
    func toDomain() -> Scene {
        Scene(
            id: id,
            title: title,
            details: details,
            date: date,
            created_at: created_at,
            updated_at: updated_at,
            rating100: rating100,
            o_counter: o_counter,
            resume_time: resume_time,
            paths: paths?.toDomain(),
            files: files?.map { $0.toDomain() },
            performers: performers?.map { $0.toDomain() },
            tags: tags?.map { $0.toDomain() },
            studio: studio?.toDomain(),
            stash_ids: stash_ids?.map { Scene.StashID(stash_id: $0.stash_id, endpoint: $0.endpoint) },
            scene_markers: scene_markers?.map { $0.toDomain() },
            o_history: o_history,
            play_history: play_history,
            director: director,
            code: code,
            url: url,
            urls: urls
        )
    }
}

// MARK: - Nested DTO Extensions

extension SceneDTO.ScenePathsDTO {
    func toDomain() -> Scene.ScenePaths {
        Scene.ScenePaths(
            screenshot: screenshot,
            preview: preview,
            stream: stream,
            sprite: sprite,
            vtt: vtt
        )
    }
}

extension SceneDTO.SceneFileDTO {
    func toDomain() -> Scene.SceneFile {
        Scene.SceneFile(
            path: path,
            size: size,
            duration: duration,
            video_codec: video_codec,
            audio_codec: audio_codec,
            width: width,
            height: height
        )
    }
}

extension SceneDTO.TagDTO {
    func toDomain() -> Tag {
        Tag(id: id, name: name, scene_count: scene_count, description: nil)
    }
}

extension SceneDTO.StudioDTO {
    func toDomain() -> Studio {
        Studio(id: id, name: name, image_path: image_path)
    }
}

extension SceneDTO.SceneMarkerDTO {
    func toDomain() -> SceneMarker {
        SceneMarker(
            id: id,
            title: title,
            seconds: seconds,
            stream: stream,
            preview: preview
        )
    }
}

// MARK: - API Response Wrappers

struct SceneResultDTO: Decodable {
    let findScenes: SceneConnectionDTO
}

struct SceneConnectionDTO: Decodable {
    let scenes: [SceneDTO]
    let count: Int
    
    func toDomain() -> (scenes: [Scene], count: Int) {
        return (scenes.map { $0.toDomain() }, count)
    }
}

struct SingleSceneResultDTO: Decodable {
    let findScene: SceneDTO?
    
    func toDomain() -> Scene? {
        return findScene?.toDomain()
    }
}

struct SceneUpdateResultDTO: Decodable {
    let sceneUpdate: SceneDTO?
    
    func toDomain() -> Scene? {
        return sceneUpdate?.toDomain()
    }
}
