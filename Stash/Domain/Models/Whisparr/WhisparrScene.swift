import Foundation
import Combine
@preconcurrency import GRDB

@preconcurrency struct WhisparrScene: Identifiable, Codable, Equatable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    let id: Int
    let title: String
    let code: String?
    let overview: String?
    let releaseDate: Date?
    let year: Int
    let runtime: Int
    let studioTitle: String?
    let studioForeignId: String?
    let foreignId: String?  // StashDB ID in format "stash:xxx" or just the UUID
    let hasFile: Bool
    let monitored: Bool
    let sizeOnDisk: Int64
    let rootFolderPath: String?
    let path: String? // Full path to the scene folder
    let qualityProfileId: Int?
    let genres: [String]
    let images: [WhisparrImage]
    let credits: [WhisparrCredit]
    let sceneFile: WhisparrSceneFile?
    let statistics: WhisparrStatistics?
    let itemType: String
    let added: Date
    
    var imageUrl: String? {
        images.first(where: { $0.coverType == "screenshot" })?.remoteUrl
    }
    
    var performerNames: String {
        credits.compactMap { $0.performer.name }.joined(separator: ", ")
    }
    
    // MARK: - GRDB
    
    static let databaseTableName = "whisparr_scenes"
    
    // Store complex types as JSON
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let code = Column("code")
        static let overview = Column("overview")
        static let releaseDate = Column("releaseDate")
        static let year = Column("year")
        static let runtime = Column("runtime")
        static let studioTitle = Column("studioTitle")
        static let studioForeignId = Column("studioForeignId")
        static let foreignId = Column("foreignId")
        static let hasFile = Column("hasFile")
        static let monitored = Column("monitored")
        static let sizeOnDisk = Column("sizeOnDisk")
        static let rootFolderPath = Column("rootFolderPath")
        static let path = Column("path")
        static let qualityProfileId = Column("qualityProfileId")
        static let genresJSON = Column("genresJSON")
        static let imagesJSON = Column("imagesJSON")
        static let creditsJSON = Column("creditsJSON")
        static let sceneFileJSON = Column("movieFileJSON") // DB Column remains movieFileJSON
        static let statisticsJSON = Column("statisticsJSON")
        static let itemType = Column("itemType")
        static let added = Column("added")
    }
    
    // Custom encoding to database
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["title"] = title
        container["code"] = code
        container["overview"] = overview
        container["releaseDate"] = releaseDate
        container["year"] = year
        container["runtime"] = runtime
        container["studioTitle"] = studioTitle
        container["studioForeignId"] = studioForeignId
        container["foreignId"] = foreignId
        container["hasFile"] = hasFile
        container["monitored"] = monitored
        container["sizeOnDisk"] = sizeOnDisk
        container["rootFolderPath"] = rootFolderPath
        container["path"] = path
        container["qualityProfileId"] = qualityProfileId
        container["itemType"] = itemType
        container["added"] = added
        
        // Encode arrays/objects as JSON strings
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let genresData = try encoder.encode(genres)
        container["genresJSON"] = String(data: genresData, encoding: .utf8)
        
        let imagesData = try encoder.encode(images)
        container["imagesJSON"] = String(data: imagesData, encoding: .utf8)
        
        let creditsData = try encoder.encode(credits)
        container["creditsJSON"] = String(data: creditsData, encoding: .utf8)
        
        if let sceneFile = sceneFile {
            let data = try encoder.encode(sceneFile)
            container["movieFileJSON"] = String(data: data, encoding: .utf8)
        }
        
        if let statistics = statistics {
            let data = try encoder.encode(statistics)
            container["statisticsJSON"] = String(data: data, encoding: .utf8)
        }
    }
    
    // Explicit memberwise initializer to support with() method
    init(
        id: Int,
        title: String,
        code: String?,
        overview: String?,
        releaseDate: Date?,
        year: Int,
        runtime: Int,
        studioTitle: String?,
        studioForeignId: String?,
        foreignId: String?,
        hasFile: Bool,
        monitored: Bool,
        sizeOnDisk: Int64,
        rootFolderPath: String?,
        path: String?,
        qualityProfileId: Int?,
        genres: [String],
        images: [WhisparrImage],
        credits: [WhisparrCredit],
        sceneFile: WhisparrSceneFile?,
        statistics: WhisparrStatistics?,
        itemType: String,
        added: Date
    ) {
        self.id = id
        self.title = title
        self.code = code
        self.overview = overview
        self.releaseDate = releaseDate
        self.year = year
        self.runtime = runtime
        self.studioTitle = studioTitle
        self.studioForeignId = studioForeignId
        self.foreignId = foreignId
        self.hasFile = hasFile
        self.monitored = monitored
        self.sizeOnDisk = sizeOnDisk
        self.rootFolderPath = rootFolderPath
        self.path = path
        self.qualityProfileId = qualityProfileId
        self.genres = genres
        self.images = images
        self.credits = credits
        self.sceneFile = sceneFile
        self.statistics = statistics
        self.itemType = itemType
        self.added = added
    }

    // Custom decoding from database
    init(row: Row) throws {
        id = row["id"]
        title = row["title"]
        code = row["code"]
        overview = row["overview"]
        releaseDate = row["releaseDate"]
        year = row["year"]
        runtime = row["runtime"]
        studioTitle = row["studioTitle"]
        studioForeignId = row["studioForeignId"]
        foreignId = row["foreignId"]
        hasFile = row["hasFile"]
        monitored = row["monitored"]
        sizeOnDisk = row["sizeOnDisk"]
        rootFolderPath = row["rootFolderPath"]
        path = row["path"]
        qualityProfileId = row["qualityProfileId"]
        itemType = row["itemType"]
        added = row["added"]
        
        // Decode JSON strings back to arrays/objects
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let genresJSON: String = row["genresJSON"]
        let genresData = Data(genresJSON.utf8)
        genres = try decoder.decode([String].self, from: genresData)
        
        let imagesJSON: String = row["imagesJSON"]
        let imagesData = Data(imagesJSON.utf8)
        images = try decoder.decode([WhisparrImage].self, from: imagesData)
        
        let creditsJSON: String = row["creditsJSON"]
        let creditsData = Data(creditsJSON.utf8)
        credits = try decoder.decode([WhisparrCredit].self, from: creditsData)
        
        if let sceneFileJSON: String = row["movieFileJSON"] {
            let data = Data(sceneFileJSON.utf8)
            sceneFile = try decoder.decode(WhisparrSceneFile.self, from: data)
        } else {
            sceneFile = nil
        }
        
        if let statisticsJSON: String = row["statisticsJSON"] {
            let data = Data(statisticsJSON.utf8)
            statistics = try decoder.decode(WhisparrStatistics.self, from: data)
        } else {
            statistics = nil
        }
    }
}

