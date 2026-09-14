import SwiftUI
import os

/// Manages available releases for a scene.
///
/// **Navigated from:** `WhisparrSceneDetailView`
struct WhisparrReleasesView: View {
    let movieId: Int
    let movieTitle: String
    let runtime: Double?
    
    @State private var viewModel: WhisparrReleaseViewModel
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var selectedRelease: WhisparrRelease?
    @State private var showSuccessToast = false
    @State private var toastMessage = "Download Queued"
    @State private var sheetHeight: CGFloat = .zero
    @Environment(\.dismiss) private var dismiss
    
    init(movieId: Int, movieTitle: String, runtime: Double?) {
        self._viewModel = State(initialValue: WhisparrReleaseViewModel())
        self.movieId = movieId
        self.movieTitle = movieTitle
        self.runtime = runtime
    }
    
    var body: some View {
        contentView
            .background(Color.stashBackground)
            .navigationTitle("Releases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        sortMenu
                        filterMenu
                    }
                    .padding(.horizontal)
                }
            }
                .searchable(text: $viewModel.filters.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search releases")
                .onSubmit(of: .search) {
                    Task {
                        await viewModel.search(movieId: movieId, term: viewModel.filters.searchQuery)
                    }
                }
                .task {
                    // Initial load - Fetch cached first (Pre-populated by interactive search)
                    await viewModel.search(movieId: movieId)
                }
                .sheet(item: $selectedRelease) { release in
                    WhisparrReleaseSheet(release: release, runtime: runtime) { force in
                        Task {
                            if await viewModel.download(release: release) {
                                HapticManager.success()
                                toastMessage = "Download Queued"
                                showSuccessToast = true
                                // Dismiss after delay
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                dismiss()
                            }
                        }
                    }
                    .onPreferenceChange(ViewHeightKey.self) { height in
                        sheetHeight = height
                    }
                    .presentationDetents([.height(sheetHeight > 0 ? sheetHeight : 600)])
                    .presentationDragIndicator(.visible)
                }
            .overlay(toastOverlay)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.releases.isEmpty {
            WhisparrReleasesSkeleton()
        } else if let _ = viewModel.error {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Failed to load releases")
                Button("Retry") {
                    Task {
                        await viewModel.search(movieId: movieId)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.displayedReleases.isEmpty {
            ContentUnavailableView("No Releases Found", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.displayedReleases) { release in
                    WhisparrReleaseRow(release: release)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRelease = release
                        }
                        .listRowBackground(Color.stashBackground)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $viewModel.sort) {
                ForEach(WhisparrReleaseSort.allCases) { sort in
                    Label(sort.rawValue, systemImage: iconForSort(sort))
                        .tag(sort)
                }
            }
            
            Divider()
            
            Picker("Direction", selection: $viewModel.sortAscending) {
                Label("Ascending", systemImage: "arrowtriangle.up")
                    .tag(true)
                Label("Descending", systemImage: "arrowtriangle.down")
                    .tag(false)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var filterMenu: some View {
        Menu {
            if !viewModel.availableProtocols.isEmpty {
                Menu {
                    Button("All") { viewModel.filters.protocolType = nil }
                    ForEach(viewModel.availableProtocols, id: \.self) { proto in
                        Button(proto.uppercased()) { viewModel.filters.protocolType = proto }
                    }
                } label: {
                     Label("Protocol", systemImage: "network")
                }
            }
            
            if !viewModel.availableIndexers.isEmpty {
                Menu {
                    Button("All") { viewModel.filters.indexer = nil }
                    ForEach(viewModel.availableIndexers, id: \.self) { indexer in
                        Button(indexer) { viewModel.filters.indexer = indexer }
                    }
                } label: {
                    Label("Indexer", systemImage: "building.2")
                }
            }
            
            Divider()
            
            Toggle(isOn: Binding(
                get: { viewModel.filters.showRejected },
                set: { viewModel.updateFilterShowRejected($0) }
            )) {
                Label("Show Rejected", systemImage: "exclamationmark.triangle")
            }
            
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .symbolVariant(viewModel.filters.isFiltering ? .fill : .none)
        }
    }
    
    private var toastOverlay: some View {
        Group {
            if showSuccessToast {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text(toastMessage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: showSuccessToast)
            }
        }
    }
    private func iconForSort(_ sort: WhisparrReleaseSort) -> String {
        switch sort {
        case .weight: return "scalemass"
        case .quality: return "film.stack"
        case .peers: return "person.wave.2"
        case .size: return "internaldrive"
        case .age: return "calendar"
        case .customScore: return "person.badge.plus"
        }
    }
}

