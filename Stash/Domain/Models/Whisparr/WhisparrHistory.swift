import Foundation
import Combine

// MARK: - API Response Model
struct WhisparrHistoryResponse: Codable {
    let page: Int
    let pageSize: Int
    let sortKey: String
    let sortDirection: String
    let totalRecords: Int
    let records: [WhisparrHistoryRecord]
}

// MARK: - History Record
struct WhisparrHistoryRecord: Codable, Identifiable, Hashable {
    let id: Int
    let movieId: Int
    let sourceTitle: String?
    let languages: [WhisparrLanguage]
    let quality: WhisparrQuality
    let date: String // ISO8601 string
    let eventType: String
    let downloadId: String?
    let data: WhisparrHistoryData?
    let movie: WhisparrHistoryMovie?
}

// MARK: - History Movie (subset of full movie data)
struct WhisparrHistoryMovie: Codable, Hashable {
    let id: Int
    let title: String
    let images: [WhisparrImage]?
    
    var imageUrl: String? {
        images?.first(where: { $0.coverType == "screenshot" })?.remoteUrl
    }
}

// MARK: - Data (flexible dictionary-like structure)
struct WhisparrHistoryData: Codable, Hashable {
    let fileId: String?
    let droppedPath: String?
    let importedPath: String?
    let downloadClient: String?
    let releaseGroup: String?
    let size: String?
    let downloadUrl: String?
    let age: String?
    
    // Some fields might be missing depending on eventType
    // We map common fields we care about
}

// MARK: - Language
struct WhisparrLanguage: Codable, Hashable {
    let id: Int
    let name: String
}
