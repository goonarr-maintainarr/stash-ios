import Foundation
import SwiftUI

/// A unified model for displaying performer details, abstraction over local `Performer` and remote `StashDBPerformer`
struct PerformerDetailDisplay: Identifiable {
    let id: String
    let name: String
    let disambiguation: String?
    let gender: String?
    let birthdate: String?
    let deathDate: String?
    let ethnicity: String?
    let country: String?
    let heightCm: Int?
    let weightKg: Int?
    let eyeColor: String?
    let hairColor: String?
    let fakeTits: String? // "Fake", "Natural", or generic string
    let careerLength: String?
    let tattoos: String?
    let piercings: String?
    let measurements: String?
    let urls: [String]
    let aliases: [String]
    let tags: [String]
    let stashIDs: [Performer.StashID]
    
    // Stats
    let sceneCount: Int
    let age: Int?
    let oCount: Int?
    let rating100: Int?
    
    // Image
    let imageURL: URL?
    
    // Source Identification
    let isLocal: Bool
    
    // MARK: - Local Initializer
    init(performer: Performer, imageURL: URL?) {
        self.id = performer.id
        self.name = performer.name ?? "Unknown"
        self.disambiguation = performer.disambiguation
        self.gender = performer.gender
        self.birthdate = performer.birthdate
        self.deathDate = performer.death_date
        self.ethnicity = performer.ethnicity
        self.country = performer.country
        self.heightCm = performer.height_cm
        self.weightKg = performer.weight
        self.eyeColor = performer.eye_color
        self.hairColor = performer.hair_color
        self.fakeTits = performer.fake_tits
        self.careerLength = performer.career_length
        self.tattoos = performer.tattoos
        self.piercings = performer.piercings
        self.measurements = performer.measurements
        self.urls = performer.urls ?? []
        self.aliases = performer.alias_list ?? []
        self.tags = performer.tags?.map { $0.name } ?? []
        self.stashIDs = performer.stash_ids ?? []
        
        self.sceneCount = performer.scene_count ?? 0
        self.age = performer.age
        self.oCount = performer.o_counter
        self.rating100 = performer.rating100
        
        self.imageURL = imageURL
        self.isLocal = true
    }
    
    // MARK: - StashDB Initializer
    init(stashPerformer: StashDBPerformer) {
        self.id = stashPerformer.id
        self.name = stashPerformer.name
        self.disambiguation = stashPerformer.disambiguation
        self.gender = stashPerformer.gender
        self.birthdate = stashPerformer.birthDate
        self.deathDate = nil // StashDBPerformer doesn't have death date in our model
        self.ethnicity = stashPerformer.ethnicity
        self.country = stashPerformer.country
        self.heightCm = stashPerformer.height
        self.weightKg = nil // StashDBPerformer does not have weight
        self.eyeColor = stashPerformer.eyeColor
        self.hairColor = stashPerformer.hairColor
        self.fakeTits = stashPerformer.breastType // Matches "Fake"/"Natural" usually
        
        // Calculate career length from start/end years
        if let start = stashPerformer.careerStartYear {
            if let end = stashPerformer.careerEndYear {
                self.careerLength = "\(start)-\(end)"
            } else {
                self.careerLength = "\(start)-"
            }
        } else {
            self.careerLength = nil
        }
        
        // Flatten simple arrays to comma-separated strings for consistency with local format
        self.tattoos = stashPerformer.tattoos?.compactMap { $0.description ?? $0.location }.joined(separator: ", ")
        self.piercings = stashPerformer.piercings?.compactMap { $0.description ?? $0.location }.joined(separator: ", ")
        
        // Format measurements
        if let m = stashPerformer.measurements {
            var parts: [String] = []
            if let band = m.band_size, band > 0 { parts.append("\(band)") }
            if let cup = m.cup_size, !cup.isEmpty { parts.append(cup) }
            if let waist = m.waist, waist > 0 { parts.append("\(waist)") }
            if let hip = m.hip, hip > 0 { parts.append("\(hip)") }
            self.measurements = parts.isEmpty ? nil : parts.joined(separator: "-")
        } else {
            self.measurements = nil
        }
        
        self.urls = stashPerformer.urls?.compactMap { $0.url } ?? []
        self.aliases = [] // StashDBPerformer model in this file does not have aliases list in the main struct, unlike Studio.
        self.tags = [] // StashDBPerformer does not have tags
        self.stashIDs = [] // StashDBPerformer does not expose stash_ids array here
        
        self.sceneCount = stashPerformer.sceneCount
        self.age = stashPerformer.age
        self.oCount = nil // Not in StashDB
        self.rating100 = nil // Not in StashDB
        
        if let urlStr = stashPerformer.images?.first?.url {
            self.imageURL = URL(string: urlStr)
        } else {
            self.imageURL = nil
        }
        
        self.isLocal = false
    }
}
