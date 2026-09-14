import Foundation

public struct SceneMarker: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let seconds: Double
    public let stream: String?
    public let preview: String?

    // Explicit init to match GraphQL schema
    public init(
        id: String,
        title: String,
        seconds: Double,
        stream: String? = nil,
        preview: String? = nil
    ) {
        self.id = id
        self.title = title
        self.seconds = seconds
        self.stream = stream
        self.preview = preview
    }
}

