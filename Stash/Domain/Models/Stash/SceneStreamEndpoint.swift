import Foundation

/// Represents a streaming endpoint for a scene.
/// Returned by the `sceneStreams` query.
struct SceneStreamEndpoint: Codable, Equatable, Identifiable, Sendable {
    let url: String
    let label: String?
    let mimeType: String?
    
    var id: String { url }
    
    /// Human-readable display name for the stream
    var displayLabel: String {
        label ?? mimeType ?? "Stream"
    }
    
    enum CodingKeys: String, CodingKey {
        case url
        case label
        case mimeType = "mime_type"
    }
}
