import SwiftUI
import Combine
import os

/// Displays scenes associated with a StashDB Performer.
///
/// **Part of:** `StashDBPerformerDetailView`
/// This wrapper ensures backward compatibility if used elsewhere as a standalone view (though primarily used embedded now).
struct StashDBPerformerScenesView: View {
    @State private var viewModel: StashDBPerformerScenesViewModel
    let performerName: String
    
    // Navigation callbacks
    let onSceneClick: (StashDBScene) -> Void
    let onStudioClick: (Studio) -> Void
    let onPerformerClick: (String, String) -> Void
    
    init(
        performerName: String,
        viewModel: StashDBPerformerScenesViewModel,
        onSceneClick: @escaping (StashDBScene) -> Void,
        onStudioClick: @escaping (Studio) -> Void,
        onPerformerClick: @escaping (String, String) -> Void
    ) {
        self.performerName = performerName
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
        _viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            StashDBPerformerScenesContentView(
                viewModel: viewModel,
                onSceneClick: onSceneClick,
                onStudioClick: onStudioClick,
                onPerformerClick: onPerformerClick
            )
        }
        .background(Color.stashBackground)
        .navigationTitle("\(performerName) on StashDB")
        .task {
            if viewModel.scenes.isEmpty {
                await viewModel.loadScenes()
            }
        }
    }
}

/// The content view for StashDB scenes, designed to be embedded in other scroll views.
struct StashDBPerformerScenesContentView: View {
    let viewModel: StashDBPerformerScenesViewModel
    
    // Navigation callbacks
    let onSceneClick: (StashDBScene) -> Void
    let onStudioClick: (Studio) -> Void
    let onPerformerClick: (String, String) -> Void
    
    var body: some View {
        LazyVStack(spacing: 16) {
            if viewModel.allScenesOwned {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("You have all the most recent scenes!")
                        .font(.headline)
                    Text("All available scenes from StashDB are already in your collection.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.stashCardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            } else if viewModel.state == .loading || !viewModel.scenes.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.excludingOwned ? "Scenes not in Stash" : "All Scenes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if viewModel.excludingVR || viewModel.excludingCompilations {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.caption2)
                                Text("Excluding: " +
                                     [viewModel.excludingVR ? "VR" : nil,
                                      viewModel.excludingCompilations ? "Compilations" : nil]
                                        .compactMap { $0 }
                                        .joined(separator: ", ")
                                )
                                .font(.caption2)
                            }
                            .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                    Spacer()
                    if viewModel.totalFilteredCount > 0 {
                        Text("\(viewModel.totalFilteredCount)")
                            .font(.headline)
                    } else {
                        SkeletonView(height: 18)
                            .frame(width: 32)
                    }
                }
                .padding()
                .background(Color.stashCardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            if case .loading = viewModel.state, viewModel.scenes.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    SceneCardSkeleton()
                }
            }
            
            if !viewModel.allScenesOwned {
                ForEach(viewModel.scenes) { scene in
                    SceneCard(
                        stashDBScene: scene,
                        actions: SceneCardActions(
                            onSceneClick: { _ in onSceneClick(scene) },
                            onStudioClick: {
                                if let studio = scene.studio {
                                    onStudioClick(Studio(id: studio.id, name: studio.name))
                                }
                            },
                            onPerformerClick: { id, name in onPerformerClick(id, name) }
                        )
                    )
                    .task {
                        // Load more when reaching the last item
                        if scene.id == viewModel.scenes.last?.id && viewModel.hasMore {
                            viewModel.loadNextPage()
                        }
                    }
                }
            }
                
            if case .loading = viewModel.state, !viewModel.scenes.isEmpty {
                SceneCardSkeleton()
            }

        }
        .padding(.horizontal, 8)
        .padding(.vertical)
        .alert("Error", isPresented: Binding(
            get: {
                if case .error = viewModel.state { return true }
                return false
            },
            set: { _ in viewModel.clearError() }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if case .error(let message) = viewModel.state {
                Text(message)
            }
        }
    }
}
