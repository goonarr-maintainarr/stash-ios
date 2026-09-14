import SwiftUI
import NukeUI
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSceneDetailView")

/// Details for a scene within the Whisparr library (Monitored/Unmonitored, Missing, etc.).
///
/// **Navigated from:** `WhisparrSceneListView`
struct WhisparrSceneDetailView: View {
    @State private var viewModel: WhisparrSceneDetailViewModel
    @ObservedObject private var metadata = WhisparrMetadataService.shared
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    
    @State private var showEditSheet = false
    @State private var showRemoveSheet = false
    @State private var navigationDestination: NavigationDestination?
    @State private var showErrorToast = false
    
    private let whisparrPink = Color(red: 0.91, green: 0.33, blue: 0.65)
    private let sceneId: Int
    var onPerformerClick: ((String, String) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    
    enum NavigationDestination: Hashable {
        case localScene(String)
        case interactiveSearch(Int, String, Double)
        case filesHistory(WhisparrScene)
        
        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.localScene(let id1), .localScene(let id2)): return id1 == id2
            case (.interactiveSearch(let id1, _, _), .interactiveSearch(let id2, _, _)): return id1 == id2
            case (.filesHistory(let s1), .filesHistory(let s2)): return s1.id == s2.id
            default: return false
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .localScene(let id): hasher.combine(id)
            case .interactiveSearch(let id, _, _): hasher.combine(id)
            case .filesHistory(let scene): hasher.combine(scene.id)
            }
        }
    }
    
    init(sceneId: Int, viewModel: WhisparrSceneDetailViewModel, onPerformerClick: ((String, String) -> Void)? = nil, onStudioClick: ((Studio) -> Void)? = nil) {
        self.sceneId = sceneId
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
        .onAppear {
            logger.info("📺 WhisparrSceneDetailView APPEARED - sceneId: \(sceneId)")
            // Pause queue polling to prevent list re-renders that break navigation
            WhisparrQueueService.shared.performRefresh = false
        }
        .onDisappear {
            logger.info("📺 WhisparrSceneDetailView DISAPPEARED - sceneId: \(sceneId)")
            // Resume queue polling when leaving
            WhisparrQueueService.shared.performRefresh = true
        }
        .refreshable {
            HapticManager.lightImpact()
            await viewModel.refreshMovieData()
            await viewModel.checkLocalScene()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let scene = viewModel.scene {
                    toolbarContent(scene)
                }
            }
        }
        .navigationDestination(item: $navigationDestination) { destination in
            switch destination {
            case .localScene(let sceneId):
                SceneDetailView(
                    sceneId: sceneId,
                    viewModel: dependencyContainer.makeSceneDetailViewModel(),
                    floatingPlayerManager: dependencyContainer.floatingVideoPlayerManager,
                    onPerformerClick: onPerformerClick,
                    onStudioClick: onStudioClick
                )
            case .interactiveSearch(let movieId, let title, let runtime):
                WhisparrReleasesView(
                    movieId: movieId,
                    movieTitle: title,
                    runtime: runtime
                )
            case .filesHistory(let scene):
                WhisparrFilesAndHistoryView(
                    movie: scene,
                    viewModel: WhisparrFilesViewModel(scene: scene)
                )
            }
        }
        .sceneBlurredBackground(imageURLString: viewModel.scene?.imageUrl)
        .navigationTitle("Scene Details")
        .navigationBarTitleDisplayMode(.inline)
        .toast(isShowing: viewModel.showSuccessToast, message: viewModel.toastMessage)
        .toast(
            isShowing: showErrorToast,
            message: "No releases found",
            icon: "exclamationmark.triangle.fill",
            iconColor: .red
        )
        .sheet(isPresented: $showEditSheet) {
            if let scene = viewModel.scene {
                WhisparrEditView(movie: scene)
                    .presentationDetents([.fraction(0.45)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.stashBackground.opacity(0.5))
                    .onDisappear {
                        // Refresh movie data when sheet closes to show updated values
                        Task {
                            await viewModel.refreshMovieData()
                        }
                    }
            }
        }
        .sheet(isPresented: $showRemoveSheet) {
            RemoveSceneSheet { deleteFiles, addImportExclusion in
                Task {
                    if await viewModel.deleteFileAndUnmonitor(deleteFiles: deleteFiles, addImportExclusion: addImportExclusion) {
                        await MainActor.run { dismiss() }
                        HapticManager.success()
                    } else {
                        HapticManager.error()
                    }
                }
            }
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.stashBackground.opacity(0.5))
        }
        .task {
            await metadata.ensureLoaded()
            await viewModel.refreshMovieData()
            await viewModel.checkLocalScene()
            await viewModel.loadPerformerDetails()
            await viewModel.checkLocalPerformers()
        }
    }
    
    @ViewBuilder
    private func sceneContent(_ scene: WhisparrScene) -> some View {
        let qualityProfileName = scene.qualityProfileId.flatMap { id in
            metadata.qualityProfiles.first(where: { $0.id == id })?.name
        }
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WhisparrSceneHeroImage(
                    scene: scene,
                    blurNsfw: settingsStore.blurNsfw,
                    qualityProfileName: qualityProfileName
                )
                WhisparrSceneHeader(
                    scene: scene,
                    onStudioClick: {
                        Task {
                            if let studio = await viewModel.resolveLocalStudio(
                                studioForeignId: scene.studioForeignId,
                                studioTitle: scene.studioTitle
                            ) {
                                onStudioClick?(studio)
                            }
                        }
                    }
                )
                .padding(.horizontal)
                WhisparrSearchButtons(
                    scene: scene,
                    isSearching: viewModel.isSearching,
                    onAutomaticSearch: viewModel.performAutomaticSearch,
                    onInteractiveSearch: {
                        HapticManager.selection()
                        // Navigate immediately - ReleasesView will show shimmer while loading
                        navigationDestination = .interactiveSearch(scene.id, scene.title, Double(scene.runtime) * 60)
                    }
                )
                WhisparrFileInfoSection(
                    scene: scene,
                    onFilesHistoryTap: {
                        navigationDestination = .filesHistory(scene)
                    }
                )
                WhisparrPerformersSection(
                    femalePerformers: viewModel.femalePerformers,
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
    
    @ViewBuilder
    private func toolbarContent(_ scene: WhisparrScene) -> some View {
        HStack(spacing: 24) {
            Button(action: {
                Task {
                    if await viewModel.toggleMonitorStatus() {
                        HapticManager.success()
                    } else {
                        HapticManager.error()
                    }
                }
            }) {
                Image(systemName: scene.monitored ? "bookmark.fill" : "bookmark")
                    .foregroundColor(scene.monitored ? .blue : .secondary)
                    .padding(.horizontal, 4)
            }
            
            Menu {
                if let localSceneId = viewModel.localSceneId {
                    Button(action: {
                        navigationDestination = .localScene(localSceneId)
                    }) {
                        Label("Open in Stash", systemImage: "play.rectangle")
                    }
                }
                
                Button(action: {
                    Task {
                        HapticManager.selection()
                        if await viewModel.refreshSceneCommand() {
                            HapticManager.success()
                        } else {
                            HapticManager.error()
                        }
                    }
                }) {
                    Label("Refresh & Scan", systemImage: "arrow.clockwise")
                }
                
                Divider()
                
                Button(action: {
                    showEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    showRemoveSheet = true
                }) {
                    Label("Remove Scene", systemImage: "trash.slash")
                }
            } label: {
                Image(systemName: "ellipsis")
                .frame(width: 24, height: 24)
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
    }
}

