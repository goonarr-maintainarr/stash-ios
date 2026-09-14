import Foundation

// MARK: - Performer DTO (API Response)

/// Data Transfer Object for Performer GraphQL API responses.
/// This struct matches the exact shape of the Stash GraphQL API response.
/// Use `toDomain()` to convert to the domain `Performer` model.
struct PerformerDTO: Decodable {
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
    let stash_ids: [StashIDDTO]?
    let tags: [TagDTO]?
    
    init(
        id: String, name: String?, disambiguation: String? = nil, urls: [String]? = nil,
        gender: String? = nil, birthdate: String? = nil, death_date: String? = nil,
        ethnicity: String? = nil, country: String? = nil, eye_color: String? = nil,
        hair_color: String? = nil, height_cm: Int? = nil, weight: Int? = nil,
        measurements: String? = nil, fake_tits: String? = nil, penis_length: Double? = nil,
        circumcised: String? = nil, career_length: String? = nil, tattoos: String? = nil,
        piercings: String? = nil, alias_list: [String]? = nil, favorite: Bool? = nil,
        image_path: String? = nil, details: String? = nil, scene_count: Int? = nil,
        image_count: Int? = nil, gallery_count: Int? = nil, group_count: Int? = nil,
        o_counter: Int? = nil, rating100: Int? = nil, created_at: String? = nil,
        updated_at: String? = nil, stash_ids: [StashIDDTO]? = nil, tags: [TagDTO]? = nil
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
    
    struct StashIDDTO: Decodable {
        let stash_id: String
        let endpoint: String
    }
    
    struct TagDTO: Decodable {
        let id: String
        let name: String
    }
    
    /// Convert API DTO to domain model
    func toDomain() -> Performer {
        Performer(
            id: id,
            name: name,
            disambiguation: disambiguation,
            urls: urls,
            gender: gender,
            birthdate: birthdate,
            death_date: death_date,
            ethnicity: ethnicity,
            country: country,
            eye_color: eye_color,
            hair_color: hair_color,
            height_cm: height_cm,
            weight: weight,
            measurements: measurements,
            fake_tits: fake_tits,
            penis_length: penis_length,
            circumcised: circumcised,
            career_length: career_length,
            tattoos: tattoos,
            piercings: piercings,
            alias_list: alias_list,
            favorite: favorite,
            image_path: image_path,
            details: details,
            scene_count: scene_count,
            image_count: image_count,
            gallery_count: gallery_count,
            group_count: group_count,
            o_counter: o_counter,
            rating100: rating100,
            created_at: created_at,
            updated_at: updated_at,
            stash_ids: stash_ids?.map { Performer.StashID(stash_id: $0.stash_id, endpoint: $0.endpoint) },
            tags: tags?.map { Performer.PerformerTag(id: $0.id, name: $0.name) }
        )
    }
}

// MARK: - API Response Wrappers

struct PerformerResultDTO: Decodable {
    let findPerformers: PerformerConnectionDTO
}

struct PerformerConnectionDTO: Decodable {
    let performers: [PerformerDTO]
    let count: Int
    
    func toDomain() -> (performers: [Performer], count: Int) {
        return (performers.map { $0.toDomain() }, count)
    }
}

struct SinglePerformerResultDTO: Decodable {
    let findPerformer: PerformerDTO?
    
    func toDomain() -> Performer? {
        return findPerformer?.toDomain()
    }
}

struct PerformerUpdateResultDTO: Decodable {
    let performerUpdate: PerformerDTO?
    
    func toDomain() -> Performer? {
        return performerUpdate?.toDomain()
    }
}
