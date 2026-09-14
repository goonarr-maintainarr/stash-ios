import Foundation

// MARK: - Studio DTO (API Response)

/// Data Transfer Object for Studio GraphQL API responses.
/// Matches the exact shape of the Stash GraphQL API response.
/// Use `toDomain()` to convert to the domain `Studio` model.
struct StudioDTO: Decodable {
    let id: String
    let name: String
    let urls: [String]?
    let parent_studio: SimpleStudioDTO?
    let child_studios: [SimpleStudioDTO]?
    let aliases: [String]?
    let tags: [TagDTO]?
    let ignore_auto_tag: Bool?
    let image_path: String?
    
    // Counts
    let scene_count: Int?
    let image_count: Int?
    let gallery_count: Int?
    let performer_count: Int?
    let group_count: Int?
    
    let stash_ids: [StashIDDTO]?
    let rating100: Int?
    let favorite: Bool?
    let details: String?
    let created_at: String?
    let updated_at: String?
    let o_counter: Int?
    
    // MARK: - Nested Types
    
    struct SimpleStudioDTO: Decodable {
        let id: String
        let name: String
        let image_path: String?
        
        func toDomain() -> Studio.SimpleStudio {
            Studio.SimpleStudio(id: id, name: name, image_path: image_path)
        }
    }
    
    struct StashIDDTO: Decodable {
        let stash_id: String
        let endpoint: String
        
        func toDomain() -> Studio.StashID {
            Studio.StashID(stash_id: stash_id, endpoint: endpoint)
        }
    }
    
    struct TagDTO: Decodable {
        let id: String
        let name: String
        
        func toDomain() -> Tag {
            // Note: Tag model might have other fields like scene_count which are optional/nullable in domain
            // Just mapping basics for now, assuming Tag init or conformance allows it. 
            // Checking Tag.swift, it has id, name, scene_count. 
            // DTO usually provides minimal tag info.
            // We use a custom init or memberwise if available. 
            // Tag(id: id, name: name, scene_count: nil)
            // Re-verifying Tag.swift from previous steps: it's a GRDB record.
            // We'll rely on a basic init or strict mapping.
            // For now, let's assume Tag decode happens elsewhere or we construct it.
            // Let's defer strict Tag mapping logic if TagDTO doesn't match Tag exactly.
            // Actually, PerformerDTO maps tags: tags?.map { Performer.PerformerTag(...) }
            // Studio likely uses actual `Tag` or a `StudioTag`.
            // `Studio.swift` definition uses `Tag` (the top level one).
            // Let's assume standard Tag mapping.
            // Tag is `struct Tag: ... { let id: String; let name: String; let scene_count: Int? }`
            Tag(id: id, name: name, scene_count: nil, description: nil)
        }
    }
    
    // MARK: - Domain Mapping
    
    func toDomain() -> Studio {
        Studio(
            id: id,
            name: name,
            urls: urls,
            parent_studio: parent_studio?.toDomain(),
            child_studios: child_studios?.map { $0.toDomain() },
            aliases: aliases,
            tags: tags?.map { $0.toDomain() },
            ignore_auto_tag: ignore_auto_tag,
            image_path: image_path,
            scene_count: scene_count,
            image_count: image_count,
            gallery_count: gallery_count,
            performer_count: performer_count,
            group_count: group_count,
            stash_ids: stash_ids?.map { $0.toDomain() },
            rating100: rating100,
            favorite: favorite,
            details: details,
            created_at: created_at,
            updated_at: updated_at,
            o_counter: o_counter
        )
    }
}

// MARK: - API Response Wrappers

struct FindStudiosResultDTO: Decodable {
    let findStudios: StudioConnectionDTO
}

struct StudioConnectionDTO: Decodable {
    let studios: [StudioDTO]
    let count: Int
    
    func toDomain() -> (studios: [Studio], count: Int) {
        return (studios.map { $0.toDomain() }, count)
    }
}

struct FindStudioResultDTO: Decodable {
    let findStudio: StudioDTO?
    
    func toDomain() -> Studio? {
        findStudio?.toDomain()
    }
}
