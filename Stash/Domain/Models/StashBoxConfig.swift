import Foundation
import Combine

struct ConfigurationResponse: Decodable {
    let configuration: ConfigurationData
}

struct ConfigurationData: Decodable {
    let general: GeneralConfig
}

struct GeneralConfig: Decodable {
    let stashBoxes: [StashBox]
}

struct StashBox: Decodable, Identifiable, Hashable {
    var id: String { endpoint } // Endpoint is unique enough for ID
    let name: String
    let endpoint: String
    let api_key: String?
}

// Input model for ScrapeSingleScene
struct ScrapeSingleSceneInput: Encodable {
    var query: String? // For text search if needed
    // Add other fields as discovered, but for now we rely on fragment data passed in other ways or query string
    // The user mentioned fragment data (video hash/fingerprint). 
    // Usually Stash's internal "identify" uses hashes. 
    // "ScrapeSingleScene" might accept a specific scene ID or hash. 
    // Let's assume for this feature we are scraping *based on the current scene's* data.
    // The user said: "The ScrapeSingleSceneInput is what contains the fragment data"
    
    // We'll define this loosely to match typical Stash input structure if needed, 
    // or just pass dictionary to variables.
}

struct ScrapedSceneResult: Decodable {
    let scrapeSingleScene: [ScrapedScene]?
}

struct ScrapedScene: Decodable, Identifiable, Equatable {
    var id: String { title ?? UUID().uuidString } // Temporary ID
    let title: String?
    let details: String?
    let date: String?
    let studio: ScrapedStudio?
    let performers: [ScrapedPerformer]?
    let tags: [ScrapedTag]?
    let image: String? // Base64 or URL
    let remote_site_id: String?
    let director: String?
    let code: String?
    let url: String?
    let urls: [String]?
}

struct ScrapedStudio: Decodable, Equatable {
    let name: String
}

struct ScrapedPerformer: Decodable, Equatable {
    let name: String
    let gender: String?
    let images: [String]?
    let stored_id: String?  // Server-provided ID if performer already exists locally
}

struct ScrapedTag: Decodable, Equatable {
    let name: String
}

// MARK: - Scene Fragment Input
struct SceneFragmentInput: Encodable {
    var title: String?
    var code: String?
    var details: String?
    var director: String?
    var urls: [String]?
    var date: String?
    var remote_site_id: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let title = title { dict["title"] = title }
        if let code = code { dict["code"] = code }
        if let details = details { dict["details"] = details }
        if let director = director { dict["director"] = director }
        if let date = date { dict["date"] = date }
        if let remote_site_id = remote_site_id { dict["remote_site_id"] = remote_site_id }
        if let urls = urls { dict["urls"] = urls }
        return dict
    }
}
