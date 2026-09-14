import SwiftUI
import NukeUI


/// A reusable hero image view for scene detail pages.
/// Displays the scene's image with rounded corners, shadow, and optional NSFW blur.
///
/// **Used by:** `SceneDetailView`
struct SceneHeroImage<OverlayContent: View>: View {
    let imageURL: URL?
    let blurNsfw: Bool
    let height: CGFloat
    
    @ViewBuilder let overlayContent: () -> OverlayContent
    
    var body: some View {
        if let url = imageURL {
            ZStack(alignment: .bottom) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width - 16, height: height)
                            .clipped()
                            .blur(radius: blurNsfw ? 20 : 0)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: height)
                    }
                }
                
                overlayContent()
            }
            .frame(height: height)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Convenience Initializers

extension SceneHeroImage where OverlayContent == EmptyView {
    /// Basic initializer without overlay
    init(imageURL: URL?, blurNsfw: Bool, height: CGFloat = 300) {
        self.imageURL = imageURL
        self.blurNsfw = blurNsfw
        self.height = height
        self.overlayContent = { EmptyView() }
    }
    
    /// Initialize with URL string
    init(imageURLString: String?, blurNsfw: Bool, height: CGFloat = 300) {
        self.imageURL = imageURLString.flatMap { URL(string: $0) }
        self.blurNsfw = blurNsfw
        self.height = height
        self.overlayContent = { EmptyView() }
    }
}

// MARK: - Factory Functions

/// Creates a scene hero image for a StashDB scene
func StashDBSceneHeroImage(
    scene: StashDBScene,
    blurNsfw: Bool,
    onImageLoad: ((URL) -> Void)? = nil
) -> some View {
    var url: URL?
    if let urlString = scene.images?.first?.url {
        url = URL(string: urlString)
    }
    
    return SceneHeroImage(imageURL: url, blurNsfw: blurNsfw)
        .onAppear {
            if let url = url {
                onImageLoad?(url)
            }
        }
}

/// Creates a scene hero image for a Whisparr scene with status bar
func WhisparrSceneHeroImage(scene: WhisparrScene, blurNsfw: Bool, qualityProfileName: String? = nil) -> some View {
    let url = scene.imageUrl.flatMap { URL(string: $0) }
    
    return SceneHeroImage(imageURL: url, blurNsfw: blurNsfw, height: 300) {
        // Status Bar with Text
        HStack {
            Text(statusText(for: scene).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            Spacer()
            if let qualityProfile = qualityProfileName {
                Text(qualityProfile)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
        .background(statusColor(for: scene))
        .frame(maxWidth: .infinity)
    }
}

/// Creates a scene hero image for a Whisparr search result
func WhisparrSearchResultHeroImage(
    searchResult: WhisparrSearchResult,
    blurNsfw: Bool
) -> some View {
    let url = searchResult.imageUrl.flatMap { URL(string: $0) }
    return SceneHeroImage(imageURL: url, blurNsfw: blurNsfw)
}

// MARK: - Helpers

private func statusColor(for scene: WhisparrScene) -> Color {
    if scene.hasFile { return .green }
    if scene.monitored { return .yellow }
    return .red
}

private func statusText(for scene: WhisparrScene) -> String {
    if scene.hasFile { return "Downloaded" }
    if scene.monitored { return "Monitored (Missing)" }
    return "Not Monitored (Missing)"
}
