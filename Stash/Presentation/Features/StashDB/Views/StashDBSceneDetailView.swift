import SwiftUI
import Nuke

/// StashDB-specific Scene Detail View.
///
/// **Navigated from:** Search Results
struct StashDBSceneDetailView: View {
    @State private var viewModel: StashDBSceneDetailViewModel
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @State private var heroColor: Color?
    var onPerformerClick: ((String, String) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    
    private var tagColor: Color {
        heroColor ?? .blue
    }
    
    init(viewModel: StashDBSceneDetailViewModel, onPerformerClick: ((String, String) -> Void)? = nil, onStudioClick: ((Studio) -> Void)? = nil) {
        _viewModel = State(wrappedValue: viewModel)
        self.onPerformerClick = onPerformerClick
        self.onStudioClick = onStudioClick
    }
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .content(let scene):
                sceneContent(scene)
            case .error(let message):
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
            case .empty:
                ContentUnavailableView("No Data", systemImage: "doc.text.magnifyingglass")
            }
        }
        .sceneBlurredBackground(imageURLString: viewModel.scene?.images?.first?.url)
        .toast(isShowing: viewModel.showSuccessMessage, message: "Added to Whisparr")
        .navigationTitle("Scene Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Fetch full details if we only have overview fields
            await viewModel.fetchFullDetails()
            await viewModel.loadPerformerDetails()
            await viewModel.checkLocalPerformers()
        }
    }
    
    @ViewBuilder
    private func sceneContent(_ scene: StashDBScene) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Scene image with rounded corners and shadow
                SceneHeroImage(
                    imageURLString: scene.images?.first?.url,
                    blurNsfw: settingsStore.blurNsfw
                )
                .task {
                    if let urlString = scene.images?.first?.url,
                       let url = URL(string: urlString) {
                        await extractHeroColor(from: url)
                    }
                }
                
                // Title, metadata, and description
                StashDBSceneHeader(scene: scene, onStudioClick: {
                    if let studio = scene.studio {
                        onStudioClick?(Studio(id: studio.id, name: studio.name))
                    }
                })
                    .padding(.horizontal)
                
                // Add to Whisparr button
                AddToWhisparrButton(
                    isLoading: viewModel.isAddingToWhisparr,
                    isDisabled: viewModel.showSuccessMessage,
                    action: viewModel.addToWhisparr
                )
                
                // Error message if add fails
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                
                // Tags in scrolling pills
                if let tags = scene.tags, !tags.isEmpty {
                    TagsSection(tags: tags, heroColor: tagColor)
                }
                
                // Performers with full images (female only)
                PerformersSection(
                    appearances: viewModel.femalePerformers,
                    localPerformerIds: viewModel.localPerformerIds,
                    performerDetails: viewModel.performerDetails,
                    localPerformerOCounts: viewModel.localPerformerOCounts,
                    localPerformerSceneCounts: viewModel.localPerformerSceneCounts,
                    localImagePaths: viewModel.localImagePaths,
                    onPerformerClick: onPerformerClick
                )
            }
            .padding(.bottom, 24)
        }
    }

    
    private func extractHeroColor(from url: URL) async {
        guard heroColor == nil else { return }
        
        if let color = await HeroAccentColor.extract(from: url) {
            self.heroColor = color
        }
    }
}