@preconcurrency struct WhisparrSceneFile: Codable, Equatable, Hashable, Sendable {
    let id: Int
    let size: Int64
    let dateAdded: Date
    let sceneName: String?
    let releaseGroup: String?
    let quality: WhisparrQuality
    let mediaInfo: WhisparrMediaInfo?
    let path: String
    let relativePath: String
}

@preconcurrency struct WhisparrLookupScene: Codable, Sendable {
    let foreignId: String
    let title: String
    let overview: String?
    let status: String?
    let studioTitle: String?
    let id: Int? // Present if already in library
    let monitored: Bool? // Present if already in library
    
    enum CodingKeys: String, CodingKey {
        case foreignId
        case title
        case overview
        case status
        case studioTitle = "studio"
        case id
        case monitored
    }
}

// MARK: - Helper Extension for Copying
extension WhisparrScene {
    func with(
        monitored: Bool? = nil,
        qualityProfileId: Int? = nil,
        rootFolderPath: String? = nil
    ) -> WhisparrScene {
        WhisparrScene(
            id: id,
            title: title,
            code: code,
            overview: overview,
            releaseDate: releaseDate,
            year: year,
            runtime: runtime,
            studioTitle: studioTitle,
            studioForeignId: studioForeignId,
            foreignId: foreignId,
            hasFile: hasFile,
            monitored: monitored ?? self.monitored,
            sizeOnDisk: sizeOnDisk,
            rootFolderPath: rootFolderPath ?? self.rootFolderPath,
            path: path,
            qualityProfileId: qualityProfileId ?? self.qualityProfileId,
            genres: genres,
            images: images,
            credits: credits,
            sceneFile: sceneFile,
            statistics: statistics,
            itemType: itemType,
            added: added
        )
    }
}

