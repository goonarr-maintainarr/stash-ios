import SwiftUI

/// Row view for displaying a Whisparr command with progress
struct WhisparrCommandRow: View {
    let command: WhisparrCommand
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and Status
            HStack {
                Text(command.message ?? command.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Spacer()
                
                statusBadge
            }
            
            // Progress info
            HStack(spacing: 6) {
                Text(command.formattedTimestamp)
                    .foregroundColor(.secondary)
                
                if let duration = command.formattedDuration {
                    Bullet()
                    Text(duration)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Spacer()
            }
            .font(.subheadline)
            
            // Progress bar (if queued or started)
            if command.status.isActive {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(statusColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stashCardBackground)
        .cornerRadius(12)
    }
    
    private var statusBadge: some View {
        Text(command.status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch command.status {
        case .queued:
            return .blue
        case .started:
            return .green
        case .completed:
            return .blue
        case .failed, .aborted:
            return .red
        case .cancelled:
            return .orange
        case .orphaned:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        WhisparrCommandRow(command: WhisparrCommand(
            id: 1,
            name: "RefreshMovie",
            commandName: "RefreshMovie",
            message: "Refreshing movie metadata",
            body: nil,
            priority: "normal",
            status: .started,
            queued: Date().addingTimeInterval(-60),
            started: Date().addingTimeInterval(-30),
            ended: nil,
            duration: nil,
            exception: nil,
            trigger: "manual"
        ))
        
        WhisparrCommandRow(command: WhisparrCommand(
            id: 2,
            name: "RssSync",
            commandName: "RssSync",
            message: "Syncing RSS feeds",
            body: nil,
            priority: "normal",
            status: .queued,
            queued: Date(),
            started: nil,
            ended: nil,
            duration: nil,
            exception: nil,
            trigger: "scheduled"
        ))
    }
    .padding()
    .background(Color.stashBackground)
}
