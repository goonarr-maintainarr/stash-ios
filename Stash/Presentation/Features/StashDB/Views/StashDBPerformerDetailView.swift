import SwiftUI

/// StashDB-specific Performer Detail View.
///
/// **Navigated from:** Search Results
struct StashDBPerformerDetailView: View {
    @State private var viewModel: StashDBPerformerDetailViewModel
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    // Callbacks for navigation (hoisted to parent)
    let onSceneClick: ((StashDBScene) -> Void)?
    let onStudioClick: ((Studio) -> Void)?
    let onPerformerClick: ((String, String) -> Void)?
    let onViewScenesClick: (() -> Void)?
    
    @State private var scenesViewModel: StashDBPerformerScenesViewModel?
    
    init(
        viewModel: StashDBPerformerDetailViewModel,
        onSceneClick: ((StashDBScene) -> Void)? = nil,
        onStudioClick: ((Studio) -> Void)? = nil,
        onPerformerClick: ((String, String) -> Void)? = nil,
        onViewScenesClick: (() -> Void)? = nil
    ) {
        // Initialize ViewModel with the provided performer (stub or full)
        _viewModel = State(wrappedValue: viewModel)
        
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
        self.onViewScenesClick = onViewScenesClick
    }
    
    var body: some View {
        ZStack {
            PerformerDetailContentView(
                performer: PerformerDetailDisplay(stashPerformer: viewModel.performer),
                scenesView: {
                    if let scenesVM = scenesViewModel {
                        StashDBPerformerScenesContentView(
                            viewModel: scenesVM,
                            onSceneClick: { scene in onSceneClick?(scene) },
                            onStudioClick: { studio in onStudioClick?(studio) },
                            onPerformerClick: { id, name in onPerformerClick?(id, name) }
                        )
                    } else {
                        // Placeholder loading state while VM inits
                        ProgressView()
                            .padding()
                    }
                }
            )
            .opacity(viewModel.isLoading ? 0.3 : 1.0)
            .task {
                if scenesViewModel == nil {
                    scenesViewModel = dependencyContainer.makeStashDBPerformerScenesViewModel(performerId: viewModel.performer.id)
                }
                await scenesViewModel?.loadScenes()
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            if let error = viewModel.errorMessage {
                VStack {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Button("Retry") {
                        Task { await viewModel.loadDetails() }
                    }
                    .buttonStyle(.bordered)
                }
                .background(Color.stashBackground.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .navigationTitle(viewModel.performer.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
