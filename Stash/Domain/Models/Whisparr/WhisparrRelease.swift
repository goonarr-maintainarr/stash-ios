import Foundation
import Combine

struct WhisparrRelease: Codable, Identifiable, Hashable {
    let guid: String
    let quality: QualityInfo
    let customFormats: [CustomFormat]?
    let customFormatScore: Int?
    let qualityWeight: Int
    let age: Int
    let ageHours: Double
    let ageMinutes: Double
    let size: Int64
    let indexerId: Int
    let indexer: String?
    let releaseGroup: String?
    let releaseHash: String?
    let title: String
    let sceneSource: Bool?
    let sceneOrigin: String?
    let rejected: Bool?
    let rejections: [String]?
    let publishDate: String?
    let downloadUrl: String?
    let infoUrl: String?
    let downloadAllowed: Bool?
    let releaseWeight: Int?
    let `protocol`: String?
    let seeders: Int?
    let leechers: Int?
    
    var id: String { guid }
    
    enum CodingKeys: String, CodingKey {
        case guid, quality, customFormats, customFormatScore
        case qualityWeight, age, ageHours, ageMinutes
        case size, indexerId, indexer, releaseGroup, releaseHash
        case title, sceneSource, sceneOrigin, rejected, rejections
        case publishDate, downloadUrl, infoUrl, downloadAllowed
        case releaseWeight, seeders, leechers
        case `protocol` = "protocol"
    }
    
    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var qualityName: String {
        quality.quality.name ?? "Unknown"
    }
    
    var isProper: Bool {
        quality.revision.isRepack
    }
    
    struct QualityInfo: Codable, Hashable {
        let quality: QualityDetail
        let revision: Revision
        
        struct QualityDetail: Codable, Hashable {
            let id: Int
            let name: String?
            let source: String?
            let resolution: Int
        }
        
        struct Revision: Codable, Hashable {
            let version: Int
            let real: Int
            let isRepack: Bool
        }
    }
    
    struct CustomFormat: Codable, Hashable {
        let id: Int?
        let name: String?
    }
}
