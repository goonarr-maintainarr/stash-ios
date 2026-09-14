import Foundation

/// A protocol for types that can be displayed as tags in the UI.
/// Both local `Tag` and `StashDBTag` conform to this protocol.
protocol TagDisplayable: Identifiable {
    var id: String { get }
    var name: String { get }
}

// Conformance for local Tag (already Identifiable)
extension Tag: TagDisplayable {}

// Conformance for StashDB Tag
extension StashDBTag: Identifiable {}
extension StashDBTag: TagDisplayable {}
