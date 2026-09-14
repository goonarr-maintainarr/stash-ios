import SwiftUI
import NukeUI

/// Search screen for adding new content to Whisparr.
///
/// **Part of:** `WhisparrDashboard` (Search Tab)
struct WhisparrSearchView: View {
    @State private var viewModel: WhisparrSearchViewModel
    @EnvironmentObject var dependencyContainer: DependencyContainer
    @Environment(\.dismiss) var dismiss
    var onPerformerClick: ((String, String) -> Void)?
    var onStudioClick: ((Studio) -> Void)?
    
    init(viewModel: WhisparrSearchViewModel, onPerformerClick: ((String, String) -> Void)? = nil, onStudioClick: ((Studio) -> Void)? = nil) {
        _viewModel = State(wrappedValue: viewModel)
        self.onPerformerClick = onPerformerClick
        self.onStudioClick = onStudioClick
    }
    
    var body: some View {
        VStack {
            if viewModel.results.isEmpty && !viewModel.isSearching && viewModel.searchText.isEmpty {
                emptyStateView
            } else {
                searchResultsList
            }
        }
        .background(Color.stashBackground)
        .navigationTitle("Search Whisparr")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search for scenes...")
        .onAppear {
            // Pause queue polling to prevent list re-renders that break navigation
            WhisparrQueueService.shared.performRefresh = false
        }
        .onDisappear {
            // Resume queue polling when leaving
            WhisparrQueueService.shared.performRefresh = true
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Search Whisparr")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter a search term to find scenes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isSearching {
                    ForEach(0..<6) { _ in
                        SceneCardSkeleton()
                    }
                }
                
                ForEach(viewModel.results) { result in
                    NavigationLink(destination: WhisparrSearchResultDetailView(
                        viewModel: dependencyContainer.makeWhisparrSearchResultDetailViewModel(searchResult: result),
                        onPerformerClick: onPerformerClick,
                        onStudioClick: onStudioClick
                    )) {
                        WhisparrSearchResultCard(result: result)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.lightImpact()
                    })
                }
                
                // Show "No results" message if search completed with no results
                if !viewModel.isSearching && viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
                
                if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
    }
}

struct WhisparrSearchResultCard: View {
    let result: WhisparrSearchResult
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            infoSection
        }
        .background(Color.stashCardBackground)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var thumbnail: some View {
        if let imageUrlString = result.imageUrl, let imageUrl = URL(string: imageUrlString) {
            GeometryReader { geometry in
                LazyImage(url: imageUrl) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: settings.blurNsfw ? 20 : 0)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .aspectRatio(16/9, contentMode: .fill)
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                 if result.runtime > 0 {
                     Text("\(result.runtime)m")
                         .font(.caption2)
                         .bold()
                         .padding(4)
                         .background(Color.black.opacity(0.6))
                         .foregroundColor(.white)
                         .clipShape(RoundedRectangle(cornerRadius: 4))
                         .padding(4)
                 }
            }
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomTrailing) {
                     if result.runtime > 0 {
                         Text("\(result.runtime)m")
                             .font(.caption2)
                             .bold()
                             .padding(4)
                             .background(Color.black.opacity(0.6))
                             .foregroundColor(.white)
                             .clipShape(RoundedRectangle(cornerRadius: 4))
                             .padding(4)
                     }
                }
        }
    }
    
    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            HStack {
                if let studioTitle = result.studioTitle {
                    Text(studioTitle)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                if let releaseDate = result.releaseDate {
                    if result.studioTitle != nil {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    Text(formattedDate(from: releaseDate))
                        .font(.subheadline)
                        .foregroundColor(.white)
                } else {
                    if result.studioTitle != nil {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    Text("\(result.year)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            
            if !result.performerNames.isEmpty {
                Text(result.performerNames)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return DateFormatters.formatDateString(dateString)
    }
}



