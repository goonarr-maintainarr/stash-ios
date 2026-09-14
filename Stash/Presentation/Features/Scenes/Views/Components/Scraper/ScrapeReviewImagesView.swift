import SwiftUI
import NukeUI

struct ScrapeReviewImagesView: View {
    let result: ScrapedScene
    let currentScene: Scene
    @Binding var useScrapedImage: Bool
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Images")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                // Current Image Option
                SelectionRow(
                    title: "Current",
                    isSelected: !useScrapedImage,
                    action: { useScrapedImage = false }
                ) {
                    if let currentUrl = settings.createImageUrl(path: currentScene.paths?.screenshot) {
                         LazyImage(url: currentUrl) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Rectangle().fill(Color.black.opacity(0.3))
                            }
                         }
                         .frame(height: 200)
                         .cornerRadius(8)
                    } else {
                        Rectangle().fill(Color.black.opacity(0.3))
                            .frame(height: 150)
                            .cornerRadius(8)
                            .overlay(Text("No Image").font(.caption).foregroundColor(.secondary))
                    }
                }
                
                // Scraped Image Option
                if let imageString = result.image {
                    Divider()
                    SelectionRow(
                        title: "Scraped",
                        isSelected: useScrapedImage,
                        action: { useScrapedImage = true }
                    ) {
                        Group {
                            if imageString.hasPrefix("http"), let url = URL(string: imageString) {
                                LazyImage(url: url) { state in
                                    if let image = state.image {
                                        image.resizable().aspectRatio(contentMode: .fit)
                                    } else {
                                        Rectangle().fill(Color.black.opacity(0.3))
                                    }
                                }
                            } else {
                                // Try Base64
                                let base64String = imageString.components(separatedBy: ",").last ?? imageString
                                if let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Rectangle().fill(Color.black.opacity(0.3))
                                }
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.stashCardBackground)
            .cornerRadius(10)
        }
    }
}
