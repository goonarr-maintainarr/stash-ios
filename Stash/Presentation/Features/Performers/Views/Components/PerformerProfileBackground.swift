import SwiftUI
import NukeUI

/// A reusable background view for performer profiles that shows a blurred version of their image.
/// The blurred background image behind the performer header.
///
/// **Used by:** `PerformerDetailView`
struct PerformerProfileBackground: View {
    let imageURL: URL?
    
    var body: some View {
        Group {
            if let imageURL = imageURL {
                LazyImage(url: imageURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
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
