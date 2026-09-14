import SwiftUI
import NukeUI

/// Detailed view for a specific Studio.
///
/// **Navigated from:** `StudioListView` or Scene Details (Studio Link)
struct StudioDetailView: View {
    @State private var viewModel: StudioDetailViewModel
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    @State private var selectedTab: Tab = .overview
    
    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case scenes = "Scenes"
        case performers = "Performers"
        
        var id: String { rawValue }
    }
    
    var onSceneClick: ((Scene) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    var onPerformerClick: ((String, String) -> Void)?
    
    init(viewModel: StudioDetailViewModel,
         onSceneClick: ((Scene) -> Void)? = nil,
         onStudioClick: ((Studio) -> Void)? = nil,
         onPerformerClick: ((String, String) -> Void)? = nil) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSceneClick = onSceneClick
        self.onStudioClick = onStudioClick
        self.onPerformerClick = onPerformerClick
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch viewModel.state {
                case .loading, .idle:
                    StudioDetailShimmer()
                    
                case .content(let studio):
                    // Header Image
                    if let url = settings.createImageUrl(path: studio.image_path) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Color.gray.opacity(0.3).frame(height: 200)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                    }
                    
                    // Tab Picker
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Tab Content
                    VStack(alignment: .leading, spacing: 12) {
                        switch selectedTab {
                        case .overview:
                            overviewContent(studio: studio)
                            
                        case .scenes:
                            StudioScenesView(
                                viewModel: StudioScenesViewModel(
                                    repository: dependencyContainer.sceneRepository,
                                    studioId: studio.id
                                ),
                                onSceneClick: onSceneClick,
                                onStudioClick: onStudioClick,
                                onPerformerClick: onPerformerClick
                            )
                            
                        case .performers:
                            StudioPerformersView(
                                viewModel: StudioPerformersViewModel(
                                    repository: dependencyContainer.performerRepository,
                                    studioId: studio.id
                                ),
                                onPerformerClick: onPerformerClick
                            )
                        }
                    }
                    
                case .empty:
                    ContentUnavailableView("Studio Not Found", systemImage: "questionmark.folder")
                    
                case .error(let error):
                    VStack {
                        Text("Error loading details")
                        Text(error)
                        Button("Retry") {
                            Task { await viewModel.refresh() }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(.vertical)
        }
        .background(Color.stashBackground)
        .navigationTitle(caseLoadedTitle ?? "Studio")
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            Task { await viewModel.loadStudio() }
        }
    }
    
    @ViewBuilder
    private func overviewContent(studio: Studio) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(studio.details ?? "No description available.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatItem(label: "Scenes", value: "\(studio.scene_count ?? 0)")
                StatItem(label: "Images", value: "\(studio.image_count ?? 0)")
                StatItem(label: "Performers", value: "\(studio.performer_count ?? 0)")
                StatItem(label: "Rating", value: studio.rating100.map { "\($0)%" } ?? "-")
            }
            
            // Parent Studio
            if let parent = studio.parent_studio {
                Divider()
                Text("Child of").font(.caption.smallCaps()).foregroundColor(.secondary)
                NavigationLink(value: Studio(id: parent.id, name: parent.name, image_path: parent.image_path)) {
                    HStack {
                        Image(systemName: "arrow.turn.right.up")
                        Text(parent.name)
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.stashCardBackground)
                    .cornerRadius(8)
                }
            }
            
            // Child Studios
            if let children = studio.child_studios, !children.isEmpty {
                Divider()
                Text("Sub-Studios").font(.caption.smallCaps()).foregroundColor(.secondary)
                ForEach(children) { child in
                    NavigationLink(value: Studio(id: child.id, name: child.name, image_path: child.image_path)) {
                        HStack {
                            Image(systemName: "arrow.turn.down.right")
                            Text(child.name)
                        }
                        .padding(.vertical, 4)
                    }
                    Divider()
                }
            }
        }
        .padding(.horizontal)
    }
    
    var caseLoadedTitle: String? {
        if case .content(let s) = viewModel.state {
            return s.name
        }
        return nil
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
            .font(.title2)
            .bold()
            Text(label)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.stashCardBackground)
        .cornerRadius(8)
    }
}

struct StudioDetailShimmer: View {
    var body: some View {
        VStack(spacing: 20) {
            Color.gray.opacity(0.3)
                .frame(height: 200)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3) { _ in
                    Color.gray.opacity(0.3)
                        .frame(height: 16)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
        }
    }
}


