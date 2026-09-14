import os
import SwiftUI

/// A self-contained section that displays Whisparr activity via SignalR real-time updates.

private let logger = Logger(subsystem: "com.stash.app", category: "WhisparrLogsSection")

/// Displays logs from the Whisparr integration.
///
/// **Used by:** `SettingsView` (debug purposes)
struct WhisparrLogsSection: View {
    @EnvironmentObject var store: SettingsStore
    
    var body: some View {
        // Only show if Whisparr is configured
        if !store.whisparrUrl.isEmpty && !store.whisparrApiKey.isEmpty {
            WhisparrActivitySectionContent()
        }
    }
}

// MARK: - Inner Content View (Observes SignalR Service)

private struct WhisparrActivitySectionContent: View {
    @EnvironmentObject var store: SettingsStore
    // Use @State to properly observe the @Observable service
    @State private var service = WhisparrSignalRService.shared
    @State private var isExpanded = false
    
    var body: some View {
        let _ = logger.debug("🔄 WhisparrActivitySectionContent.body evaluated (activities: \(service.activities.count), connected: \(service.isConnected))")
        Section(header: HStack {
            Text("Whisparr Activity")
            Spacer()
            ConnectionBadge(isConnected: service.isConnected)
        }) {
            if service.activities.isEmpty {
                if service.isConnected {
                    Text("Waiting for activity...")
                        .foregroundColor(.secondary)
                } else {
                    Text("Connecting...")
                        .foregroundColor(.secondary)
                }
            } else {
                ActivityList(activities: Array(service.activities.prefix(isExpanded ? 20 : 5)))
                
                if service.activities.count > 5 {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(isExpanded ? "Show Less" : "Show More (\(service.activities.count) total)")
                                .font(.caption)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .listRowBackground(Color.stashCardBackground)
    }
}

// MARK: - Connection Badge

private struct ConnectionBadge: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(isConnected ? "Live" : "...")
                .font(.caption2)
                .foregroundColor(isConnected ? .green : .secondary)
        }
    }
}

// MARK: - Activity List

private struct ActivityList: View {
    let activities: [WhisparrActivity]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(activities) { activity in
                ActivityRow(activity: activity)
                if activity.id != activities.last?.id {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Activity Row View

private struct ActivityRow: View {
    let activity: WhisparrActivity
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: activity.eventType.icon)
                .font(.caption)
                .foregroundColor(statusColor)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(activity.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(Self.timeFormatter.string(from: activity.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let detail = activity.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let status = activity.status {
                    Text(status.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        guard let status = activity.status else { return .secondary }
        switch status {
        case .started: return .blue
        case .completed: return .green
        case .failed: return .red
        case .updated: return .orange
        }
    }
}
