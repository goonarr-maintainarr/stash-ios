import Foundation
import Observation
import SwiftUI
import os


/// A ViewModel responsible for managing the details display and interactions for a specific StashDB scene.
///
/// `StashDBSceneDetailViewModel` handles loading detailed performer information, checking for local matches
/// in the user's Stash, and adding the scene to Whisparr.
@MainActor
@Observable
final class StashDBSceneDetailViewModel {
    private let logger = Logger(subsystem: "com.stash.app", category: "StashDBSceneDetailViewModel")
    
    // MARK: - Type Aliases
    
    typealias OperationState = StashDBSceneOperationState
    
    // MARK: - Managers
    
    private let whisparrManager: StashDBSceneWhisparrManager
    private let performerManager: StashDBScenePerformerManager
    private let dataManager: StashDBSceneDataManager
    
    /// The current view state.
    var state: ViewState<StashDBScene>
    
    var scene: StashDBScene? { state.content }
    
    // MARK: - Forwarded Properties
    
    var operationState: OperationState {
        whisparrManager.operationState
    }
    
    var performerDetails: [String: StashDBPerformer] {
        performerManager.performerDetails
    }
    
    var localPerformerIds: [String: String] {
        performerManager.localPerformerIds
    }
    
    var localPerformerOCounts: [String: Int] {
        performerManager.localPerformerOCounts
    }
    
    var localImagePaths: [String: String] {
        performerManager.localImagePaths
    }
    
    var localPerformerSceneCounts: [String: Int] {
        performerManager.localPerformerSceneCounts
    }
    
    // MARK: - Computed Properties for Compatibility
    
    var isAddingToWhisparr: Bool {
        if case .adding = operationState { return true }
        return false
    }
    
    var showSuccessMessage: Bool {
        if case .success = operationState { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = operationState { return message }
        return nil
    }
    
    // MARK: - Dependencies (kept for potential future use)
    
    /// Returns a list of performer appearances that are *not* male.
    ///
    /// This property relies on `performerDetails` being populated to check the gender.
    /// If details are not yet loaded for a performer, they are excluded from this list.
    var femalePerformers: [StashDBPerformerAppearance] {
        guard let scene = self.scene else { return [] }
        return (scene.performers ?? []).filter { appearance in
            // Only show performers we've loaded and confirmed are not male
            guard let details = performerDetails[appearance.performer.id] else {
                return false // Don't show until we've loaded and verified gender
            }
            return details.gender?.uppercased() != "MALE"
        }
    }
    
    /// Initializes the `StashDBSceneDetailViewModel`.
    ///
    /// - Parameter scene: The StashDB scene to display.
    /// Initializes the `StashDBSceneDetailViewModel`.
    ///
    /// - Parameter scene: The StashDB scene to display.
    init(
        scene: StashDBScene,
        whisparrManager: StashDBSceneWhisparrManager,
        performerManager: StashDBScenePerformerManager,
        dataManager: StashDBSceneDataManager
    ) {
        self.state = .content(scene)
        
        // Injected managers
        self.whisparrManager = whisparrManager
        self.performerManager = performerManager
        self.dataManager = dataManager
    }
    
    /// Adds the current scene to the user's Whisparr instance.
    ///
    /// This process involves:
    /// 1. Looking up the scene in Whisparr via its Stash ID (to get the internal Whisparr format).
    /// 2. Adding the movie to Whisparr using configured quality profile and root folder.
    /// 3. Optimistically saving the new movie to the local database.
    /// 4. Triggering a background metadata refresh on Whisparr.
    ///
    /// - Returns: `true` if the add operation was successful, `false` otherwise.
    func addToWhisparr() async -> Bool {
        guard let scene = self.scene else { return false }
        return await whisparrManager.addToWhisparr(sceneId: scene.id)
    }
    
    /// Fetches full scene details from StashDB if needed.
    /// Only fetches if we don't already have full details (checks for details/duration fields).
    func fetchFullDetails() async {
        guard case .content(let currentScene) = state else { return }
        
        // Skip fetch if we already have full details (details or duration field is populated)
        // Overview queries omit these fields, full queries include them
        if currentScene.details != nil || currentScene.duration != nil {
            logger.debug("⏭️ Scene already has full details, skipping fetch")
            return
        }
        
        logger.info("🔍 Fetching full scene details for \(currentScene.id)")
        
        do {
            let fullScene = try await dataManager.fetchFullDetails(sceneId: currentScene.id)
            self.state = .content(fullScene)
        } catch {
            logger.error("Failed to fetch full scene details: \(error.localizedDescription)")
        }
    }

    /// Fetches detailed information for all performers in the scene from StashDB.
    func loadPerformerDetails() async {
        guard let scene = self.scene, let performers = scene.performers else { return }
        await performerManager.loadPerformerDetails(for: performers)
    }
    
    /// Checks the local Stash database for matches for any of the scene's performers.
    func checkLocalPerformers() async {
        guard let scene = self.scene, let performers = scene.performers else { return }
        await performerManager.checkLocalPerformers(for: performers)
    }
}
