import os
import SwiftUI
import NukeUI
import Nuke




private let logger = Logger(subsystem: "com.stash.app", category: "PerformerDetailView")

/// The main detail screen for a Performer.
///
/// **Navigated from:**
/// - `PerformerListView`
/// - `SceneDetailView` (Performer Link)
struct PerformerDetailView: View {
    let performerId: String
    @State private var viewModel: PerformerDetailViewModel
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    
    var onSceneClick: ((Scene) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    var onPerformerClick: ((String, String) -> Void)?
    var onStashDBSceneClick: ((StashDBScene) -> Void)?
    var onStashDBPerformerClick: ((StashDBPerformer) -> Void)?
    var onViewStashDB: ((String, String) -> Void)?
    
    init(
        performerId: String,
        viewModel: PerformerDetailViewModel,
        onSceneClick: ((Scene) -> Void)? = nil,
        onStudioClick: ((Studio) -> Void)? = nil,
        onPerformerClick: ((String, String) -> Void)? = nil,
        onStashDBSceneClick: ((StashDBScene) -> Void)? = nil,
        onStashDBPerformerClick: ((StashDBPerformer) -> Void)? = nil,
        onViewStashDB: ((String, String) -> Void)? = nil
    ) {
        self.performerId = performerId
        _viewModel = State(wrappedValue: viewModel)
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
        self.onStashDBSceneClick = onStashDBSceneClick
        self.onStashDBPerformerClick = onStashDBPerformerClick
        self.onViewStashDB = onViewStashDB
    }
    
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    
    @State private var isDeleting = false
    @State private var heroColor: Color?
    
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .content(let performer, let scenes):
                let stashDBId = performer.stash_ids?.first(where: { $0.endpoint.contains("stashdb.org") })?.stash_id
                
                PerformerDetailContentView(
                    performer: PerformerDetailDisplay(
                        performer: performer,
                        imageURL: settings.createImageUrl(path: performer.image_path)
                    ),
                    onEdit: { showEditSheet = true },
                    onDelete: { showDeleteConfirmation = true },
                    onLookupStashDB: stashDBId != nil ? {
                        if let stashId = stashDBId {
                            onViewStashDB?(stashId, performer.name ?? "Performer")
                        }
                    } : nil,
                    scenesView: { scenesView(scenes: scenes, performerId: performer.id) }
                )
                
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            case .error(let message):
                Text(message)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .refreshable {
            HapticManager.lightImpact()
            await viewModel.fetchPerformerDetails(id: performerId, forceRefresh: true)
        }
        .task {
            await viewModel.fetchPerformerDetails(id: performerId)
        }
        .sheet(isPresented: $showEditSheet) {
            if let performer = viewModel.performer {
                EditPerformerView(viewModel: dependencyContainer.makeEditPerformerViewModel(
                    performer: performer
                ))
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePerformerSheet(
                isDeleting: $isDeleting,
                onConfirm: {
                    Task {
                        await deletePerformer()
                    }
                }
            )
            .presentationDetents([.fraction(0.35)])
            .presentationBackground(Color.stashBackground.opacity(0.5))
        }
            .presentationBackground(Color.stashBackground.opacity(0.5))
        }
    


    private func deletePerformer() async {
        isDeleting = true
        
        do {
            try await viewModel.deletePerformer(id: performerId)
            
            HapticManager.success()
            await MainActor.run {
                dismiss()
            }
        } catch {
            HapticManager.error()
            logger.error("Failed to delete performer: \(error)")
        }
        
        isDeleting = false
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func scenesView(scenes: [Scene], performerId: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Text("Scenes")
                    .font(.title2)
                    .bold()
                
                if !scenes.isEmpty {
                    Text("•")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "film")
                            .font(.headline)
                        Text("\(scenes.count)")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // Sort Menu
            Menu {
                Section("Sort By") {
                    ForEach(SceneSortType.allCases) { type in
                        Toggle(isOn: Binding(
                            get: { viewModel.sortType == type },
                            set: { _ in
                                viewModel.sortType = type
                            }
                        )) {
                            if let customIcon = type.customIconName {
                                Label {
                                    Text(type.displayName)
                                } icon: {
                                    Image(customIcon)
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 14, height: 14)
                                }
                            } else {
                                Label(type.displayName, systemImage: type.iconName)
                            }
                        }
                    }
                }
                
                if viewModel.sortType != .random {
                    Section("Sort Direction") {
                        Toggle(isOn: Binding(
                            get: { viewModel.sortDirection == "ASC" },
                            set: { _ in
                                viewModel.sortDirection = "ASC"
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )) {
                            Label("Ascending", systemImage: "arrowtriangle.up")
                        }
                        
                        Toggle(isOn: Binding(
                            get: { viewModel.sortDirection == "DESC" },
                            set: { _ in
                                viewModel.sortDirection = "DESC"
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )) {
                            Label("Descending", systemImage: "arrowtriangle.down")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sortDirection == "ASC" ? "arrowtriangle.up" : "arrowtriangle.down")
                        .font(.caption)
                    Text(viewModel.sortType.displayName)
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                .padding(8)
                .background(Color.stashCardBackground)
                .cornerRadius(8)
            }
        }
        
        
        switch viewModel.scenesLoadState {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView("Loading scenes...")
                Spacer()
            }
            
        case .loaded:
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
                            onPerformerClick: { performerIdClicked, name in
                                // Don't navigate to self
                                if performerIdClicked != performerId {
                                    onPerformerClick?(performerIdClicked, name)
                                }
                            }
                        )
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            
        case .error(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(message)
                    .foregroundColor(.secondary)
                Button("Retry") {
                    Task {
                        await viewModel.fetchPerformerDetails(id: performerId, forceRefresh: true)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }
    
    
}

