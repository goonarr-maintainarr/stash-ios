import SwiftUI

/// Displays a filterable, sortable list of all Performers.
///
/// **Part of:** `MainTabView` (Third Tab)
struct PerformerListView: View {
    @State var viewModel: PerformerListViewModel
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Performers")
                .toolbar {
                    sortToolbarItem
                    viewOptionsToolbarItem
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
                .navigationDestination(for: Scene.self) { scene in
                    SceneDetailView(
                        sceneId: scene.id,
                        initialStartTime: scene.resume_time,
                        viewModel: dependencyContainer.makeSceneDetailViewModel(),
                        floatingPlayerManager: dependencyContainer.floatingVideoPlayerManager,
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
                .navigationDestination(for: StashDBScene.self) { scene in
                    StashDBSceneDetailView(
                        viewModel: dependencyContainer.makeStashDBSceneDetailViewModel(scene: scene),
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name, isStashDB: true) },
                        onStudioClick: { navigationPath.append($0) }
                    )
                }
                .navigationDestination(for: StashDBPerformer.self) { performer in
                    StashDBPerformerDetailView(
                        viewModel: dependencyContainer.makeStashDBPerformerDetailViewModel(performer: performer),
                        onSceneClick: { navigationPath.append($0) },
                        onStudioClick: { navigationPath.append($0) },
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name, isStashDB: true) },
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
                                handlePerformerClick(performerId: id, name: name, isStashDB: true)
                            }
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .stashAllJobsCompleted)) { _ in
                    // Refresh list when all jobs complete (may include newly identified performers)
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
            performerList
        case .empty:
            emptyView
        case .error(let message):
            errorView(message: message)
        }
    }
    
    private var loadingView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    PerformerCardSkeleton()
                }
            }
            .padding()
        }
        .background(Color.stashBackground)

    }
    
    private var emptyView: some View {
        ScrollView {
            ContentUnavailableView("No Performers", systemImage: "person.slash", description: Text("Try adjusting your filters or scan for content."))
                .frame(maxWidth: .infinity, minHeight: 400)
        }
        .background(Color.stashBackground)
        .refreshable {
            await viewModel.fetchItems(reset: true)
        }
    }
    
    private func errorView(message: String) -> some View {
        ScrollView {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
                .frame(maxWidth: .infinity, minHeight: 400)
        }
        .background(Color.stashBackground)
        .refreshable {
            await viewModel.fetchItems(reset: true)
        }
    }
    
    private var performerList: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(viewModel.performers) { performer in
                    PerformerCard(
                        performer: performer,
                        layoutType: settings.performerListLayout,
                        actions: makePerformerActions(for: performer)
                    )
                    .task {
                        await viewModel.loadMore(currentItem: performer)
                    }
                    .onDisappear {
                        if let imagePath = performer.image_path,
                           let url = settings.createImageUrl(path: imagePath) {
                            dependencyContainer.imagePrefetchManager.cancelPrefetch(urls: [url])
                        }
                    }
                }
                
                if viewModel.isFetching {
                    ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding()
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
    
    private var gridColumns: [GridItem] {
        switch settings.performerListLayout {
        case .grid3x:
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        case .grid2x:
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        case .list:
            return [GridItem(.flexible())]
        }
    }
    
    private func makePerformerActions(for performer: Performer) -> PerformerCardActions {
        PerformerCardActions(onPerformerClick: {
            HapticManager.lightImpact()
            navigationPath.append(performer)
        })
    }
    
    private var skeletonCount: Int {
        switch settings.performerListLayout {
        case .grid3x: return 9  // 3 rows of 3
        case .grid2x: return 6  // 3 rows of 2
        case .list: return 3     // 3 large cards
        }
    }
    
    @ToolbarContentBuilder
    private var sortToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Section("Sort By") {
                    ForEach(PerformerSortType.allCases) { type in
                        Toggle(isOn: Binding(
                            get: { viewModel.sortType == type },
                            set: { _ in
                                viewModel.sortType = type
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                                Image(systemName: type.iconName)
                                Text(type.displayName)
                            }
                        }
                    }
                }
                
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
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sortDirection == "ASC" ? "arrowtriangle.up" : "arrowtriangle.down")
                        .font(.caption)
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
                    ForEach(PerformerLayoutType.allCases) { type in
                        Toggle(isOn: Binding(
                            get: { settings.performerListLayout == type },
                            set: { _ in
                                settings.performerListLayout = type
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )) {
                            Label(type.displayName, systemImage: type.iconName)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
    
    private var navigationTitle: String {
        if viewModel.totalCount > 0 {
            return "Performers · \(viewModel.totalCount.formatted())"
        }
        return "Performers"
    }
    
    // MARK: - Navigation Helpers
    
    private func handlePerformerClick(performerId: String, name: String, isStashDB: Bool = false) {
        if isStashDB {
            Task {
                // If we know it's StashDB, we still check for local match just in case,
                // matching logic is same.
                await checkAndNavigate(performerId: performerId, name: name)
            }
        } else {
             Task {
                await checkAndNavigate(performerId: performerId, name: name)
            }
        }
    }
    
    private func checkAndNavigate(performerId: String, name: String) async {
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
