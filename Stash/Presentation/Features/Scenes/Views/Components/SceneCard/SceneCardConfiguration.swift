import SwiftUI

struct SceneCardConfiguration {
    let title: String
    let imageUrl: URL?
    let videoPreviewUrl: URL?
    let spriteUrl: URL?
    let vttUrl: URL?
    let date: String?
    let studio: String?
    let runtime: String?
    let performers: [SceneCardPerformer]
    let statusColor: Color?
    let statusText: String? // Text to display on colored status bar (e.g., quality profile)
    let indicators: [SceneCardIndicator]
    let isMonitored: Bool?
    let addedDate: String?
    let resumeTime: Double?
    let duration: Double?
    let description: String?
    let tags: [String] // Simple list of tag names for display
    let showDescription: Bool // Whether to show the description (default true)
    
    // Default init for manual creating
    internal init(
        title: String,
        imageUrl: URL?,
        videoPreviewUrl: URL?,
        spriteUrl: URL?,
        vttUrl: URL?,
        date: String?,
        studio: String?,
        runtime: String?,
        performers: [SceneCardPerformer],
        statusColor: Color?,
        statusText: String?,
        indicators: [SceneCardIndicator],
        isMonitored: Bool?,
        addedDate: String?,
        resumeTime: Double?,
        duration: Double?,
        description: String?,
        tags: [String],
        showDescription: Bool = true
    ) {
        self.title = title
        self.imageUrl = imageUrl
        self.videoPreviewUrl = videoPreviewUrl
        self.spriteUrl = spriteUrl
        self.vttUrl = vttUrl
        self.date = date
        self.studio = studio
        self.runtime = runtime
        self.performers = performers
        self.statusColor = statusColor
        self.statusText = statusText
        self.indicators = indicators
        self.isMonitored = isMonitored
        self.addedDate = addedDate
        self.resumeTime = resumeTime
        self.duration = duration
        self.description = description
        self.tags = tags
        self.showDescription = showDescription
    }
    
    struct SceneCardPerformer: Identifiable {
        let id: String
        let name: String
        let localId: String? // If present, navigation link is created
        let imageUrl: URL?
    }
    
    struct SceneCardIndicator: Identifiable {
        let id: UUID = UUID()
        let icon: String?
        let customIcon: String?
        let text: String
        let color: Color
        
        init(icon: String? = nil, customIcon: String? = nil, text: String, color: Color) {
            self.icon = icon
            self.customIcon = customIcon
            self.text = text
            self.color = color
        }
    }
}
