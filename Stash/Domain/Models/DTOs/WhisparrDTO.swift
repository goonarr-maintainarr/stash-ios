import Foundation

// MARK: - Whisparr DTO (API Response)

/// Data Transfer Object for Whisparr API responses.
/// The Whisparr API uses "Movie" terminology, but we map to `WhisparrScene` domain model.
/// Use `toDomain()` to convert to the domain model.
struct WhisparrMovieDTO: Codable {
    let id: Int
    let title: String
    let code: String?
    let overview: String?
    let releaseDate: Date?
    let year: Int
    let runtime: Int
    let studioTitle: String?
    let studioForeignId: String?
    let foreignId: String?
    let hasFile: Bool?
    let movieFileId: Int?
    let monitored: Bool
    let sizeOnDisk: Int64
    let rootFolderPath: String?
    let path: String?
    let qualityProfileId: Int?
    let genres: [String]
    let images: [WhisparrImage]
    let credits: [WhisparrCredit]
    let movieFile: WhisparrMovieFileDTO?
    let statistics: WhisparrStatistics?
    let itemType: String
    let added: Date
    
    /// Computed hasFile value: use explicit hasFile if present, otherwise derive from movieFileId
    var computedHasFile: Bool {
        if let hasFile = hasFile {
            return hasFile
        }
        return movieFileId != nil
    }
    
    /// Derive root folder path from the full path if not provided by API
    /// Whisparr's single movie GET endpoint doesn't return rootFolderPath,
    /// so we extract it from the path field
    private func deriveRootFolderPath() -> String? {
        // If API provided it, use it
        if let rootFolder = rootFolderPath {
            return rootFolder
        }
        
        // Extract from path: try first component, or first two if looks like nested path
        guard let fullPath = path else { return nil }
        
        let components = fullPath.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty else { return nil }
        
        // If path starts with common nested patterns like "data/media", use both
        if components.count >= 2 && (components[0] == "data" || components[0] == "mnt") {
            return "/" + components[0...1].joined(separator: "/")
        }
        
        // Otherwise use first component
        return "/" + components[0]
    }
    
    /// Convert API DTO to domain model
    func toDomain() -> WhisparrScene {
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
            hasFile: computedHasFile,
            monitored: monitored,
            sizeOnDisk: sizeOnDisk,
            rootFolderPath: deriveRootFolderPath(),
            path: path,
            qualityProfileId: qualityProfileId,
            genres: genres,
            images: images,
            credits: credits,
            sceneFile: movieFile?.toDomain(),
            statistics: statistics,
            itemType: itemType,
            added: added
        )
    }
}

struct WhisparrMovieFileDTO: Codable {
    let id: Int
    let size: Int64
    let dateAdded: Date
    let sceneName: String?
    let releaseGroup: String?
    let quality: WhisparrQuality
    let mediaInfo: WhisparrMediaInfo?
    let path: String
    let relativePath: String
    
    func toDomain() -> WhisparrSceneFile {
        WhisparrSceneFile(
            id: id,
            size: size,
            dateAdded: dateAdded,
            sceneName: sceneName,
            releaseGroup: releaseGroup,
            quality: quality,
            mediaInfo: mediaInfo,
            path: path,
            relativePath: relativePath
        )
    }
}

// MARK: - Movie Editor Request

/// Request body for the /api/v3/movie/editor bulk update endpoint
struct WhisparrMovieEditorRequest: Codable {
    let movieIds: [Int]
    let monitored: Bool?
    let qualityProfileId: Int?
    let rootFolderPath: String?
    let moveFiles: Bool?
    let applyTags: String = "replace"
    let tags: [Int] = []
}
