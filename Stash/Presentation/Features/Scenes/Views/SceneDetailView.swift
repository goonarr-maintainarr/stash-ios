import SwiftUI
import AVKit
import NukeUI
import Nuke
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "SceneDetailView")

/// The main detail screen for a specific Scene.
/// Contains video player, metadata, performers, and related content.
///
/// **Navigated from:** Lists, Search Results, Recommendations
struct SceneDetailView: View {
    let sceneId: String
    @State private var viewModel: SceneDetailViewModel
    @EnvironmentObject var settings: SettingsStore
    var onPerformerClick: ((String, String) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    
    init(sceneId: String, initialStartTime: Double? = nil, viewModel: SceneDetailViewModel, floatingPlayerManager: FloatingVideoPlayerService, onPerformerClick: ((String, String) -> Void)? = nil, onStudioClick: ((Studio) -> Void)? = nil, zoomNamespace: Namespace.ID? = nil) {
        self.sceneId = sceneId
        viewModel.initialStartTime = initialStartTime
        _viewModel = State(wrappedValue: viewModel)
        self.floatingPlayerManager = floatingPlayerManager
        self.onPerformerClick = onPerformerClick
        self.onStudioClick = onStudioClick
        self.zoomNamespace = zoomNamespace
    }
    @EnvironmentObject var dependencyContainer: DependencyContainer
    var floatingPlayerManager: FloatingVideoPlayerService
    @State private var isLandscape = false
    @State private var showDeleteDialog = false
    @State private var showEditSheet = false
    @State private var deleteFile = true
    @State private var deleteGenerated = true
    @State private var isDeleting = false
    @State private var showReleaseSearch = false
    @State private var navigateToWhisparr = false
    @State private var showWhisparrNotFound = false
    @State private var showScrapeSheet = false
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var heroColor: Color?
    @State private var spriteManager: SpriteManager?

    @Environment(\.dismiss) var dismiss
    private var zoomNamespace: Namespace.ID? // Passed from parent for transition
    

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                SceneDetailSkeletonView()
                    .transition(.opacity)
            case .content(let scene):
                sceneContent(scene)
                    .task {
                        await extractHeroColor(from: scene)
                        await loadSprites(for: scene)
                    }
            case .empty:
                ContentUnavailableView("No Scene Data", systemImage: "film", description: Text("Scene data is not available"))
            case .error(let message):
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
                    .refreshable {
                        await viewModel.fetchSceneDetails(id: sceneId, forceRefresh: true)
                    }
            }
        }
        .task {
            // Load if not loaded
            if viewModel.scene == nil {
                await viewModel.fetchSceneDetails(id: sceneId)
            }
        }
        .onAppear {
            // Recreate player if scene is loaded but player was cleaned up
            if viewModel.scene != nil && viewModel.player == nil {
                viewModel.recreatePlayerIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape {
                isLandscape = true
            } else if orientation.isPortrait {
                isLandscape = false
            }
        }
        .fullScreenCover(isPresented: $isLandscape) {
            if let player = viewModel.player, let scene = viewModel.scene {
                SceneFullscreenPlayerView(
                    player: player,
                    scene: scene,
                    spriteManager: spriteManager,
                    heroColor: heroColor ?? .white,
                    isPresented: $isLandscape
                )
                .onDisappear {
                    if UIDevice.current.orientation.isPortrait {
                        isLandscape = false
                    }
                }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }
        }
        // Sheets and Alerts need to be attached here or to the sceneContent
        // Attach them to the group so they work in all states if needed, or just content?
        // Most depend on scene data, so attach to content.
        // But showDeleteDialog relies on state vars which are in View.
        .sheet(isPresented: $showReleaseSearch) {
            if let movieId = viewModel.whisparrMovieId, let scene = viewModel.scene {
                WhisparrReleasesView(
                    movieId: movieId, 
                    movieTitle: scene.title ?? "Unknown Scene",
                    runtime: scene.files?.first?.duration
                )
            }
        }
        .alert("Scene not found in Whisparr", isPresented: $showWhisparrNotFound) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This scene could not be found in your Whisparr library with the associatedStash ID. Ensure it is added and mapped correctly.")
        }
        .sheet(isPresented: $showDeleteDialog) {
            DeleteSceneSheet(
                deleteFile: $deleteFile,
                deleteGenerated: $deleteGenerated,
                isDeleting: $isDeleting,
                onConfirm: {
                    Task {
                        await deleteScene()
                    }
                }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationBackground(Color.stashBackground.opacity(0.5))
        }
        .sheet(isPresented: $showEditSheet) {
            if let scene = viewModel.scene {
                EditSceneView(
                    viewModel: dependencyContainer.makeEditSceneViewModel(scene: scene)
                ) {
                    Task {
                        await viewModel.fetchSceneDetails(id: scene.id, forceRefresh: true)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showScrapeSheet) {
            SceneScrapeView(viewModel: viewModel, isPresented: $showScrapeSheet)
        }
        .onDisappear {
            // Only cleanup if not using floating player
            if !floatingPlayerManager.isPlaying {
                viewModel.cleanup()
            }
        }
    }
    
    private func extractHeroColor(from scene: Scene) async {
        guard heroColor == nil,
              let screenshotPath = scene.paths?.screenshot,
              let url = settings.createImageUrl(path: screenshotPath) else { return }
        
        if let color = await HeroAccentColor.extract(from: url) {
            self.heroColor = color
        }
    }
    
    private func loadSprites(for scene: Scene) async {
        if spriteManager == nil,
           scene.paths?.sprite != nil,
           scene.paths?.vtt != nil {
            let loader = SceneScrubberLoader(settings: settings)
            spriteManager = try? await loader.loadScrubber(for: scene)
        }
    }

    private func sceneContent(_ scene: Scene) -> some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 16) {
                    SceneVideoPlayerView(
                        player: viewModel.player,
                        isPlayerLoaded: viewModel.isPlayerLoaded,
                        onPlayerLoadedChange: { viewModel.setPlayerLoaded($0) },
                        scene: scene,
                        availableStreams: viewModel.availableStreams,
                        selectedStream: viewModel.selectedStream,
                        onSelectStream: { viewModel.selectStream($0) },
                        spriteManager: spriteManager,
                        heroAccentColor: heroColor ?? .red
                    )
                    .id("videoPlayer")
                    
                    LocalSceneHeader(scene: scene, viewModel: viewModel, onStudioClick: {
                        if let studio = scene.studio {
                            onStudioClick?(Studio(id: studio.id, name: studio.name))
                        }
                    })
                        .padding(.horizontal)
                    
                    if let tags = scene.tags, !tags.isEmpty {
                        TagsSection(tags: tags, heroColor: heroColor)
                    }
                    
                    if let markers = scene.scene_markers, !markers.isEmpty {
                        SceneMarkersSection(markers: markers) { seconds in
                            if let player = viewModel.player {
                                withAnimation {
                                    proxy.scrollTo("videoPlayer", anchor: .top)
                                }
                                // Update player loaded state
                                viewModel.setPlayerLoaded(true)
                                let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
                                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                player.play()
                            }
                        }
                    }
                    
                    if let performers = scene.performers, !performers.isEmpty {
                        PerformersSection(performers: performers, onPerformerClick: onPerformerClick, zoomNamespace: zoomNamespace)
                    }
                    
                    if (scene.o_history != nil && !scene.o_history!.isEmpty) || (scene.play_history != nil && !scene.play_history!.isEmpty) {
                        SceneHistoryView(scene: scene)
                    }
                    
                    if let file = scene.files?.first {
                        FileInfoSection(file: file)
                            .padding(.horizontal)
                    }
                    
                    if let stashIds = scene.stash_ids, !stashIds.isEmpty {
                        SceneStashIDsView(stashIds: stashIds)
                            .padding(.horizontal)
                    }
                    
                    if (scene.director != nil && !scene.director!.isEmpty) ||
                       (scene.code != nil && !scene.code!.isEmpty) ||
                       (scene.url != nil && !scene.url!.isEmpty) ||
                       (scene.urls != nil && !scene.urls!.isEmpty) ||
                       (scene.created_at != nil && !scene.created_at!.isEmpty) ||
                       (scene.updated_at != nil && !scene.updated_at!.isEmpty) {
                        SceneAdditionalMetadataView(
                            director: scene.director,
                            code: scene.code,
                            url: scene.url,
                            urls: scene.urls,
                            createdAt: scene.created_at,
                            updatedAt: scene.updated_at
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .refreshable {
            HapticManager.lightImpact()
            await viewModel.fetchSceneDetails(id: sceneId, forceRefresh: true)
        }
        .sceneBlurredBackground(imageURL: settings.createImageUrl(path: scene.paths?.screenshot))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.player != nil {
                    Button(action: {
                        HapticManager.mediumImpact()
                        if let player = viewModel.player {
                            floatingPlayerManager.startPlaying(player: player, scene: scene)
                        }
                    }) {
                        Label("Minimize", systemImage: "pip.enter")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !settings.whisparrUrl.isEmpty {
                        Button(action: {
                            Task {
                                await viewModel.resolveWhisparrId()
                                if viewModel.whisparrMovie != nil {
                                    navigateToWhisparr = true
                                } else {
                                    showWhisparrNotFound = true
                                }
                            }
                        }) {
                            Label("Open in Whisparr", systemImage: "magnifyingglass")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        viewModel.resetScrapeState()
                        showScrapeSheet = true
                        Task {
                             await viewModel.fetchStashBoxes()
                        }
                    }) {
                        Label("Scrape Scene", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button(action: {
                        showEditSheet = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteDialog = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    if viewModel.whisparrState.isResolving {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToWhisparr) {
            if let movie = viewModel.whisparrMovie {
                WhisparrSceneDetailView(
                    sceneId: movie.id,
                    viewModel: dependencyContainer.makeWhisparrSceneDetailViewModel(scene: movie),
                    onPerformerClick: onPerformerClick,
                    onStudioClick: onStudioClick
                )
            }
        }
    }
    

    
    private func deleteScene() async {
        isDeleting = true
        
        let success = await viewModel.deleteScene(deleteFile: deleteFile, deleteGenerated: deleteGenerated)
        
        await MainActor.run {
            if success {
                HapticManager.success()
                showDeleteDialog = false
                dismiss()
            } else {
                HapticManager.error()
                showDeleteDialog = false
            }
            isDeleting = false
        }
    }
}

