import SwiftUI
import NukeUI

/// A circular avatar thumbnail for performer lists/headers.
///
/// **Used by:**
/// - `PerformerCard`
/// - `SceneDetailView` (Performer list)
struct PerformerThumbnail: View {
    let imagePath: String?
    let name: String
    let settings: SettingsStore
    var size: CGFloat = 60
    
    @State private var heroColor: Color?
    
    var body: some View {
        Group {
            if let imagePath = imagePath,
               let url = settings.createImageUrl(path: imagePath) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size, alignment: .top)
                            .clipped()
                    } else {
                        placeholderView
                    }
                }
                .task {
                    await extractHeroColor(from: url)
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(8)
        .shadow(color: (heroColor ?? .black).opacity(heroColor != nil ? 0.4 : 0.15), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(heroColor?.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
        .padding(4) // Give shadow room to render
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            )
    }
    
    private func extractHeroColor(from url: URL) async {
        guard heroColor == nil else { return }
        
        if let color = await HeroAccentColor.extract(from: url) {
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) {
                    self.heroColor = color
                }
            }
        }
    }
}
