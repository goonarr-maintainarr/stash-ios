import Foundation
import Combine

/// A protocol that provides default implementations for common database notification observers.
///
/// ViewModels that conform to this protocol automatically get observers for:
/// - Database changes (`.stashDatabaseChanged`)
/// - Scene updates (`.sceneUpdated`)
/// - Performer updates (`.performerUpdated`)
///
/// Usage:
/// ```swift
/// @MainActor
/// final class MyViewModel: ObservableObject, DatabaseObservable {
///     var cancellables = Set<AnyCancellable>()
///     
///     init() {
///         setupDatabaseObservers()
///     }
///     
///     func onDatabaseChanged() {
///         // Handle database change
///     }
/// }
/// ```
@MainActor
protocol DatabaseObservable: AnyObject {
    /// Storage for Combine subscriptions. Required by conforming types.
    var cancellables: Set<AnyCancellable> { get set }
    
    /// Called when the Stash database changes (e.g., scene deletion, bulk updates).
    /// Override this method to handle database change events.
    func onDatabaseChanged()
    
    /// Called when a specific scene is updated.
    /// Override this method to handle scene update events.
    /// - Parameter notification: The notification containing scene update info
    func onSceneUpdated(_ notification: Notification)
    
    /// Called when a specific performer is updated.
    /// Override this method to handle performer update events.
    /// - Parameter notification: The notification containing performer update info
    func onPerformerUpdated(_ notification: Notification)
}

// MARK: - Default Implementations

extension DatabaseObservable {
    /// Sets up observers for common database notifications.
    ///
    /// Call this method in your ViewModel's init() to automatically
    /// subscribe to database change notifications.
    func setupDatabaseObservers() {
        observeDatabaseChanges()
        observeSceneUpdates()
        observePerformerUpdates()
    }
    
    /// Observes the `.stashDatabaseChanged` notification.
    ///
    /// This notification is posted when the database has significant changes
    /// that require reloading data (e.g., bulk updates, deletions).
    func observeDatabaseChanges() {
        NotificationCenter.default.publisher(for: .stashDatabaseChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.onDatabaseChanged()
            }
            .store(in: &cancellables)
    }
    
    /// Observes the `.sceneUpdated` notification.
    ///
    /// This notification is posted when a specific scene is updated
    /// (e.g., metadata change, rating update).
    func observeSceneUpdates() {
        NotificationCenter.default.publisher(for: .sceneUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.onSceneUpdated(notification)
            }
            .store(in: &cancellables)
    }
    
    /// Observes the `.performerUpdated` notification.
    ///
    /// This notification is posted when a specific performer is updated
    /// (e.g., image change, details update).
    func observePerformerUpdates() {
        NotificationCenter.default.publisher(for: .performerUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.onPerformerUpdated(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Default No-Op Implementations
    
    /// Default implementation that does nothing.
    /// Override this in your ViewModel if you need to handle database changes.
    func onDatabaseChanged() {
        // Default: no-op
    }
    
    /// Default implementation that does nothing.
    /// Override this in your ViewModel if you need to handle scene updates.
    func onSceneUpdated(_ notification: Notification) {
        // Default: no-op
    }
    
    /// Default implementation that does nothing.
    /// Override this in your ViewModel if you need to handle performer updates.
    func onPerformerUpdated(_ notification: Notification) {
        // Default: no-op
    }
}
