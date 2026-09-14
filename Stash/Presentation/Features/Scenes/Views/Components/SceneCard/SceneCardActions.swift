import SwiftUI

/// Actions that can be triggered from a SceneCard.
/// This enables the "callback pattern" where the card is a pure presentation component
/// and the parent handles all navigation/action logic.
struct SceneCardActions {
    /// Called when user taps the scene (thumbnail or general info area).
    /// The optional Double is the scrubbed time in seconds, if user scrubbed before tapping.
    var onSceneClick: ((Double?) -> Void)?
    
    /// Called when user taps the studio name
    var onStudioClick: (() -> Void)?
    
    /// Called when user taps a performer name.
    /// The first String is the performer's local ID / StashDB ID, the second is the name.
    var onPerformerClick: ((String, String) -> Void)?
    
    /// Default empty actions - card will be non-interactive
    static let none = SceneCardActions()
    
    /// Convenience initializer
    init(
        onSceneClick: ((Double?) -> Void)? = nil,
        onStudioClick: (() -> Void)? = nil,
        onPerformerClick: ((String, String) -> Void)? = nil
    ) {
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
    }
}
