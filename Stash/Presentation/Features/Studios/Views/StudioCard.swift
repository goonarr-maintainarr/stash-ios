import SwiftUI
import NukeUI

/// A card/grid item representing a Studio.
///
/// **Used by:** `StudioListView`
struct StudioCard: View {
    let studio: Studio
    
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            ZStack {
                if let url = settings.createImageUrl(path: studio.image_path) {
                   LazyImage(url: url) { state in
                       if let image = state.image {
                           image
                               .resizable()
                               .aspectRatio(contentMode: .fit)
                               .frame(maxWidth: .infinity, maxHeight: .infinity)
                       } else if state.error != nil {
                           Color.gray.opacity(0.5)
                       } else {
                           // Loading state with shimmer
                           Color.gray.opacity(0.5)
                               .shimmering()
                       }
                   }
                } else {
                    Color.gray.opacity(0.1)
                    Image(systemName: "building.2.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .frame(height: 100) // Fixed height for the image area
            .background(Color.white.opacity(0.05)) // Subtle background for transparent logos/loading
            .clipped()
            // Removed white background to support transparency
            .cornerRadius(8)
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(studio.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack {
                    if let scenes = studio.scene_count {
                        Label("\(scenes)", systemImage: "film")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if studio.favorite == true {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }

        .background(Color.stashCardBackground)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
