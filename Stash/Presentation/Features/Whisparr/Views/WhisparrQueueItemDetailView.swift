import os
import SwiftUI


private let logger = Logger(subsystem: "com.stash.app", category: "WhisparrQueueItemDetailView")

/// Details for a specific item in the Whisparr Queue.
///
/// **Navigated from:** `WhisparrQueueView`
struct WhisparrQueueItemDetailView: View {
    let initialItem: WhisparrQueueItem
    var queue: WhisparrQueueService = .shared
    @Environment(\.dismiss) private var dismiss
    
    private var item: WhisparrQueueItem {
        queue.items.first { $0.id == initialItem.id } ?? initialItem
    }
    
    init(item: WhisparrQueueItem, queue: WhisparrQueueService = .shared) {
        self.initialItem = item
        self.queue = queue
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Thumbnail Image
                    if let imageUrl = item.movie?.imageUrl, let url = URL(string: imageUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                            Text(item.status)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.stashCardBackground)
                    .cornerRadius(12)
                    
                    // Progress section
                    if item.progress > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progress")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                ProgressView(value: item.progress, total: 100)
                                    .progressViewStyle(LinearProgressViewStyle())
                                
                                HStack {
                                    Text("\(Int(item.progress))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let timeLeft = item.timeleft {
                                        Text(timeLeft + " remaining")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.stashCardBackground)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Download info section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Download Info")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            if let downloadClient = item.downloadClient {
                                InfoRow(label: "Client", value: downloadClient)
                                Divider()
                            }
                            
                            if let indexer = item.indexer {
                                InfoRow(label: "Indexer", value: indexer)
                                Divider()
                            }
                            
                            if let downloadProtocol = item.downloadProtocol {
                                InfoRow(label: "Protocol", value: downloadProtocol.uppercased())
                                Divider()
                            }
                            
                            InfoRow(label: "Size", value: item.sizeString)
                            
                            if item.sizeleft > 0 {
                                Divider()
                                InfoRow(label: "Remaining", value: item.remainingString)
                            }
                        }
                        .padding()
                        .background(Color.stashCardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Status messages section
                    if let statusMessages = item.statusMessages, !statusMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Issues")
                                    .font(.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(statusMessages, id: \.title) { statusMessage in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(statusMessage.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        
                                        ForEach(statusMessage.messages, id: \.self) { message in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("•")
                                                    .foregroundColor(.secondary)
                                                Text(message)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.stashBackground)
            .navigationTitle("Queue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        Task {
                            do {
                                try await queue.removeFromQueue(itemId: item.id)
                                HapticManager.success()
                                dismiss()
                            } catch {
                                logger.error("Failed to remove from queue: \(error)")
                                HapticManager.error()
                            }
                        }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
            }
        }
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
