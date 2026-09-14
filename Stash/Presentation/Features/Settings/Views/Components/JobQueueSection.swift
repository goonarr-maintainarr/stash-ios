import SwiftUI

/// A self-contained section that displays the Stash job queue.
/// Uses an inner view with explicit observation to fully isolate from parent.
/// Displays active and completed server background jobs.
///
/// **Used by:** `SettingsView`
struct JobQueueSection: View {
    var body: some View {
        JobQueueSectionContent()
    }
}

// MARK: - Inner Content View (Handles All Observation)

/// This view observes ONLY the jobs state, not the entire service.
/// By being a separate struct, it isolates observation from the parent Form.
private struct JobQueueSectionContent: View {
    // Observe jobsState directly (it's @Observable)
    @State private var jobsState = StashSubscriptionService.shared.jobsState
    // Manually track connection state to avoid observing the entire ObservableObject service
    @State private var isConnected = false
    
    private let service = StashSubscriptionService.shared
    
    var body: some View {
        Section(header: HStack {
            Text("Task Queue")
            if jobsState.jobs.contains(where: { $0.status == .running || $0.status == .ready }) {
                Button(action: {
                    Task {
                        try? await service.stopAllJobs()
                    }
                }) {
                    Image(systemName: "stop.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            Spacer()
            ConnectionStatusBadge(isConnected: isConnected)
        }) {
            JobListContent(jobs: jobsState.jobs)
        }
        .onReceive(service.$isConnected) { isConnected = $0 }
        .onAppear { isConnected = service.isConnected }
    }
}

// MARK: - Connection Status Badge (Static - No Observation)

private struct ConnectionStatusBadge: View {
    let isConnected: Bool
    
    var body: some View {
        if isConnected {
            Text("Connected")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Text("Disconnected")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Job List Content (Static - No Observation)

private struct JobListContent: View {
    let jobs: [Job]
    
    var body: some View {
        if jobs.isEmpty {
            Text("No active tasks")
                .foregroundColor(.secondary)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(jobs) { job in
                        JobRowView(job: job)
                            .id(job.id)
                        if job.id != jobs.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

// MARK: - Job Row View

struct JobRowView: View, Equatable {
    let job: Job
    
    // MARK: - Cached Formatters
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Equatable conformance - only redraws when these specific properties change
    static func == (lhs: JobRowView, rhs: JobRowView) -> Bool {
        lhs.job.id == rhs.job.id &&
        lhs.job.status == rhs.job.status &&
        lhs.job.progress == rhs.job.progress &&
        lhs.job.description == rhs.job.description &&
        lhs.job.subTasks == rhs.job.subTasks &&
        lhs.job.error == rhs.job.error &&
        lhs.job.endTime == rhs.job.endTime
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(colorForStatus(job.status))
                    .frame(width: 8, height: 8)
                Text(job.description ?? "Unknown Job")
                    .font(.body)
                Spacer()
                Text(job.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let progress = job.progress, progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Show subtasks if available
            if let subtasks = job.subTasks, !subtasks.isEmpty {
                ForEach(subtasks, id: \.self) { task in
                    Text(task)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
            }
            
            // Show error if failed
            if let error = job.error {
               Text(error)
                   .font(.caption)
                   .foregroundColor(.red)
            }
            
            // Show timing info for completed tasks
            if job.isCompleted {
                if let endTime = job.endTime {
                    Text("Completed: \(formatDate(endTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func colorForStatus(_ status: JobStatus) -> Color {
        switch status {
        case .ready: return .blue
        case .running: return .green
        case .stopping: return .orange
        case .cancelled: return .gray
        case .finished: return .blue
        case .failed: return .red
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        guard let date = Self.iso8601Formatter.date(from: dateString) else {
            return dateString
        }
        return Self.timeFormatter.string(from: date)
    }
}