@preconcurrency struct WhisparrImage: Codable, Equatable, Hashable, Sendable {
    let coverType: String
    let url: String?
    let remoteUrl: String?
}

@preconcurrency struct WhisparrCredit: Codable, Equatable, Hashable, Sendable {
    let performer: WhisparrPerformer
    let type: String
    let order: Int
}

@preconcurrency struct WhisparrPerformer: Codable, Equatable, Hashable, Sendable {
    let name: String?
    let gender: String?
    let foreignId: String
    let images: [WhisparrImage]?
}

@preconcurrency struct WhisparrQuality: Codable, Equatable, Hashable, Sendable {
    let quality: QualityDetail
    let revision: QualityRevision
    
    struct QualityDetail: Codable, Equatable, Hashable, Sendable {
        let id: Int
        let name: String
        let source: String
        let resolution: Int
    }
    
    struct QualityRevision: Codable, Equatable, Hashable, Sendable {
        let version: Int
        let real: Int
        let isRepack: Bool
    }
}

@preconcurrency struct WhisparrMediaInfo: Codable, Equatable, Hashable, Sendable {
    let videoCodec: String
    let audioCodec: String
    let resolution: String
    let runTime: String
    let videoBitrate: Int
    let audioBitrate: Int
    let videoFps: Double
    let audioChannels: Double  // Changed to Double to handle values like 5.1
    let videoBitDepth: Int
    let scanType: String
}

@preconcurrency struct WhisparrStatistics: Codable, Equatable, Hashable, Sendable {
    let movieFileCount: Int
    let sizeOnDisk: Int64
    let releaseGroups: [String]
}

@preconcurrency struct WhisparrRootFolder: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: Int
    let path: String
    let accessible: Bool?
    let freeSpace: Int64?
    let unmappedFolders: [UnmappedFolder]?
    
    struct UnmappedFolder: Codable, Equatable, Hashable, Sendable {
        let name: String
        let path: String
    }
}

@preconcurrency struct WhisparrQualityProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: Int
    let name: String
}


@preconcurrency struct WhisparrHistoryEvent: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: Int
    let movieId: Int
    let eventType: WhisparrEventType
    let date: Date
    let sourceTitle: String?
    let quality: WhisparrQuality?
    let data: [String: String?]?
}

@preconcurrency enum WhisparrEventType: String, Codable, Equatable, Sendable {
    case grabbed
    case downloadFolderImported
    case downloadFailed
    case deleted
    case renamed
    case ignored
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // API might return string value
        if let stringValue = try? container.decode(String.self) {
            self = WhisparrEventType(rawValue: stringValue) ?? .unknown
            return
        }
        // Or integer value
        if let intValue = try? container.decode(Int.self) {
            switch intValue {
            case 1: self = .grabbed
            case 3: self = .downloadFolderImported
            case 4: self = .downloadFailed
            case 6: self = .deleted
            case 8: self = .renamed
            case 9: self = .ignored
            default: self = .unknown
            }
            return
        }
        self = .unknown
    }
}
