import Foundation

// MARK: - Parse Mode

enum ParseMode: String, Codable, CaseIterable, Sendable {
    case auto = "auto"
    case filename = "filename"
    case directory = "dir"
    case path = "path"
    case metadata = "metadata"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .filename: return "Filename"
        case .directory: return "Directory"
        case .path: return "Path"
        case .metadata: return "Metadata"
        }
    }
}

// MARK: - Tag Operation

enum TagOperation: String, Codable, CaseIterable, Sendable {
    case merge = "merge"
    case overwrite = "overwrite"
    
    var displayName: String {
        switch self {
        case .merge: return "Merge"
        case .overwrite: return "Overwrite"
        }
    }
}

// MARK: - Gender Enum

enum GenderEnum: String, Codable, CaseIterable, Sendable {
    case male = "MALE"
    case female = "FEMALE"
    case transgenderMale = "TRANSGENDER_MALE"
    case transgenderFemale = "TRANSGENDER_FEMALE"
    case intersex = "INTERSEX"
    case nonBinary = "NON_BINARY"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .transgenderMale: return "Transgender Male"
        case .transgenderFemale: return "Transgender Female"
        case .intersex: return "Intersex"
        case .nonBinary: return "Non-Binary"
        }
    }
    
    init?(from string: String) {
        let normalized = string.uppercased().replacingOccurrences(of: " ", with: "_")
        if let exact = GenderEnum(rawValue: normalized) {
            self = exact
            return
        }
        
        switch normalized {
        case "MALE": self = .male
        case "FEMALE": self = .female
        case "TRANSGENDER_MALE", "TRANS_MALE": self = .transgenderMale
        case "TRANSGENDER_FEMALE", "TRANS_FEMALE": self = .transgenderFemale
        case "INTERSEX": self = .intersex
        case "NON_BINARY", "NONBINARY": self = .nonBinary
        default: return nil
        }
    }
}

// MARK: - Tagger Config

struct TaggerConfig: Codable, Sendable, Equatable {
    var mode: ParseMode
    var blacklist: [String]
    var performerGenders: [GenderEnum]?
    var setCoverImage: Bool
    var setTags: Bool
    var tagOperation: TagOperation
    var selectedEndpoint: String?
    var fingerprintQueue: [String: [String]]?
    var excludedPerformerFields: [String]
    var markSceneAsOrganizedOnSave: Bool
    var excludedStudioFields: [String]
    var createParentStudios: Bool
    
    // Default configuration
    static var `default`: TaggerConfig {
        TaggerConfig(
            mode: .auto,
            blacklist: [],
            performerGenders: nil,
            setCoverImage: true,
            setTags: true,
            tagOperation: .merge,
            selectedEndpoint: nil,
            fingerprintQueue: [:],
            excludedPerformerFields: defaultExcludedPerformerFields,
            markSceneAsOrganizedOnSave: false,
            excludedStudioFields: defaultExcludedStudioFields,
            createParentStudios: true
        )
    }
    
    // Default excluded fields
    static let defaultExcludedPerformerFields = [
        "image", "urls", "details", "death_date",
        "hair_color", "weight", "penis_length", "circumcised"
    ]
    
    static let defaultExcludedStudioFields = ["image"]
    
    // All available fields for selection in UI
    static let allPerformerFields = [
        "name", "image", "disambiguation", "aliases",
        "gender", "birthdate", "death_date", "country",
        "ethnicity", "hair_color", "eye_color", "height",
        "weight", "penis_length", "circumcised", "measurements",
        "fake_tits", "tattoos", "piercings", "career_length",
        "urls", "details"
    ]
    
    static let allStudioFields = ["name", "image", "url", "parent_studio"]
}
