import SwiftUI

/// A wrapper around `NukeUI.LazyImage` that provides consistent caching, transition animations, and error handling.
///
/// **Used by:**
/// - `SceneCard`, `PerformerCard` (Lists)
/// - `SceneDetailView`, `PerformerDetailView` (Headers)
/// - `StudioGridItem`
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        // Reset state if needed (though .task(id:) handles identity changes)
        if image != nil && self.url != url {
            image = nil
        }
        
        isLoading = true
        
        let imageCache = dependencyContainer.imageCache
        
        // Check cache - disk I/O is now handled async inside image(for:)
        if let cachedImage = await imageCache.image(for: url) {
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
            }
            return
        }
        
        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                imageCache.insert(downloadedImage, for: url)
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
