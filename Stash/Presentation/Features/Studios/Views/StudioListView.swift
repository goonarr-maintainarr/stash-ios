import SwiftUI

/// Displays a list of Studios.
///
/// **Navigated from:** `HomeView` (via Sidebar or "Studios" option)
struct StudioListView: View {
    @State private var viewModel: StudioListViewModel
    
    init(viewModel: StudioListViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        contentView
            .navigationTitle(navigationTitle)
            .searchable(text: $viewModel.searchText, prompt: "Search studios")
            .onAppear {
                Task { await viewModel.fetchItems() }
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .loading, .idle:
            // Shimmer loading
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(0..<10, id: \.self) { _ in
                         StudioCardShimmer()
                    }
                }
                .padding()
                .padding()
            }
            .background(Color.stashBackground)
            
        case .content(let studios):
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(studios) { studio in
                        NavigationLink(value: studio) {
                            StudioCard(studio: studio)
                                .onAppear {
                                    Task { await viewModel.loadMore(currentItem: studio) }
                                }
                        }
                    }
                }
                .padding()
            }
            .background(Color.stashBackground)
            .refreshable {
                await viewModel.fetchItems(reset: true)
            }
            
        case .empty:
            ContentUnavailableView("No Studios", systemImage: "building.2")
            
        case .error(let error):
            VStack {
                Text("Error loading studios")
                Text(error).font(.caption).foregroundColor(.secondary)
                Button("Retry") {
                    Task { await viewModel.fetchItems(reset: true) }
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch viewModel.state {
        case .loading, .idle:
            return "Studios"
        default:
            return "Studios • \(viewModel.totalCount)"
        }
    }
}

// Shimmer Placeholder
struct StudioCardShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView(height: 100, cornerRadius: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(height: 20, width: 120, cornerRadius: 4)
                
                HStack {
                    SkeletonView(height: 14, width: 40, cornerRadius: 4)
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(Color.stashCardBackground)
        .cornerRadius(8)
    }
}
