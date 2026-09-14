import SwiftUI

/// Actions that can be triggered from a PerformerCard.
struct PerformerCardActions {
    /// Called when user taps the performer (card or general info area).
    var onPerformerClick: (() -> Void)?
    
    /// Default empty actions - card will be non-interactive
    static let none = PerformerCardActions()
    
    /// Convenience initializer
    init(onPerformerClick: (() -> Void)? = nil) {
        self.onPerformerClick = onPerformerClick
    }
}
