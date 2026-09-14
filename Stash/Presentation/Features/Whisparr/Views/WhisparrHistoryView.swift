import SwiftUI

/// A global history of Whisparr grabs/imports.
///
/// **Navigated from:** `WhisparrDashboard` (Tab)
struct WhisparrHistoryView: View {
    @State private var viewModel: WhisparrHistoryViewModel
    
    @MainActor
    init(viewModel: WhisparrHistoryViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            if viewModel.historyRecords.isEmpty && viewModel.isLoading {
                ProgressView("Loading History...")
            } else if let error = viewModel.errorMessage, viewModel.historyRecords.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        Task { await viewModel.loadHistory(reset: true) }
                    }
                    .buttonStyle(.bordered)
                }
            } else if viewModel.historyRecords.isEmpty {
                VStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No History Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.historyRecords) { record in
                            HistoryRow(record: record)
                                .onAppear {
                                    if record.id == viewModel.historyRecords.last?.id {
                                        Task {
                                            await viewModel.loadHistory()
                                        }
                                    }
                                }
                        }
                        
                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.loadHistory(reset: true)
                }
                .background(Color.stashBackground)
            }
        }
        .navigationTitle("History")
        .task {
            if viewModel.historyRecords.isEmpty {
                await viewModel.loadHistory(reset: true)
            }
        }
    }
}

struct HistoryRow: View {
    let record: WhisparrHistoryRecord
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail Image
            if let imageUrl = record.movie?.imageUrl, let url = URL(string: imageUrl) {
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
            
            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Event Type and Date
                HStack {
                    Text(eventTypeLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(eventTypeColor.opacity(0.2))
                        .foregroundColor(eventTypeColor)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text(formatDate(record.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Row 2: Title
                Text(record.sourceTitle ?? "Unknown Title")
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.white)
                
                // Row 3: Quality and Size
                HStack(spacing: 8) {
                    Text(record.quality.quality.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    
                    if let sizeStr = record.data?.size, let sizeInt = Int64(sizeStr) {
                        Text(formatSize(sizeInt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.stashCardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private var eventTypeLabel: String {
        if record.eventType == "downloadFolderImported" {
            return "Imported"
        }
        return record.eventType.capitalized
    }
    
    private var eventTypeColor: Color {
        switch record.eventType {
        case "grabbed": return .blue
        case "downloadFolderImported": return .green
        case "downloadFailed": return .red
        default: return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return dateString
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
