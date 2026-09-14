import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSceneOperationsManager")

/// Manages Whisparr scene operations like search, refresh, monitor toggle, and delete.
@MainActor
@Observable
class WhisparrSceneOperationsManager {
    
    // MARK: - State
    
    var operationState: WhisparrSceneOperationState = .idle
    
    // MARK: - Dependencies
    
    private let repository: WhisparrRepositoryProtocol
    
    // MARK: - Initialization
    
    init(repository: WhisparrRepositoryProtocol) {
        self.repository = repository
        logger.debug("🔧 WhisparrSceneOperationsManager initialized")
    }
    
    // MARK: - Operations
    
    // MARK: - Operations
    
    /// Triggers automatic search for the scene and waits for results (interactive mode).
    /// - Returns: True if releases were found, False if timed out.
    func performInteractiveSearch(sceneId: Int) async -> Bool {
        logger.info("🔍 Starting interactive search for scene \(sceneId)")
        operationState = .searching
        
        do {
            // Direct call to fetchReleases (which now passes episodeId to trigger synchronous search)
            let releases = try await repository.fetchReleases(sceneId: sceneId, term: nil)
            
            if !releases.isEmpty {
                logger.info("✅ Found \(releases.count) releases")
                operationState = .success("Found \(releases.count) Releases")
                
                // Cleanup success state after delay
                Task {
                     try? await Task.sleep(nanoseconds: 2_000_000_000)
                     self.operationState = .idle
                }
                return true
            } else {
                logger.warning("⚠️ Search completed but no releases found")
                operationState = .error("No releases found")
                return false
            }
        } catch {
            logger.error("❌ Interactive search failed: \(error.localizedDescription)")
            operationState = .error("Search failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Triggers automatic search for the scene in Whisparr (Fire & Forget).
    func performAutomaticSearch(sceneId: Int) async -> Bool {
        logger.info("🔍 Performing automatic search for scene \(sceneId)")
        operationState = .searching
        
        do {
            try await repository.performAutomaticSearch(sceneId: sceneId)
            logger.info("✅ Search queued successfully")
            
            operationState = .success("Search Queued")
            
            // Hide toast after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.operationState = .idle
            }
            return true
        } catch {
            logger.error("❌ Automatic search failed: \(error.localizedDescription)")
            operationState = .error("Automatic search failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Toggles the monitoring status of the scene.
    func toggleMonitorStatus(scene: WhisparrScene) async throws -> WhisparrScene {
        // Prevent concurrent operations
        guard operationState != .togglingMonitor else {
            logger.warning("⚠️ Toggle already in progress, ignoring duplicate request")
            throw AppError.validation(.custom("Toggle already in progress"))
        }
        
        logger.info("🔄 Toggling monitor status for scene \(scene.id)")
        operationState = .togglingMonitor
        defer { operationState = .idle }
        
        do {
            let confirmedScene = try await repository.toggleMonitorStatus(scene: scene)
            logger.info("✅ Monitor status confirmed: \(confirmedScene.monitored)")
            return confirmedScene
        } catch {
            logger.error("❌ Toggle failed: \(error.localizedDescription)")
            throw error.toAppError()
        }
    }
    
    /// Refreshes scene metadata from foreign sources.
    func refreshScene(sceneId: Int) async -> Bool {
        logger.info("🔄 Refreshing scene metadata for \(sceneId)")
        operationState = .refreshing
        
        do {
            try await repository.refreshScene(sceneId: sceneId)
            logger.info("✅ Refresh queued successfully")
            
            // Wait for Whisparr to process
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            operationState = .idle
            return true
        } catch {
            logger.error("❌ Failed to trigger refresh: \(error.localizedDescription)")
            operationState = .error("Failed to refresh: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Deletes the scene from Whisparr.
    func deleteScene(
        scene: WhisparrScene,
        deleteFiles: Bool,
        addImportExclusion: Bool
    ) async -> Bool {
        logger.info("🗑️ Deleting scene \(scene.id), deleteFiles: \(deleteFiles), addExclusion: \(addImportExclusion)")
        operationState = .deleting
        
        do {
            try await repository.deleteScene(
                scene: scene,
                deleteFiles: deleteFiles,
                addImportExclusion: addImportExclusion
            )
            logger.info("✅ Scene deleted successfully")
            
            operationState = .idle
            return true
        } catch {
            logger.error("❌ Failed to remove scene: \(error.localizedDescription)")
            operationState = .error("Failed to remove: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Operation State

enum WhisparrSceneOperationState: Equatable {
    case idle
    case searching
    case deleting
    case togglingMonitor
    case refreshing
    case success(String)
    case error(String)
}
