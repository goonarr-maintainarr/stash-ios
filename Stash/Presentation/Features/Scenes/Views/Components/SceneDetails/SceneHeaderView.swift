import SwiftUI

/// A unified, composable header view for scene detail pages.
/// Displays the title section and allows for optional accessory views (rating, path, etc.)
///
/// **Used by:** `SceneDetailView`
struct SceneHeaderView<AccessoryContent: View>: View {
    let title: String
    var studio: String?
    var date: String?
    var runtime: String?
    var description: String?
    var onStudioClick: (() -> Void)?
    
    @ViewBuilder let accessoryContent: () -> AccessoryContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title, Studio, Date, Runtime
            SceneTitleSection(
                title: title,
                studio: studio,
                date: date,
                runtime: runtime,
                onStudioClick: onStudioClick
            )
            
            // Optional accessory content (rating, O-counter, path, etc.)
            accessoryContent()
            
            // Description
            if let description = description, !description.isEmpty {
                SceneDescriptionSection(text: description)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension SceneHeaderView where AccessoryContent == EmptyView {
    /// Basic initializer with no accessory content
    init(
        title: String,
        studio: String? = nil,
        date: String? = nil,
        runtime: String? = nil,
        description: String? = nil,
        onStudioClick: (() -> Void)? = nil
    ) {
        self.title = title
        self.studio = studio
        self.date = date
        self.runtime = runtime
        self.description = description
        self.onStudioClick = onStudioClick
        self.accessoryContent = { EmptyView() }
    }
}

// MARK: - Factory Functions

/// Creates a SceneHeaderView for a local Scene with rating/O-counter accessory
func LocalSceneHeader(
    scene: Scene,
    viewModel: SceneDetailViewModel,
    onStudioClick: (() -> Void)? = nil
) -> some View {
    SceneHeaderView(
        title: scene.title ?? "Untitled",
        studio: scene.studio?.name,
        date: scene.date.map { DateFormatters.formatDateString($0) },
        runtime: formatSceneRuntime(seconds: scene.files?.first?.duration),
        description: scene.details,
        onStudioClick: onStudioClick
    ) {
        HStack {
            StarRatingView(rating: scene.rating100, interactive: true) { newRating in
                HapticManager.lightImpact()
                Task {
                    await viewModel.updateRating(newRating)
                }
            }
            Spacer()
            
            Button(action: {
                HapticManager.success()
                Task {
                    await viewModel.incrementOCounter()
                }
            }) {
                HStack(spacing: 6) {
                    Image("SweatDrops")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    
                    Text("\(scene.o_counter ?? 0)")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.top, 4)
    }
}

/// Creates a SceneHeaderView for a StashDB Scene (no accessory content)
func StashDBSceneHeader(scene: StashDBScene, onStudioClick: (() -> Void)? = nil) -> some View {
    SceneHeaderView(
        title: scene.title ?? "Untitled",
        studio: scene.studio?.name,
        date: scene.date.map { DateFormatters.formatDateString($0) },
        runtime: formatSceneRuntime(seconds: scene.duration),
        description: scene.details,
        onStudioClick: onStudioClick
    )
}

/// Creates a SceneHeaderView for a Whisparr Scene with path display
func WhisparrSceneHeader(scene: WhisparrScene, onStudioClick: (() -> Void)? = nil) -> some View {
    SceneHeaderView(
        title: scene.title,
        studio: scene.studioTitle,
        date: "Added: \(DateFormatters.formatDate(scene.added))",
        runtime: nil,
        description: scene.overview,
        onStudioClick: onStudioClick
    ) {
        if let path = scene.path {
            VStack(alignment: .leading, spacing: 12) {
                Text("Path")
                    .font(.headline)
                
                Text(path)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.stashCardBackground)
                    .cornerRadius(12)
            }
        }
    }
}

/// Creates a SceneHeaderView for a Whisparr Search Result
func WhisparrSearchResultHeader(result: WhisparrSearchResult, onStudioClick: (() -> Void)? = nil) -> some View {
    SceneHeaderView(
        title: result.title,
        studio: result.studioTitle,
        date: result.releaseDate.map { DateFormatters.formatDate($0) } ?? "\(result.year)",
        runtime: formatSceneRuntime(seconds: Double(result.runtime) * 60),
        description: result.overview,
        onStudioClick: onStudioClick
    )
}

// MARK: - Helpers

private func formatSceneRuntime(seconds: Double?) -> String? {
    guard let seconds = seconds else { return nil }
    return formatSceneRuntime(seconds: Int(seconds))
}

private func formatSceneRuntime(seconds: Int?) -> String? {
    guard let seconds = seconds else { return nil }
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainingSeconds = seconds % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    } else {
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
