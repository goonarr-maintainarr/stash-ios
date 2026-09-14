import SwiftUI
import NukeUI
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSceneListView")

/// A list of monitored scenes in Whisparr (Missing, Wanted, Cutoff Unmet).
///
/// **Part of:** `WhisparrDashboard` (Whisparr Tab)
struct WhisparrSceneListView: View {
    @Bindable var viewModel: WhisparrSceneListViewModel
    var queue: WhisparrQueueService = .shared
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by title, studio, code, or performer")
                .toolbar {
                    sortToolbarItem
                    trailingToolbarItems
                }
                .navigationDestination(for: WhisparrScene.self) { scene in
                    WhisparrSceneDetailView(
                        sceneId: scene.id,
                        viewModel: dependencyContainer.makeWhisparrSceneDetailViewModel(scene: scene),
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) },
                        onStudioClick: { navigationPath.append($0) }
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
                        onSceneClick: { scene in navigationPath.append(scene) },
                        onStudioClick: { navigationPath.append($0) },
                        onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) }
                    )
                }
                .task {
                    await viewModel.loadScenes()
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        // Always show scene list if we have data, to preserve navigation state
        if !viewModel.items.isEmpty || viewModel.syncState != .idle {
            sceneList
        } else {
            switch viewModel.state {
            case .idle, .loading:

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            SceneCardSkeleton()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical)
                }
                .background(Color.stashBackground)
                .background(Color.stashBackground)
            case .error(let message):
                errorView(message)
            case .empty:
                // Empty state (loaded but no scenes)
                GeometryReader { geometry in
                    ScrollView {
                        ContentUnavailableView("No Movies", systemImage: "film.stack", description: Text("Try adjusting your filters or add movies via Whisparr."))
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height - 200)
                    }
                }
                .background(Color.stashBackground)
                .refreshable {
                    await viewModel.fetchItems(reset: true)
                }
            case .content(let items):
                // This shouldn't be hit because of the if !viewModel.items.isEmpty above,
                // but we include it for completeness.
                sceneList
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height - 200)
            }
        }
        .background(Color.stashBackground)
        .refreshable {
            await viewModel.fetchItems(reset: true)
        }
    }
    
    private var sceneList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.items) { scene in
                    sceneRow(scene)
                        .padding(.horizontal, 8)
                }
                
                if viewModel.isRefreshing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
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
    
    private var navigationTitle: String {
        if viewModel.totalCount > 0 {
            return "Whisparr · \(viewModel.totalCount.formatted())"
        }
        return "Whisparr"
    }

    @ViewBuilder
    private func sceneRow(_ scene: WhisparrScene) -> some View {
        SceneCard(
            whisparrScene: scene,
            isInQueue: queue.isMovieInQueue(scene.id),
            actions: SceneCardActions(
                onSceneClick: { _ in navigationPath.append(scene) },
                onStudioClick: {
                    handleStudioClick(studioForeignId: scene.studioForeignId, studioTitle: scene.studioTitle)
                },
                onPerformerClick: { id, name in
                    // Whisparr performer clicks usually go to StashDB or local
                    // Whisparr foreignId IS the StashDB ID.
                    handlePerformerClick(performerId: id, name: name)
                }
            )
        )
        .simultaneousGesture(TapGesture().onEnded {
            HapticManager.lightImpact()
        })
        .onAppear {
            prefetchUpcomingImages(from: scene)
        }
        .onDisappear {
            if let urlStr = scene.imageUrl, let url = URL(string: urlStr) {
                dependencyContainer.imagePrefetchManager.cancelPrefetch(urls: [url])
            }
        }
        .task {
            await viewModel.loadMore(currentItem: scene)
        }
    }
    
    /// Prefetches images for upcoming scenes in the list.
    private func prefetchUpcomingImages(from scene: WhisparrScene) {
        let currentItems = viewModel.items
        guard let currentIndex = currentItems.firstIndex(where: { $0.id == scene.id }) else { return }
        
        // Prefetch next 5 scenes
        let endIndex = min(currentIndex + 6, currentItems.count)
        let upcomingScenes = currentItems[currentIndex..<endIndex]
        
        let urls = upcomingScenes.compactMap { scene -> URL? in
            guard let urlStr = scene.imageUrl else { return nil }
            return URL(string: urlStr)
        }
        
        dependencyContainer.imagePrefetchManager.prefetch(urls: urls)
    }
    
    // MARK: - Toolbar Items
    
    @ToolbarContentBuilder
    private var sortToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 0) {
                // Sort Menu
                Menu {
                    Section("Sort By") {
                        ForEach(WhisparrSortType.allCases) { sortType in
                            Toggle(isOn: Binding(
                                get: { viewModel.sortType == sortType },
                                set: { _ in
                                    viewModel.sortType = sortType
                                    HapticManager.lightImpact()
                                }
                            )) {
                                Label(sortType.displayName, systemImage: sortType.iconName)
                            }
                        }
                    }
                    
                    Section("Direction") {
                        Toggle(isOn: Binding(
                            get: { viewModel.sortDirection == "ASC" },
                            set: { _ in
                                viewModel.sortDirection = "ASC"
                                HapticManager.lightImpact()
                            }
                        )) {
                            Label("Ascending", systemImage: "arrowtriangle.up")
                        }
                        
                        Toggle(isOn: Binding(
                            get: { viewModel.sortDirection == "DESC" },
                            set: { _ in
                                viewModel.sortDirection = "DESC"
                                HapticManager.lightImpact()
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
                
                // Vertical Divider
                Divider()
                    .frame(height: 20)
                
                // Filter Menu
                Menu {
                    Section("Filter") {
                        ForEach(WhisparrFilterType.allCases) { filterType in
                            Toggle(isOn: Binding(
                                get: { viewModel.filterType == filterType },
                                set: { _ in
                                    viewModel.filterType = filterType
                                    HapticManager.lightImpact()
                                }
                            )) {
                                Label(filterType.displayName, systemImage: filterType.iconName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.filterType.displayName)
                            .font(.subheadline)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            NavigationLink(destination: WhisparrSearchView(
                viewModel: WhisparrSearchViewModel(),
                onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name) },
                onStudioClick: { navigationPath.append($0) }
            )) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
            }
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.lightImpact()
            })
            
            NavigationLink {
                WhisparrQueueView()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.body)
                    if queue.items.isEmpty {
                        Text("Queue")
                            .font(.subheadline)
                    } else {
                        Text("\(queue.items.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.lightImpact()
            })
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
    
    private func handleStudioClick(studioForeignId: String?, studioTitle: String?) {
        Task {
            let studio = await viewModel.resolveLocalStudio(studioForeignId: studioForeignId, studioTitle: studioTitle)
            await MainActor.run {
                if let studio = studio {
                    navigationPath.append(studio)
                }
            }
        }
    }
}

