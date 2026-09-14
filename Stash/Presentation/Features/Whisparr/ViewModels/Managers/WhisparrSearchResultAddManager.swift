import Observation
import os
import Foundation

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSearchResultAddManager")

/// Manages adding scenes to Whisparr and performing automatic searches.
@MainActor
@Observable
class WhisparrSearchResultAddManager: ErrorStateManaging {
    
    // MARK: - State
    
    /// The movie object returned after a successful add operation.
    var addedMovie: WhisparrScene?
    
    /// Whether currently adding to Whisparr.
    var isAdding = false
    
    /// Whether currently performing automatic search.
    var isSearching = false
    
    /// Success message.
    var successMessage: String?
    
    /// Error message.
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let repository: WhisparrRepositoryProtocol
    
    // MARK: - Initialization
    
    init(repository: WhisparrRepositoryProtocol) {
        self.repository = repository
        logger.debug("🔧 WhisparrSearchResultAddManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Adds the movie to the user's Whisparr library.
    @discardableResult
    func addToWhisparr(
        searchResult: WhisparrSearchResult,
        rootFolder: WhisparrRootFolder,
        qualityProfile: WhisparrQualityProfile
    ) async -> Bool {
        logger.info("➕ Adding to Whisparr: \(searchResult.title, privacy: .public)")
        
        isAdding = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // Create lookup scene from search result
            let lookupScene = WhisparrLookupScene(
                foreignId: searchResult.foreignId,
                title: searchResult.title,
                overview: searchResult.overview,
                status: "released",
                studioTitle: searchResult.studioTitle,
                id: nil,
                monitored: nil
            )
            
            let movie = try await repository.addScene(
                lookupScene: lookupScene,
                qualityProfileId: qualityProfile.id,
                rootFolderPath: rootFolder.path
            )
            
            self.addedMovie = movie
            self.successMessage = "Added to Whisparr!"
            
            logger.info("✅ Successfully added to Whisparr (ID: \(movie.id, privacy: .public))")
            
            isAdding = false
            return true
            
        } catch {
            setError(error)
            logger.error("❌ Failed to add to Whisparr: \(error.localizedDescription, privacy: .public)")
            isAdding = false
            return false
        }
    }
    
    /// Triggers an automatic search for the newly added movie.
    func performAutomaticSearch(for movie: WhisparrScene) async -> Bool {
        logger.info("🔍 Performing automatic search for: \(movie.title, privacy: .public)")
        
        isSearching = true
        clearError()
        successMessage = nil
        
        do {
            try await repository.performAutomaticSearch(sceneId: movie.id)
            
            successMessage = "Search started!"
            logger.info("✅ Automatic search started")
            
            // Brief delay to show success
            try await Task.sleep(nanoseconds: 2_000_000_000)
            successMessage = nil
            
            isSearching = false
            return true
            
        } catch {
            setError(error)
            logger.error("❌ Automatic search failed: \(error.localizedDescription, privacy: .public)")
            isSearching = false
            return false
        }
    }
    
    /// Clears error and success messages.
    func clearMessages() {
        clearError()
        successMessage = nil
    }
}
