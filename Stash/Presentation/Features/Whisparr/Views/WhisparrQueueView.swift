import SwiftUI
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrQueueView")

/// The active download queue for Whisparr.
///
/// **Navigated from:** `WhisparrDashboard` (Queue Tab)
struct WhisparrQueueView: View {
    var queue: WhisparrQueueService = .shared
    @State private var selectedItem: WhisparrQueueItem?
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    var body: some View {
        list
            .overlay {
                if queue.items.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshQueue()
            }
            .sheet(item: $selectedItem) { item in
                WhisparrQueueItemDetailView(item: item, queue: queue)
            }
            .onAppear {
                logger.info("📱 WhisparrQueueView appeared - enabling polling (performRefresh=true)")
                queue.performRefresh = true
            }
            .onDisappear {
                logger.info("📱 WhisparrQueueView disappeared - disabling polling (performRefresh=false)")
                queue.performRefresh = false
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        WhisparrHistoryView(viewModel: WhisparrHistoryViewModel())
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.lightImpact()
                    })
                }
            }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Active Downloads")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Downloads from Whisparr will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stashBackground)
    }
    
    // MARK: - List View
    
    @ViewBuilder
    private var list: some View {
        List {
            Section {
                ForEach(queue.items) { item in
                    Button {
                        selectedItem = item
                        HapticManager.lightImpact()
                    } label: {
                        WhisparrQueueItemRow(item: item)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            } header: {
                HStack {
                    Text("\(queue.items.count) \(queue.items.count == 1 ? "Task" : "Tasks")")
                    
                    Spacer()
                    
                    // Loading indicator
                    if queue.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    // Issues badge
                    if queue.itemsWithIssues > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("\(queue.itemsWithIssues)")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.stashBackground)
    }
    
    // MARK: - Actions
    
    private func refreshQueue() async {
        await queue.fetchQueue()
    }
}

// MARK: - Queue Item Row

struct WhisparrQueueItemRow: View {
    let item: WhisparrQueueItem
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail Image
            if let imageUrl = item.movie?.imageUrl, let url = URL(string: imageUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 120, height: 80)
                .blur(radius: settings.blurNsfw ? 20 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Placeholder when no image
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title Line
                Text(item.movie?.title ?? item.title)
                    .font(.headline.monospacedDigit())
                    .fontWeight(.semibold)
                    .truncationMode(.middle)
                
                // Status Line
                HStack(spacing: 6) {
                    Text(item.displayStatus)
                        .foregroundColor(statusColor)
                    
                    // Progress (only when downloading/importing)
                    if item.progress > 0 {
                        Bullet()
                        Text(String(format: "%.1f%%", item.progress))
                            .monospacedDigit()
                    }
                    
                    // Issue indicator on right
                    if let messages = item.statusMessages, !messages.isEmpty {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .imageScale(.small)
                            .foregroundColor(.orange)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                
                // Time remaining on new line
                if item.progress > 0, let remaining = item.timeleft {
                    Text(remaining + " remaining")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stashCardBackground)
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
    
    private var statusColor: Color {
        switch item.status.lowercased() {
        case "downloading", "queued":
            return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "paused":
            return .orange
        case "completed":
            return .green
        case "failed":
            return .red
        case "warning":
            return .yellow
        default:
            return .gray
        }
    }
}

// Simple bullet separator component
struct Bullet: View {
    var body: some View {
        Text("·")
            .font(.subheadline)
    }
}
