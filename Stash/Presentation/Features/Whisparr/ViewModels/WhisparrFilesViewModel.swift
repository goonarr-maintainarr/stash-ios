import Foundation
import Observation
import SwiftUI

/// A ViewModel responsible for managing files and history associated with a Whisparr scene.
///
/// `WhisparrFilesViewModel` fetches the history events for a scene (e.g., grabs, imports) and allows
/// deleting the associated scene file.
@MainActor
@Observable
class WhisparrFilesViewModel {
    /// Represents the state of the history view.
    enum ViewState {
        /// Data is loading.
        case loading
        /// History events are loaded.
        case loaded([WhisparrHistoryEvent])
        /// No history events found.
        case empty
        /// An error occurred while fetching history.
        case error(String)
    }
    
    /// The current state of the history data.
    var historyState: ViewState = .loading
    
    /// Indicates if a file deletion is in progress.
    var isDeleting = false
    
    /// Error message encountered during file deletion.
    var deleteError: String?
    
    private let repository: WhisparrRepositoryProtocol
    private let scene: WhisparrScene
    
    /// Initializes the `WhisparrFilesViewModel`.
    ///
    /// - Parameters:
    ///   - scene: The scene whose files and history are being managed.
    ///   - repository: The repository for data access.
    init(scene: WhisparrScene, repository: WhisparrRepositoryProtocol? = nil) {
        self.scene = scene
        self.repository = repository ?? WhisparrRepository()
    }
    
    /// Fetches the history of events for the scene (grabs, imports, etc.).
    ///
    /// Updates `historyState` based on the result.
    @MainActor
    func fetchHistory() async {
        historyState = .loading
        do {
            let events = try await repository.fetchHistory(sceneId: scene.id)
            let sortedEvents = events.sorted(by: { $0.date > $1.date })
            
            if sortedEvents.isEmpty {
                historyState = .empty
            } else {
                historyState = .loaded(sortedEvents)
            }
        } catch {
            historyState = .error(error.localizedDescription)
        }
    }
    
    /// Deletes the currently associated scene file from Whisparr.
    ///
    /// - Returns: `true` if the deletion was successful, `false` otherwise.
    @MainActor
    func deleteFile() async -> Bool {
        guard let fileId = scene.sceneFile?.id else { return false }
        
        isDeleting = true
        deleteError = nil
        
        do {
            try await repository.deleteSceneFile(fileId: fileId)
            
            // Haptic feedback
            HapticManager.success()
            
            // Notify library changed
            NotificationCenter.default.post(name: .whisparrLibraryChanged, object: nil)
            
            isDeleting = false
            return true
        } catch {
            deleteError = "Failed to delete file: \(error.localizedDescription)"
            isDeleting = false
            return false
        }
    }
}
