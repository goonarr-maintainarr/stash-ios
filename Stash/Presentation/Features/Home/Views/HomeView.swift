import SwiftUI
import os

/// Navigation destinations for HomeView
enum HomeNavigation: Hashable {
    case configureRows
    case studios
}

/// The main dashboard screen displaying categorized content (New Releases, Tag-based rows, etc.).
///
/// **Part of:** `MainTabView` (First Tab)
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var hasInitialized = false
    @State private var prefetchTask: Task<Void, Never>? = nil
    @State private var showStats = false
    @State private var navigationPath = NavigationPath()
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    // Default memberwise init is sufficient for ObservedObject
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                // Use VStack for < 10 categories, LazyVStack for more
                // LazyVStack has overhead that's not needed for small lists
                Group {
                    if viewModel.categories.count < 10 {
                        VStack(spacing: 24) {
                            categoryContent
                        }
                    } else {
                        LazyVStack(spacing: 24) {
                            categoryContent
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.stashBackground)
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(value: HomeNavigation.configureRows) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.lightImpact()
                    })
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            HapticManager.lightImpact()
                            showStats = true
                        }) {
                            Label("Library Stats", systemImage: "chart.bar.fill")
                        }
                        
                        Button(action: {
                            HapticManager.lightImpact()
                            navigationPath.append(HomeNavigation.studios)
                        }) {
                            Label("Studios", systemImage: "building.2.fill")
                        }
                        
                        Button(action: {
                            HapticManager.mediumImpact()
                            settings.blurNsfw.toggle()
                        }) {
                            Label(
                                settings.blurNsfw ? "Disable NSFW Blur" : "Enable NSFW Blur",
                                systemImage: settings.blurNsfw ? "eye.fill" : "eye.slash.fill"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .refreshable {
                HapticManager.lightImpact()
                await viewModel.refresh()
            }
            .navigationDestination(for: SceneCategory.self) { category in
                CategoryDetailView(
                    category: category,
                    container: dependencyContainer,
                    onSceneClick: { scene, scrubTime in
                        let navScene = scrubTime.map { scene.withResumeTime($0) } ?? scene
                        navigationPath.append(navScene)
                    },
                    onStudioClick: { navigationPath.append($0) },
                    onPerformerClick: { id, name in
                        handlePerformerClick(performerId: id, name: name, isStashDB: category.type == .stashDBScenes)
                    },
                    onStashDBSceneClick: { navigationPath.append($0) }
                )
            }
            .navigationDestination(for: Scene.self) { scene in
                SceneDetailView(
                    sceneId: scene.id,
                    initialStartTime: scene.resume_time,
                    viewModel: dependencyContainer.makeSceneDetailViewModel(),
                    floatingPlayerManager: dependencyContainer.floatingVideoPlayerManager,
                    onPerformerClick: { id, name in
                        handlePerformerClick(performerId: id, name: name, isStashDB: false)
                    },
                    onStudioClick: { navigationPath.append($0) }
                )
            }
            .navigationDestination(for: StashDBScene.self) { scene in
                StashDBSceneDetailView(
                    viewModel: dependencyContainer.makeStashDBSceneDetailViewModel(scene: scene),
                    onPerformerClick: { id, name in
                        handlePerformerClick(performerId: id, name: name, isStashDB: true)
                    },
                    onStudioClick: { navigationPath.append($0) }
                )
            }
            .navigationDestination(for: Performer.self) { performer in
                PerformerDetailView(
                    performerId: performer.id,
                    viewModel: dependencyContainer.makePerformerDetailViewModel(),
                    onSceneClick: { navigationPath.append($0) },
                    onStudioClick: { navigationPath.append($0) },
                    onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name, isStashDB: false) },
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
            .navigationDestination(for: Studio.self) { studio in
                StudioDetailView(
                    viewModel: dependencyContainer.makeStudioDetailViewModel(studioId: studio.id),
                    onSceneClick: { scene in
                        // Handle scene click, including resume time if needed (defaulting to clean start here as StudioDetailView usually passes full scene)
                        navigationPath.append(scene)
                    },
                    onStudioClick: { navigationPath.append($0) },
                    onPerformerClick: { id, name in handlePerformerClick(performerId: id, name: name, isStashDB: false) }
                )
            }
            .navigationDestination(for: HomeNavigation.self) { navigation in
                switch navigation {
                case .configureRows:
                    RowConfigView(viewModel: viewModel)
                case .studios:
                    StudioListView(viewModel: dependencyContainer.makeStudioListViewModel())
                }
            }
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                Task {
                    await viewModel.prefetchAppData()
                    await viewModel.loadCategories()
                }
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView(viewModel: dependencyContainer.makeStatsViewModel())
        }
    }
    // MARK: - Helpers
    
    @ViewBuilder
    private var categoryContent: some View {
        if let syncError = viewModel.syncManager.errorMessage {
            RetryView(message: syncError) {
                Task {
                    viewModel.syncManager.errorMessage = nil
                    await viewModel.refresh()
                }
            }
        } else if case .error(let message) = viewModel.state {
            RetryView(message: message) {
                Task { await viewModel.loadCategories() }
            }
        } else {
            switch viewModel.state {
            case .loading where viewModel.categories.isEmpty:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            default:
                if viewModel.categories.isEmpty {
                    // Skeleton loading state
                    ForEach(0..<3, id: \.self) { _ in
                        CategoryRowSkeleton()
                    }
                } else {
                    ForEach(viewModel.categories) { category in
                        CategoryRow(
                            category: category,
                            zoomTransition: nil,
                            onSceneClick: { scene, scrubTime in
                                let navScene = scrubTime.map { scene.withResumeTime($0) } ?? scene
                                navigationPath.append(navScene)
                            },
                            onStashDBSceneClick: { scene in
                                navigationPath.append(scene)
                            },
                            onStudioClick: { studio in
                                navigationPath.append(studio)
                            },
                            onPerformerClick: { id, name in
                                handlePerformerClick(performerId: id, name: name, isStashDB: category.type == .stashDBScenes)
                            },
                            onSeeAllClick: { category in
                                navigationPath.append(category)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Helpers
    
    private func handlePerformerClick(performerId: String, name: String, isStashDB: Bool) {
        Task {
            // Check for local match first
            let matchResult = await dependencyContainer.performerDataProvider.checkLocalPerformers(identifiers: [(performerId, name)]).ids
            let localId = matchResult[performerId]
            
            await MainActor.run {
                if let localId = localId {
                    navigationPath.append(Performer(id: localId, name: ""))
                } else if isStashDB {
                    navigationPath.append(StashDBPerformer(stubId: performerId, stubName: name))
                } else {
                    navigationPath.append(Performer(id: performerId, name: ""))
                }
            }
        }
    }
}
