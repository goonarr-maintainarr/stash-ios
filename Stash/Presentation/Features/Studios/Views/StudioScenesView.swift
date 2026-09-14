import SwiftUI

struct StudioScenesView: View {
    @State private var viewModel: StudioScenesViewModel
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    var onSceneClick: ((Scene) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    var onPerformerClick: ((String, String) -> Void)?
    
    init(viewModel: StudioScenesViewModel,
         onSceneClick: ((Scene) -> Void)? = nil,
         onStudioClick: ((Studio) -> Void)? = nil,
         onPerformerClick: ((String, String) -> Void)? = nil) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
    }
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .loading, .idle:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                
            case .empty:
                ContentUnavailableView(
                    "No Scenes Found",
                    systemImage: "film",
                    description: Text("This studio has no scenes.")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
                
            case .error(let message):
                ContentUnavailableView(
                    "Error Loading Scenes",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                
            case .content(let scenes):
                LazyVStack(spacing: 16) {
                    ForEach(scenes) { scene in
                        SceneCard(
                            scene: scene,
                            actions: SceneCardActions(
                                onSceneClick: { scrubTime in
                                    let navScene = scrubTime.map { scene.withResumeTime($0) } ?? scene
                                    onSceneClick?(navScene)
                                },
                                onStudioClick: {
                                    if let studio = scene.studio {
                                        onStudioClick?(Studio(id: studio.id, name: studio.name))
                                    }
                                },
                                onPerformerClick: { id, name in
                                    onPerformerClick?(id, name)
                                }
                            )
                        )
                        .onAppear {
                            if scene == scenes.last {
                                Task { await viewModel.loadMore() }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 0) // Full width typically implies 0 horizontal padding in list views, but SceneCard handles its own internal layout. SceneListView uses horizontal padding 8 for lists usually.
                .padding(.vertical)
            }
        }
        .task {
            await viewModel.loadScenes()
        }
    }
}
