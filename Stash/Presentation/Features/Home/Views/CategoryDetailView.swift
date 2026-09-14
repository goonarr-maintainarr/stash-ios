import SwiftUI
import os

/// Displays a full list of items from a specific Home category (local scenes or StashDB scenes).
///
/// **Navigated from:** `HomeView` (via "See All" button)
struct CategoryDetailView: View {
    let category: SceneCategory
    
    // Callbacks for navigation (hoisted to parent)
    let onSceneClick: ((Scene, Double?) -> Void)?
    let onStudioClick: ((Studio) -> Void)?
    let onPerformerClick: ((String, String) -> Void)?
    let onStashDBSceneClick: ((StashDBScene) -> Void)?
    
    @EnvironmentObject var container: DependencyContainer
    
    // ViewModels for both types
    // SceneListViewModel is @Observable so uses @State
    @State private var localVM: SceneListViewModel
    // StashDBCategoryDetailViewModel is now @Observable so uses @State
    @State private var stashDBVM: StashDBCategoryDetailViewModel
    
    @State private var hasLoaded = false
    
    init(
        category: SceneCategory,
        container: DependencyContainer,
        onSceneClick: ((Scene, Double?) -> Void)? = nil,
        onStudioClick: ((Studio) -> Void)? = nil,
        onPerformerClick: ((String, String) -> Void)? = nil,
        onStashDBSceneClick: ((StashDBScene) -> Void)? = nil
    ) {
        self.category = category
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
        self.onStashDBSceneClick = onStashDBSceneClick
        
        // Initialize appropriate ViewModels using container
        // SceneListViewModel uses @State init pattern for @Observable
        _localVM = State(initialValue: container.makeSceneListViewModel())
        _stashDBVM = State(wrappedValue: container.makeStashDBCategoryDetailViewModel(category: category))
    }
    
    var body: some View {
        Group {
            if category.type == .localScenes {
                localContent
            } else {
                stashDBContent
            }
        }
        .background(Color.stashBackground)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Local Scenes Content
    
    @ViewBuilder
    private var localContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if case .loading = localVM.state {
                    ForEach(0..<4, id: \.self) { _ in
                        SceneCardSkeleton()
                            .padding(.horizontal)
                    }
                } else if localVM.scenes.isEmpty {
                    emptyState
                } else {
                    ForEach(localVM.scenes) { scene in
                        SceneCard(
                            scene: scene,
                            actions: SceneCardActions(
                                onSceneClick: { onSceneClick?(scene, $0) },
                                onStudioClick: { if let s = scene.studio { onStudioClick?(Studio(id: s.id, name: s.name)) } },
                                onPerformerClick: { id, name in onPerformerClick?(id, name) }
                            )
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .task {
            if !hasLoaded {
                hasLoaded = true
                await loadLocalScenes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sceneUpdated)) { _ in
            Task { await loadLocalScenes() }
        }
    }
    
    // MARK: - StashDB Scenes Content
    
    @ViewBuilder
    private var stashDBContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if case .refreshing = stashDBVM.state {
                    ForEach(0..<4, id: \.self) { _ in
                        SceneCardSkeleton()
                            .padding(.horizontal)
                    }
                } else if stashDBVM.displayedScenes.isEmpty {
                    emptyState
                } else {
                    ForEach(stashDBVM.displayedScenes) { scene in
                        SceneCard(
                            stashDBScene: scene,
                            actions: SceneCardActions(
                                onSceneClick: { _ in onStashDBSceneClick?(scene) },
                                onStudioClick: {
                                    if let studio = scene.studio {
                                        onStudioClick?(Studio(id: studio.id, name: studio.name))
                                    }
                                },
                                onPerformerClick: { id, name in onPerformerClick?(id, name) }
                            )
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            HapticManager.lightImpact()
            _ = await stashDBVM.refreshData()
        }
        .task {
            if !hasLoaded {
                hasLoaded = true
                stashDBVM.loadScenes()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var navigationTitle: String {
        if category.type == .localScenes {
            if let tagIds = category.tagIds, !tagIds.isEmpty, let count = category.count {
                return "\(category.title) · \(count.formatted())"
            }
        } else {
            if let count = category.count {
                return "\(category.title) · \(count.formatted())"
            }
        }
        return category.title
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No scenes found")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private func loadLocalScenes() async {
        let expectedCount = category.count ?? category.scenes.count
        Logger.home.info("📦 Loading category '\(self.category.title, privacy: .public)' (expecting ~\(expectedCount) scenes)")
        
        await MainActor.run { localVM.updateLoading(true) }
        
        do {
            let database = container.stashDatabase
            
            // Use efficient tag-based query if category has tagIds
            let allScenes: [Scene]
            if let tagIds = category.tagIds, !tagIds.isEmpty {
                allScenes = try await database.fetchScenesByTagIds(tagIds)
            } else {
                // No tags - use category.scenes directly (non-tag categories like "Random", "Top Rated")
                allScenes = category.scenes
            }
            
            let sortedScenes = await Task.detached(priority: .userInitiated) {
                // Sort
                let sorted: [Scene]
                if category.sortType == .random && !category.scenes.isEmpty {
                    let categorySceneIds = Set(category.scenes.map { $0.id })
                    let categorySceneOrder = category.scenes.map { $0.id }
                    let categoryScenes = categorySceneOrder.compactMap { id in allScenes.first { $0.id == id } }
                    let remainingScenes = allScenes.filter { !categorySceneIds.contains($0.id) }.shuffled()
                    sorted = categoryScenes + remainingScenes
                } else {
                    switch category.sortType {
                    case .random: sorted = allScenes.shuffled()
                    case .createdAt: sorted = allScenes.sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
                    case .date: sorted = allScenes.sorted { ($0.date ?? "") > ($1.date ?? "") }
                    case .rating: sorted = allScenes.sorted { ($0.rating100 ?? 0) > ($1.rating100 ?? 0) }
                    case .oCounter: sorted = allScenes.sorted { ($0.o_counter ?? 0) > ($1.o_counter ?? 0) }
                    case .updatedAt: sorted = allScenes.sorted { ($0.updated_at ?? "") > ($1.updated_at ?? "") }
                    }
                }
                return sorted
            }.value
            
            Logger.home.info("✅ Loaded \(sortedScenes.count) scenes for '\(self.category.title, privacy: .public)'")
            
            await MainActor.run {
                localVM.setScenes(sortedScenes)
                localVM.updateLoading(false)
            }
        } catch {
            Logger.home.error("❌ Failed to load category: \(error.localizedDescription)")
            await MainActor.run { localVM.updateError(error.localizedDescription) }
        }
    }
}
