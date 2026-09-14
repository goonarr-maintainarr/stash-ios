import SwiftUI

/// A screen for selecting/following tags.
///
/// **Navigated from:** `HomeView` (via "Edit Tags" in header)
struct TagSelectionView: View {
    @State private var viewModel: TagSelectionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var tagToDelete: Tag?
    
    init(viewModel: TagSelectionViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
    
    private var navigationTitle: String {
        if viewModel.totalTagCount > 0 {
            return "Manage Tags · \(viewModel.totalTagCount.formatted())"
        }
        return "Manage Tags"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !viewModel.selectedTags.isEmpty {
                    sectionHeader("Followed Tags")
                    
                    ForEach(viewModel.selectedTags) { tag in
                        TagCard(
                            tag: tag,
                            isSelected: true,
                            onTap: { viewModel.toggleFollow(tag: tag) },
                            onDelete: {
                                tagToDelete = tag
                                showDeleteConfirmation = true
                            }
                        )
                    }
                    .padding(.horizontal)
                }
                
                sectionHeader("All Tags")
                
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 100)
                case .error(let message):
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                case .empty:
                    ContentUnavailableView("No Tags", systemImage: "tag.slash")
                        .padding()
                case .content:
                    ForEach(viewModel.tags) { tag in
                        TagCard(
                            tag: tag,
                            isSelected: viewModel.isFollowing(tagId: tag.id),
                            onTap: { viewModel.toggleFollow(tag: tag) },
                            onDelete: {
                                tagToDelete = tag
                                showDeleteConfirmation = true
                            }
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.stashBackground)
        .searchable(text: $viewModel.searchText, prompt: "Search tags")
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.fetchItems()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("OK") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .confirmationDialog(
            "Delete \"\(tagToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if let tag = tagToDelete {
                        await viewModel.deleteTag(tag)
                    }
                    tagToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
        } message: {
            Text("This action cannot be undone. The tag will be removed from all scenes.")
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct TagCard: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.lightImpact()
            onTap()
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tag.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let count = tag.scene_count {
                        Text("\(count) scenes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let description = tag.description, !description.isEmpty {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.stashCardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Tag", systemImage: "trash")
            }
        }
    }
}
