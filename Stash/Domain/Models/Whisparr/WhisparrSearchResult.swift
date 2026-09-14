import Foundation
import Combine

// Model for search results from /api/v3/lookup/scene?term=
struct WhisparrSearchResult: Identifiable, Codable, Equatable, Hashable {
    let foreignId: String
    let title: String
    let overview: String?
    let releaseDate: Date?
    let year: Int
    let runtime: Int
    let studioTitle: String?
    let images: [WhisparrImage]
    let credits: [WhisparrCredit]
    
    var id: String { foreignId }
    
    var imageUrl: String? {
        images.first(where: { $0.coverType == "screenshot" })?.remoteUrl
    }
    
    var performerNames: String {
        credits.compactMap { credit -> String? in
            guard let name = credit.performer.name else { return nil }
            if let gender = credit.performer.gender, gender.lowercased() == "male" { return nil }
            return name
        }.joined(separator: ", ")
    }
    
    enum CodingKeys: String, CodingKey {
        case foreignId
        case id
        case movie
    }
    
    enum MovieKeys: String, CodingKey {
        case title
        case overview
        case releaseDate
        case year
        case runtime
        case studioTitle
        case images
        case credits
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Always present at top level in both formats
        foreignId = try container.decode(String.self, forKey: .foreignId)
        
        // Check if details are nested in a "movie" object
        if container.contains(.movie) {
            let movieContainer = try container.nestedContainer(keyedBy: MovieKeys.self, forKey: .movie)
            
            title = try movieContainer.decode(String.self, forKey: .title)
            overview = try movieContainer.decodeIfPresent(String.self, forKey: .overview)
            releaseDate = try movieContainer.decodeIfPresent(Date.self, forKey: .releaseDate)
            year = try movieContainer.decode(Int.self, forKey: .year)
            runtime = try movieContainer.decode(Int.self, forKey: .runtime)
            studioTitle = try movieContainer.decodeIfPresent(String.self, forKey: .studioTitle)
            images = try movieContainer.decode([WhisparrImage].self, forKey: .images)
            credits = try movieContainer.decode([WhisparrCredit].self, forKey: .credits)
        } else {
            // Fallback: details are flat at the top level
            // Note: We need to use MovieKeys for decoding even from the top container 
            // because the CodingKeys enum only has foreignId, id, movie
            let topContainer = try decoder.container(keyedBy: MovieKeys.self)
            
            title = try topContainer.decode(String.self, forKey: .title)
            overview = try topContainer.decodeIfPresent(String.self, forKey: .overview)
            releaseDate = try topContainer.decodeIfPresent(Date.self, forKey: .releaseDate)
            year = try topContainer.decode(Int.self, forKey: .year)
            runtime = try topContainer.decode(Int.self, forKey: .runtime)
            
            // Handle studio fallback for flat structure (might still be 'studio' instead of 'studioTitle')
            if let title = try? topContainer.decodeIfPresent(String.self, forKey: .studioTitle) {
                studioTitle = title
            } else {
                // Try legacy "studio" key which isn't in MovieKeys, need a dynamic check or different enum
                // For simplicity, let's assume if it's flat, it matches the properties we just defined in MovieKeys
                // If studio is missing/null, that's fine as it's optional
                studioTitle = nil
            }
            
            images = try topContainer.decode([WhisparrImage].self, forKey: .images)
            credits = try topContainer.decode([WhisparrCredit].self, forKey: .credits)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(foreignId, forKey: .foreignId)
        // Note: For now we only implement decoding as this is primarily a read model
        // If encodng is needed, we would need to reconstruct the nested structure
    }
    

}
