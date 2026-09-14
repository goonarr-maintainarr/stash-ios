import Foundation
@testable import Stash

// MARK: - Test Helpers for WhisparrScene

extension WhisparrScene {
    /// Creates a minimal test WhisparrScene with sensible defaults
    static func testScene(
        id: Int = 1,
        title: String = "Test Scene",
        code: String? = nil,
        overview: String? = nil,
        releaseDate: Date? = nil,
        year: Int = 2024,
        runtime: Int = 30,
        studioTitle: String? = "Test Studio",
        studioForeignId: String? = nil,
        foreignId: String? = "stash:test-uuid-123",
        hasFile: Bool = true,
        monitored: Bool = true,
        sizeOnDisk: Int64 = 1_000_000_000,
        rootFolderPath: String? = "/movies",
        path: String? = nil,
        qualityProfileId: Int? = 1,
        genres: [String] = [],
        images: [WhisparrImage] = [],
        credits: [WhisparrCredit] = [],
        sceneFile: WhisparrSceneFile? = nil,
        statistics: WhisparrStatistics? = nil,
        itemType: String = "scene",
        added: Date = Date()
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
            monitored: monitored,
            sizeOnDisk: sizeOnDisk,
            rootFolderPath: rootFolderPath,
            path: path,
            qualityProfileId: qualityProfileId,
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
