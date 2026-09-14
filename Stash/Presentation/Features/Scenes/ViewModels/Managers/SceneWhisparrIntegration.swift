import Observation
import Foundation
import Combine
import os

/// Manages Whisparr integration for scenes.
@MainActor
@Observable
final class SceneWhisparrIntegration {
    
    // MARK: - State
    
    /// Represents the Whisparr integration state.
    struct WhisparrState: Equatable {
        var movieId: Int?
        var movie: WhisparrScene?
        var isResolving: Bool
        
        static var initial: WhisparrState {
            WhisparrState(movieId: nil, movie: nil, isResolving: false)
        }
    }
    
    private(set) var state: WhisparrState = .initial
    
    // MARK: - Dependencies
    
    private let whisparrRepository: any WhisparrRepositoryProtocol
    private let settings: SettingsStoreProtocol
    
    // MARK: - Convenience Properties
    
    var movieId: Int? { state.movieId }
    var movie: WhisparrScene? { state.movie }
    var isResolving: Bool { state.isResolving }
    
    // MARK: - Initialization
    
    init(
        whisparrRepository: any WhisparrRepositoryProtocol,
        settings: SettingsStoreProtocol
    ) {
        self.whisparrRepository = whisparrRepository
        self.settings = settings
    }
    
    // MARK: - Whisparr Operations
    
    /// Attempts to find a corresponding movie in Whisparr for the current scene.
    ///
    /// It first tries matching by StashDB ID, then by local scene ID.
    /// If found, it populates `movie` and `movieId`.
    func resolveWhisparrId(scene: Scene) async {
        let url = settings.whisparrUrl
        guard !url.isEmpty else {
            Logger.scenes.warning("⚠️ Missing Whisparr URL")
            return
        }
        
        state.isResolving = true
        
        // Determine the lookup term
        var lookupTerm: String?
        var lookupSource: String = "Unknown"
        
        if let stashDbId = scene.stash_ids?.first?.stash_id {
            lookupTerm = stashDbId
            lookupSource = "StashDB ID"
        } else {
            lookupTerm = "stash:\(scene.id)"
            lookupSource = "Local Scene ID"
        }
        
        guard let term = lookupTerm else {
            Logger.scenes.warning("⚠️ No valid StashDB ID or Local ID found for lookup.")
            state.isResolving = false
            return
        }
        
        Logger.scenes.info("🔍 STARTING Whisparr Lookup using \(lookupSource): \(term, privacy: .public)")
        
        do {
            if let lookupResult = try await whisparrRepository.lookupScene(stashId: term),
               let movieId = lookupResult.id {
                 Logger.scenes.debug("📥 Lookup Result: Title='\(lookupResult.title)', ID=\(movieId)")
                 
                 // Fetch full movie details to be sure (Repository fetchMovie calls getMovie)
                 let fullMovie = try await whisparrRepository.fetchRemoteScene(id: movieId)
                 
                 state.movieId = fullMovie.id
                 state.movie = fullMovie
                 state.isResolving = false
                 
                 Logger.scenes.info("🎉 Loaded details for: \(fullMovie.title)")
            } else {
                Logger.scenes.warning("❌ Lookup returned NO results (or not in library) for term: \(term)")
                state.movieId = nil
                state.movie = nil
                state.isResolving = false
            }
        } catch {
            Logger.scenes.error("❌ Failed to resolve Whisparr ID: \(error.localizedDescription)")
            state.movieId = nil
            state.movie = nil
            state.isResolving = false
        }
    }
    
    /// Refreshes a Whisparr scene by its Stash ID.
    func refreshWhisparrScene(stashId: String) async {
        do {
            // Find movie by Stash ID first
            if let whisparrMovie = try await whisparrRepository.lookupScene(stashId: stashId),
               let movieId = whisparrMovie.id {
                // Refresh
                try await whisparrRepository.refreshScene(sceneId: movieId)
                Logger.scenes.info("✅ Triggered Whisparr refresh for scene ID: \(movieId)")
            }
        } catch {
            Logger.scenes.error("Failed to refresh Whisparr scene: \(error.localizedDescription, privacy: .public)")
        }
    }
}
