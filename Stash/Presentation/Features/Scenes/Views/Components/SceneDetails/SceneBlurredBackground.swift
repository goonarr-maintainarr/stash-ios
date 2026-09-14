import SwiftUI
import NukeUI

/// A reusable blurred background view for scene detail pages.
/// Displays the scene's image blurred with a dark overlay.
/// Blurred background image for scene details.
///
/// **Used by:** `SceneDetailView`
struct SceneBlurredBackground: View {
    let imageURL: URL?
    
    var body: some View {
        Group {
            if let url = imageURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 20)
                            .overlay(Color.black.opacity(0.7))
                    } else {
                        Color.stashBackground
                    }
                }
            } else {
                Color.stashBackground
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Modifier

extension View {
    /// Applies a blurred scene background from the given image URL.
    func sceneBlurredBackground(imageURL: URL?) -> some View {
        self.background(SceneBlurredBackground(imageURL: imageURL))
    }
    
    /// Applies a blurred scene background from a URL string.
    func sceneBlurredBackground(imageURLString: String?) -> some View {
        let url = imageURLString.flatMap { URL(string: $0) }
        return self.background(SceneBlurredBackground(imageURL: url))
    }
}
