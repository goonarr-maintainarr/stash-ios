import Foundation

// MARK: - Core Models

struct StashDBPerformer: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let disambiguation: String?
    let gender: String?
    let birthDate: String?
    let ethnicity: String?
    let country: String?
    let height: Int?
    let hairColor: String?
    let eyeColor: String?
    let measurements: StashDBMeasurements?
    let breastType: String?
    let careerStartYear: Int?
    let careerEndYear: Int?
    let tattoos: [StashDBBodyMod]?
    let piercings: [StashDBBodyMod]?
    let sceneCount: Int
    let isFavorite: Bool
    let images: [StashDBImage]?
    let urls: [StashDBURL]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, disambiguation, gender, ethnicity, country, height, images, measurements, tattoos, piercings, urls
        case birthDate = "birth_date"
        case hairColor = "hair_color"
        case eyeColor = "eye_color"
        case breastType = "breast_type"
        case careerStartYear = "career_start_year"
        case careerEndYear = "career_end_year"
        case sceneCount = "scene_count"
        case isFavorite = "is_favorite"
    }

    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        return DateFormatters.calculateAge(from: birthDate)
    }
}






struct StashDBMeasurements: Codable, Equatable, Hashable {
    let cup_size: String?
    let band_size: Int?
    let waist: Int?
    let hip: Int?
}

struct StashDBBodyMod: Codable, Equatable, Hashable {
    let location: String?
    let description: String?
}

struct StashDBScene: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String?
    let details: String?
    let date: String?
    let releaseDate: String?
    let productionDate: String?
    let duration: Int?
    let director: String?
    let code: String?
    let deleted: Bool?
    let created: String?
    let updated: String?
    let studio: StashDBStudio?
    let performers: [StashDBPerformerAppearance]?
    let tags: [StashDBTag]?
    let images: [StashDBImage]?
    let urls: [StashDBURL]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, details, date, duration, director, code, deleted, created, updated, studio, performers, tags, images, urls
        case releaseDate = "release_date"
        case productionDate = "production_date"
    }
}



// MARK: - Supporting Models

struct StashDBStudio: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let aliases: [String]?
    let deleted: Bool?
    let isFavorite: Bool?
    let created: String?
    let updated: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, aliases, deleted, created, updated
        case isFavorite = "is_favorite"
    }
}

struct StashDBPerformerAppearance: Codable, Equatable, Hashable {
    let performer: StashDBPerformerBasic
}

struct StashDBPerformerBasic: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let gender: String?
}

struct StashDBTag: Codable, Equatable, Hashable {
    let id: String
    let name: String
}

struct StashDBImage: Codable, Equatable, Hashable {
    let id: String
    let url: String
    let width: Int
    let height: Int
}

struct StashDBURL: Codable, Equatable, Hashable {
    let url: String
    let type: String
}

// MARK: - GraphQL Response Wrappers

struct StashDBPerformersResult: Codable {
    let queryPerformers: StashDBPerformersData
}

struct StashDBPerformersData: Codable {
    let count: Int
    let performers: [StashDBPerformer]
}

struct StashDBPerformerScenesResult: Codable {
    let findPerformer: StashDBPerformerWithScenes
}

struct StashDBPerformerWithScenes: Codable {
    let id: String
    let name: String
    let scenes: [StashDBScene]
}

struct StashDBScenesData: Codable {
    let count: Int
    let scenes: [StashDBScene]
}

struct StashDBScenesQueryResult: Codable {
    let queryScenes: StashDBScenesData
}

struct StashDBStudiosResult: Codable {
    let queryStudios: StashDBStudiosData
}

struct StashDBStudiosData: Codable {
    let count: Int
    let studios: [StashDBStudio]
}

struct StashDBPerformerDetailResult: Codable {
    let findPerformer: StashDBPerformer
}

extension StashDBPerformer {
    /// Stub initializer for navigation
    init(stubId: String, stubName: String) {
        self.id = stubId
        self.name = stubName
        self.disambiguation = nil
        self.gender = nil
        self.birthDate = nil
        self.ethnicity = nil
        self.country = nil
        self.height = nil
        self.hairColor = nil
        self.eyeColor = nil
        self.measurements = nil
        self.breastType = nil
        self.careerStartYear = nil
        self.careerEndYear = nil
        self.tattoos = nil
        self.piercings = nil
        self.sceneCount = 0
        self.isFavorite = false
        self.images = nil
        self.urls = nil
    }
}

