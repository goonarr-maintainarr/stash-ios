import SwiftUI
import NukeUI

/// A screen for reviewing and applying scraped metadata results.
///
/// **Navigated from:** `SceneDetailView` (via Scrape Dialog)
struct ScrapeResultReviewView: View {
    let result: ScrapedScene
    let currentScene: Scene
    var viewModel: SceneDetailViewModel
    @Binding var sheetDetent: PresentationDetent
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var useTitle = false
    @State private var useDetails = false
    @State private var usePerformers = false
    @State private var useTags = false
    @State private var isApplying = false
    @State private var useScrapedImage = false
    @State private var useStudio = false
    @State private var useDirector = false
    @State private var useCode = false
    @State private var useUrl = false
    @State private var missingPerformers: Set<String> = []
    @State private var workingTags: [ScrapedTag] = []
    
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                ScrapeReviewImagesView(
                    result: result,
                    currentScene: currentScene,
                    useScrapedImage: $useScrapedImage
                )
                
                ScrapeReviewDetailsView(
                    result: result,
                    currentScene: currentScene,
                    useTitle: $useTitle,
                    useDetails: $useDetails,
                    useTags: $useTags,
                    useStudio: $useStudio,
                    useDirector: $useDirector,
                    useCode: $useCode,
                    useUrl: $useUrl,
                    workingTags: $workingTags
                )
                
                ScrapeReviewPerformersView(
                    result: result,
                    currentScene: currentScene,
                    usePerformers: $usePerformers,
                    missingPerformers: $missingPerformers,
                    viewModel: viewModel
                )
                
            }
            .padding()
        }
        .background(Color.stashBackground)
        .scrollContentBackground(.hidden)
        .navigationTitle("Review Changes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    Task {
                        isApplying = true
                        await viewModel.applyScrapeResult(
                            result, 
                            useTitle: useTitle,
                            useDetails: useDetails,
                            usePerformers: usePerformers,
                            useTags: useTags,
                            useImage: useScrapedImage,
                            useStudio: useStudio,
                            useDirector: useDirector,
                            useCode: useCode,
                            useUrl: useUrl,
                            customTags: workingTags
                        )
                        isApplying = false
                        onComplete()
                    }
                }) {
                    if isApplying {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(isApplying)
            }
        }
        .onAppear {
            sheetDetent = .large
            
            // Auto-select fields if they have data
            if result.title != nil { useTitle = true }
            if result.details != nil { useDetails = true }
            if let tags = result.tags, !tags.isEmpty { useTags = true }
            if result.studio != nil { useStudio = true }
            if result.director != nil { useDirector = true }
            if result.code != nil { useCode = true }
            if result.url != nil || (result.urls?.isEmpty == false) { useUrl = true }
            if result.image != nil { useScrapedImage = true }
            if let performers = result.performers, !performers.isEmpty { usePerformers = true }
        }
        .task {
            if let performers = result.performers {
                missingPerformers = await viewModel.validateScrapedPerformers(performers)
            }
            if let tags = result.tags {
                workingTags = tags
            }
        }
    }
}
