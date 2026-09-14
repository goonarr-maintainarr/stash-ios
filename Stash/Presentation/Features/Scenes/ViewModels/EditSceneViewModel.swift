import Observation
import Foundation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "EditSceneViewModel")

/// A ViewModel responsible for managing the state and logic for editing a `Scene`.
///
/// `EditSceneViewModel` allows users to modify scene details such as title, description,
/// associated performers, and tags. It also supports managing playback and O-counter history.
@MainActor
@Observable
final class EditSceneViewModel {
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case saving
        case searching
        case searchingTags
        case error(String)
    }
    
    /// The current ViewState, derived from manager states when possible.
    var state: ViewState {
        if saveManager.isSaving { return .saving }
        if performerManager.isSearching { return .searching }
        if tagManager.isSearching { return .searchingTags }
        if let error = saveManager.errorMessage { return .error(error) }
        return .idle
    }
    
    var title: String
    var details: String
    var director: String
    var code: String
    var url: String
    
    // MARK: - Managers
    
    let performerManager: EditScenePerformerManager
    let tagManager: EditSceneTagManager
    let historyManager: EditSceneHistoryManager
    let saveManager: EditSceneSaveManager
    
    let sceneId: String
    
    /// Initializes the `EditSceneViewModel`.
    ///
    /// - Parameters:
    ///   - scene: The scene to edit.
    ///   - repository: The scene repository.
    ///   - performerRepository: The performer repository.
    ///   - tagRepository: The tag repository.
    init(
        scene: Scene,
        repository: any SceneRepositoryProtocol,
        performerRepository: any PerformerRepositoryProtocol,
        tagRepository: any TagRepositoryProtocol
    ) {
        logger.info("🎬 EditSceneViewModel initializing for scene: \(scene.id)")
        
        self.sceneId = scene.id
        self.title = scene.title ?? ""
        self.details = scene.details ?? ""
        self.director = scene.director ?? ""
        self.code = scene.code ?? ""
        self.url = scene.url ?? ""
        
        // Initialize managers
        self.performerManager = EditScenePerformerManager(
            initialPerformers: scene.performers ?? [],
            performerRepository: performerRepository
        )
        
        self.tagManager = EditSceneTagManager(
            initialTags: scene.tags ?? [],
            tagRepository: tagRepository
        )
        
        self.historyManager = EditSceneHistoryManager(
            oHistory: scene.o_history ?? [],
            playHistory: scene.play_history ?? []
        )
        
        self.saveManager = EditSceneSaveManager(
            sceneId: scene.id,
            repository: repository
        )
        
        logger.debug("✅ EditSceneViewModel initialized with \(self.performerManager.currentPerformers.count) performers, \(self.tagManager.currentTags.count) tags")
    }
    
    // MARK: - Public Methods
    
    /// Clears the current error state.
    func clearError() {
        logger.debug("🧹 Clearing error state")
        saveManager.clearError()
    }
    
    /// Saves all changes to the server.
    ///
    /// This includes updating metadata and deleting removed history entries.
    ///
    /// - Returns: `true` if all operations were successful, otherwise `false`.
    func save() async -> Bool {
        logger.info("💾 Saving scene changes")
        
        let performerIds = performerManager.currentPerformers.map { $0.id }
        let tagIds = tagManager.currentTags.map { $0.id }
        
        let success = await saveManager.save(
            title: title,
            details: details,
            performerIds: performerIds,
            tagIds: tagIds,
            removedOHistory: historyManager.getRemovedOHistory(),
            removedPlayHistory: historyManager.getRemovedPlayHistory(),
            director: director.isEmpty ? nil : director,
            code: code.isEmpty ? nil : code,
            url: url.isEmpty ? nil : url
        )
        
        if success {
            historyManager.clearRemovedTracking()
            logger.info("✅ Scene saved successfully")
        } else {
            logger.error("❌ Failed to save scene")
        }
        
        return success
    }
    
    // MARK: - Performer Methods
    
    /// Adds a performer to the scene's list if not already present.
    func addPerformer(_ performer: Performer) {
        logger.debug("🧑 Adding performer: \(performer.name ?? "Unknown", privacy: .public)")
        performerManager.addPerformer(performer)
    }
    
    /// Removes a performer from the scene's list.
    func removePerformer(id: String) {
        logger.debug("❌ Removing performer: \(id, privacy: .public)")
        performerManager.removePerformer(id: id)
    }
    
    // MARK: - Tag Methods
    
    /// Adds a tag to the scene's list if not already present.
    func addTag(_ tag: Tag) {
        logger.debug("🏷️ Adding tag: \(tag.name, privacy: .public)")
        tagManager.addTag(tag)
    }
    
    /// Removes a tag from the scene's list.
    func removeTag(id: String) {
        logger.debug("❌ Removing tag: \(id, privacy: .public)")
        tagManager.removeTag(id: id)
    }
    
    // MARK: - History Methods
    
    /// Removes an O-counter history entry.
    func removeOHistory(at timestamp: String) {
        logger.debug("🗑️ Removing O-counter entry: \(timestamp, privacy: .public)")
        historyManager.removeOHistory(at: timestamp)
    }
    
    /// Removes a play history entry.
    func removePlayHistory(at timestamp: String) {
        logger.debug("🗑️ Removing play history entry: \(timestamp, privacy: .public)")
        historyManager.removePlayHistory(at: timestamp)
    }
}
