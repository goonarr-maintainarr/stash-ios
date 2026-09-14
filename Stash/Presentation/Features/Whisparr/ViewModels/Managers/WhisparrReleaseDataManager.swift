import Foundation
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrReleaseDataManager")

/// Manages data operations for Whisparr releases (search and download).
@MainActor
@Observable
class WhisparrReleaseDataManager {
    
    // MARK: - State
    
    /// The full list of fetched releases.
    var releases: [WhisparrRelease] = []
    
    // MARK: - Dependencies
    
    private let repository: WhisparrRepositoryProtocol
    private var movieId: Int?
    
    // MARK: - Initialization
    
    init(repository: WhisparrRepositoryProtocol) {
        self.repository = repository
        logger.debug("🔧 WhisparrReleaseDataManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Performs a search for releases associated with a specific movie ID.
    func search(movieId: Int, term: String? = nil) async throws -> [WhisparrRelease] {
        self.movieId = movieId
        
        logger.info("🔍 Starting search for movieId: \(movieId, privacy: .public)")
        
        let fetchedReleases = try await repository.fetchReleases(sceneId: movieId, term: term)
        self.releases = fetchedReleases
        
        logger.info("✅ Fetched \(fetchedReleases.count, privacy: .public) releases")
        
        return fetchedReleases
    }
    
    /// Triggers a download for a specific release.
    func download(release: WhisparrRelease) async throws {
        guard let movieId = movieId else {
            logger.error("❌ Cannot download - no movieId set")
            throw NSError(domain: "WhisparrReleaseDataManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Movie ID not set"
            ])
        }
        
        logger.info("⬇️ Downloading release: \(release.title, privacy: .public)")
        
        try await repository.downloadRelease(release: release, sceneId: movieId)
        
        logger.info("✅ Download initiated successfully for: \(release.title, privacy: .public)")
    }
    /// Triggers a remote search command for the movie.
    func triggerRemoteSearch(movieId: Int) async throws {
        logger.info("⚡ Triggering remote search for movieId: \(movieId)")
        try await repository.performAutomaticSearch(sceneId: movieId)
        logger.info("✅ Remote search triggered")
    }
}
