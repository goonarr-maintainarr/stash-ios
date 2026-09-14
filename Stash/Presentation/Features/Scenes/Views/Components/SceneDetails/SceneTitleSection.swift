import SwiftUI

/// A reusable title section for scene detail views.
/// Displays: Title, then Studio • Date • Runtime
/// The header section of the Scene Detail view (Title, Studio, Date).
///
/// **Used by:** `SceneDetailView`
struct SceneTitleSection: View {
    let title: String
    var studio: String?
    var date: String?
    var runtime: String?
    var onStudioClick: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 0) {
                if let studio = studio {
                    Button(action: {
                        onStudioClick?()
                    }) {
                        Text(studio)
                            .font(.headline)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
                
                if let date = date {
                    if studio != nil {
                        Text(" • ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let runtime = runtime {
                    if date != nil || studio != nil {
                        Text(" • ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(runtime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    /// Formats seconds into MM:SS or HH:MM:SS format
    private static func formatRuntime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    
    /// Formats seconds (Double) into MM:SS or HH:MM:SS format
    private static func formatRuntime(seconds: Double) -> String {
        formatRuntime(seconds: Int(seconds))
    }
}

// MARK: - Convenience Initializers

extension SceneTitleSection {
    /// Initialize from a local Scene
    init(scene: Scene) {
        self.title = scene.title ?? "Untitled"
        self.studio = scene.studio?.name
        self.date = scene.date.map { DateFormatters.formatDateString($0) }
        
        if let duration = scene.files?.first?.duration {
            self.runtime = SceneTitleSection.formatRuntime(seconds: duration)
        } else {
            self.runtime = nil
        }
    }
    
    /// Initialize from a StashDB Scene
    init(stashDBScene: StashDBScene) {
        self.title = stashDBScene.title ?? "Untitled"
        self.studio = stashDBScene.studio?.name
        self.date = stashDBScene.date.map { DateFormatters.formatDateString($0) }
        
        if let duration = stashDBScene.duration {
            self.runtime = SceneTitleSection.formatRuntime(seconds: duration)
        } else {
            self.runtime = nil
        }
    }
    
    /// Initialize from a Whisparr Scene
    init(whisparrScene: WhisparrScene) {
        self.title = whisparrScene.title
        self.studio = whisparrScene.studioTitle
        self.date = "Added: \(DateFormatters.formatDate(whisparrScene.added))"
        self.runtime = nil // Runtime shown in file info section
    }
    
    /// Initialize from a Whisparr Search Result
    init(searchResult: WhisparrSearchResult) {
        self.title = searchResult.title
        self.studio = searchResult.studioTitle
        
        if let releaseDate = searchResult.releaseDate {
            self.date = DateFormatters.formatDate(releaseDate)
        } else {
            self.date = "\(searchResult.year)"
        }
        
        // Runtime in minutes, convert to seconds for formatting
        self.runtime = SceneTitleSection.formatRuntime(seconds: searchResult.runtime * 60)
    }
}
