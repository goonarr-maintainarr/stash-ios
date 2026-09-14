import SwiftUI
import NukeUI

/// The "Add to Whisparr" screen for a specific search result.
///
/// **Navigated from:** `WhisparrSearchView` -> Result Tap
struct WhisparrSearchResultDetailView: View {
    @State private var viewModel: WhisparrSearchResultDetailViewModel
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dependencyContainer: DependencyContainer // Inject dependency container
    
    // Performer state (redundant in VM but View uses loop for UI)
    // Actually the VM exposes performerDetails and localPerformerIds which the VIEW iterates over via femalePerformers (vm.femalePerformers)
    
    private let whisparrPink = Color(red: 0.91, green: 0.33, blue: 0.65)
    var onPerformerClick: ((String, String) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    
    init(
        viewModel: WhisparrSearchResultDetailViewModel,
         onPerformerClick: ((String, String) -> Void)? = nil,
         onStudioClick: ((Studio) -> Void)? = nil
    ) {
         _viewModel = State(wrappedValue: viewModel)
         self.onPerformerClick = onPerformerClick
         self.onStudioClick = onStudioClick
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sceneImageSection
                titleMetadataSection
                
                // Show search buttons if movie has been added
                if let movie = viewModel.addedMovie {
                    searchButtonsSection(for: movie)
                } else {
                    addToWhisparrButton
                }
                
                if !viewModel.femalePerformers.isEmpty {
                    performersSection
                }
            }
        }
        .sceneBlurredBackground(imageURLString: viewModel.searchResult.imageUrl)
        .navigationTitle("Scene Details")
        .navigationBarTitleDisplayMode(.inline)
        .toast(isShowing: viewModel.showSuccessToast, message: viewModel.addedMovie != nil ? "Search Queued" : "Added to Whisparr")
        .sheet(isPresented: $viewModel.showReleasesSheet) {
            if let movie = viewModel.addedMovie {
                WhisparrReleasesView(movieId: movie.id, movieTitle: movie.title, runtime: Double(movie.runtime) * 60)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.showErrorAlert)) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.loadWhisparrSettings()
            await viewModel.loadPerformerDetails()
            await viewModel.checkLocalPerformers()
        }
    }
    
    @ViewBuilder
    private var sceneImageSection: some View {
        WhisparrSearchResultHeroImage(
            searchResult: viewModel.searchResult,
            blurNsfw: settingsStore.blurNsfw
        )
    }
    
    @ViewBuilder
    private var titleMetadataSection: some View {
        WhisparrSearchResultHeader(result: viewModel.searchResult, onStudioClick: {
            Task {
                if let studio = await viewModel.resolveLocalStudio(
                    studioForeignId: nil,
                    studioTitle: viewModel.searchResult.studioTitle
                ) {
                    onStudioClick?(studio)
                }
            }
        })
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var addToWhisparrButton: some View {
        AddToWhisparrButton(
            isLoading: viewModel.isAddingToWhisparr,
            isDisabled: viewModel.showSuccessToast,
            action: viewModel.addToWhisparr
        )
    }
    
    @ViewBuilder
    private func searchButtonsSection(for movie: WhisparrScene) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Automatic Search Button
                Button {
                    HapticManager.mediumImpact()
                    Task {
                        if await viewModel.performAutomaticSearch(for: movie) {
                             HapticManager.success()
                        } else {
                             HapticManager.error()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Automatic")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(whisparrPink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isSearching)
                .shadow(color: whisparrPink.opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Interactive Search Button
                Button {
                    HapticManager.mediumImpact()
                    viewModel.showReleasesSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Interactive")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(whisparrPink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .shadow(color: whisparrPink.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var performersSection: some View {
        PerformersSection(
            credits: viewModel.femalePerformers,
            localPerformerIds: viewModel.localPerformerIds,
            performerDetails: viewModel.performerDetails,
            localPerformerOCounts: viewModel.localPerformerOCounts,
            localPerformerSceneCounts: viewModel.localPerformerSceneCounts,
            localImagePaths: viewModel.localImagePaths,
            onPerformerClick: onPerformerClick
        )
    }
    
}
