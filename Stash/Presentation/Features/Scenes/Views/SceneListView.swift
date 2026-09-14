import SwiftUI

/// Displays a filterable, sortable list of all Scenes.
///
/// **Part of:** `MainTabView` (Second Tab)
struct SceneListView: View {
    @Bindable var viewModel: SceneListViewModel
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Scenes")
                .toolbar {
                    sortToolbarItem
                    viewOptionsToolbarItem
                }
                .navigationDestination(for: Scene.self) { scene in
                    SceneDetailView(
                        sceneId: scene.id,
                        initialStartTime: scene.resume_time,
                        viewModel: dependencyContainer.makeSceneDetailViewModel(),
                        floatingPlayerManager: dependencyContainer.floatingVideoPlayerManager,
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) },
                        onStudioClick: { navigationPath.append($0) },
                        zoomNamespace: nil
                    )
                }
                .navigationDestination(for: Performer.self) { performer in
                    PerformerDetailView(
                        performerId: performer.id,
                        viewModel: dependencyContainer.makePerformerDetailViewModel(),
                        onSceneClick: { navigationPath.append($0) },
                        onStudioClick: { navigationPath.append($0) },
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) },
                        onStashDBSceneClick: { navigationPath.append($0) },
                        onStashDBPerformerClick: { navigationPath.append($0) },
                        onViewStashDB: { id, name in
                            navigationPath.append(StashDBRoute.performerScenes(performerId: id, performerName: name))
                        }
                    )
                }
                .navigationDestination(for: StashDBPerformer.self) { performer in
                    StashDBPerformerDetailView(
                        viewModel: dependencyContainer.makeStashDBPerformerDetailViewModel(performer: performer),
                        onSceneClick: { navigationPath.append($0) },
                        onStudioClick: { navigationPath.append($0) },
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) },
                        onViewScenesClick: {
                            navigationPath.append(StashDBRoute.performerScenes(
                                performerId: performer.id,
                                performerName: performer.name
                            ))
                        }
                    )
                }
                .navigationDestination(for: StashDBRoute.self) { route in
                    switch route {
                    case .performerScenes(let performerId, let performerName):
                        StashDBPerformerScenesView(
                            performerName: performerName,
                            viewModel: dependencyContainer.makeStashDBPerformerScenesViewModel(performerId: performerId),
                            onSceneClick: { navigationPath.append($0) },
                            onStudioClick: { navigationPath.append($0) },
                            onPerformerClick: { id, name in
                                handlePerformerClick(performerId: id, name: name)
                            }
                        )
                    }
                }
                .navigationDestination(for: StashDBScene.self) { scene in
                    StashDBSceneDetailView(
                        viewModel: dependencyContainer.makeStashDBSceneDetailViewModel(scene: scene),
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) },
                        onStudioClick: { navigationPath.append($0) }
                    )
                }
                .navigationDestination(for: Studio.self) { studio in
                    StudioDetailView(
                        viewModel: dependencyContainer.makeStudioDetailViewModel(studioId: studio.id),
                        onSceneClick: { navigationPath.append($0) },
                        onStudioClick: { navigationPath.append($0) },
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) }
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .stashAllJobsCompleted)) { _ in
                    // Refresh list when all jobs complete (may include newly identified scenes)
                    Task {
                        await viewModel.checkForUpdates()
                    }
                }
                .task {
                    // Load cache first, then smart sync
                    await viewModel.loadFromCache()
                    await viewModel.checkForUpdates()
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .content:
            sceneList
        case .empty:
             emptyView
        case .error(let message):
             errorView(message: message)
        }
    }
    
    private var loadingView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns(for: settings.sceneListLayout), spacing: 16) {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    Group {
                        switch settings.sceneListLayout {
                        case .grid:
                            SceneGridSkeleton()
                        case .compact:
                            SceneCompactSkeleton()
                        case .list:
                            SceneCardSkeleton()
                        }
                    }
                }
            }
            .padding(settings.sceneListLayout == .grid ? 16 : 0)
            .padding(.vertical)
        }
        .background(Color.stashBackground)

    }
    
    private var emptyView: some View {
        ScrollView {
            ContentUnavailableView("No Scenes", systemImage: "play.slash", description: Text("Try adjusting your filters or scan for content."))
                .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height - 200)
        }
        .background(Color.stashBackground)
        .refreshable {
            await viewModel.fetchItems(reset: true)
        }
    }
    
    private func errorView(message: String) -> some View {
        ScrollView {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
                .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height - 200)
        }
        .background(Color.stashBackground)
        .refreshable {
            await viewModel.fetchItems(reset: true)
        }
    }
    
    private var sceneList: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns(for: settings.sceneListLayout), spacing: 16) {
                ForEach(viewModel.scenes, id: \.id) { scene in
                    sceneCell(for: scene)
                    .contentShape(Rectangle())
                    .onAppear {
                            // Prefetch image when the cell appears
                            if let screenshotPath = scene.paths?.screenshot,
                               let url = dependencyContainer.settingsStore.createImageUrl(path: screenshotPath) {
                                dependencyContainer.imagePrefetchManager.prefetch(urls: [url])
                            }
                        }
                        .onDisappear {
                            // Cancel prefetch for this scene's image
                            if let screenshotPath = scene.paths?.screenshot,
                               let url = dependencyContainer.settingsStore.createImageUrl(path: screenshotPath) {
                                dependencyContainer.imagePrefetchManager.cancelPrefetch(urls: [url])
                            }
                        }
                        .padding(.horizontal, settings.sceneListLayout == .grid ? 0 : 8)
                        .task(id: scene.id) {
                            // Trigger pagination only when near the end to avoid redundant calls
                            if let index = viewModel.scenes.firstIndex(where: { $0.id == scene.id }),
                               index >= viewModel.scenes.count - 5 {
                                await viewModel.loadMore(currentItem: scene)
                            }
                        }
                }

                // Load-more footer. If your view model exposes `hasMorePages`, prefer that; otherwise fall back to `isFetching`.
                if viewModel.isFetching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(outerPadding)
            .padding(.vertical)
        }
        .background(Color.stashBackground)
        .refreshable {
            HapticManager.lightImpact()
            let task = Task.detached { @MainActor in
                await viewModel.fetchItems(reset: true)
            }
            await task.value
        }
    }
    
    private var outerPadding: CGFloat {
        settings.sceneListLayout == .grid ? 8 : 0
    }
    
    // Grid columns configuration
    private func gridColumns(for layout: SceneListLayout) -> [GridItem] {
        switch layout {
        case .grid:
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        default:
            return [GridItem(.flexible())]
        }
    }
    
    private var skeletonCount: Int {
        switch settings.sceneListLayout {
        case .grid: return 6
        case .compact: return 8
        case .list: return 3
        }
    }
    
    @ToolbarContentBuilder
    private var sortToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Section("Sort By") {
                    Picker("Sort By", selection: $viewModel.sortType) {
                        ForEach(SceneSortType.allCases) { type in
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
                                .tag(type)
                            } else {
                                Label(type.displayName, systemImage: type.iconName)
                                    .tag(type)
                            }
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: viewModel.sortType) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                
                if viewModel.sortType != .random {
                    Section("Sort Direction") {
                        Picker("Direction", selection: $viewModel.sortDirection) {
                            Label("Ascending", systemImage: "arrowtriangle.up")
                                .tag("ASC")
                            Label("Descending", systemImage: "arrowtriangle.down")
                                .tag("DESC")
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        .onChange(of: viewModel.sortDirection) { _, _ in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if viewModel.sortType == .random {
                        Image(systemName: "shuffle")
                            .font(.caption)
                    } else {
                        Image(systemName: viewModel.sortDirection == "ASC" ? "arrowtriangle.up" : "arrowtriangle.down")
                            .font(.caption)
                    }
                    Text(viewModel.sortType.displayName)
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var viewOptionsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Section("View Options") {
                    ForEach(SceneListLayout.allCases) { layout in
                        Toggle(isOn: Binding(
                            get: { settings.sceneListLayout == layout },
                            set: { _ in
                                settings.sceneListLayout = layout
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )) {
                            Label(layout.displayName, systemImage: layout.iconName)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
    
    private func makeSceneActions(for scene: Scene) -> SceneCardActions {
        SceneCardActions(
            onSceneClick: { scrubTime in
                let navScene = scrubTime.map { scene.withResumeTime($0) } ?? scene
                navigationPath.append(navScene)
            },
            onStudioClick: {
                if let studio = scene.studio {
                    navigationPath.append(Studio(id: studio.id, name: studio.name))
                }
            },
            onPerformerClick: { id, name in
                handlePerformerClick(performerId: id, name: name)
            }
        )
    }

    private var navigationTitle: String {
        if viewModel.totalCount > 0 {
            return "Scenes · \(viewModel.totalCount.formatted())"
        }
        return "Scenes"
    }
    

    @ViewBuilder
    private func sceneCell(for scene: Scene) -> some View {
        switch settings.sceneListLayout {
        case .grid:
            SceneGridItem(scene: scene, actions: makeSceneActions(for: scene))
        case .compact:
            NavigationLink(value: scene) {
                SceneCompactRow(scene: scene, actions: makeSceneActions(for: scene))
            }
            .buttonStyle(BounceButtonStyle())
        case .list:
            NavigationLink(value: scene) {
                SceneCard(scene: scene, actions: makeSceneActions(for: scene))
            }
            .buttonStyle(BounceButtonStyle())
        }
    }
    
    // MARK: - Navigation Helpers
    
    private func handlePerformerClick(performerId: String, name: String) {
        Task {
            // Check for local match first
            let matchResult = await dependencyContainer.performerDataProvider.checkLocalPerformers(identifiers: [(performerId, name)]).ids
            let localId = matchResult[performerId]
            
            await MainActor.run {
                if let localId = localId {
                    navigationPath.append(Performer(id: localId, name: ""))
                } else {
                    navigationPath.append(StashDBPerformer(stubId: performerId, stubName: name))
                }
            }
        }
    }
}

