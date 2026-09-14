import Foundation

/// Command payload for Whisparr API
struct WhisparrSearchCommand: Codable {
    let name: String
    let movieIds: [Int]
}

/// Represents a command being executed by Whisparr
struct WhisparrCommand: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let commandName: String
    let message: String?
    let body: CommandBody?
    let priority: String
    let status: CommandStatus
    let queued: Date?
    let started: Date?
    let ended: Date?
    let duration: String?
    let exception: String?
    let trigger: String
    
    enum CommandStatus: String, Codable {
        case queued
        case started
        case completed
        case failed
        case aborted
        case cancelled
        case orphaned
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var isActive: Bool {
            self == .queued || self == .started
        }
        
        var isCompleted: Bool {
            self == .completed || self == .failed || self == .aborted || self == .cancelled
        }
    }
    
    struct CommandBody: Codable, Equatable {
        let sendUpdatesToClient: Bool?
        let updateScheduledTask: Bool?
        let completionMessage: String?
        let requiresDiskAccess: Bool?
        let isExclusive: Bool?
        let isTypeExclusive: Bool?
        let name: String?
        let trigger: String?
    }
    
    /// Computed property for duration display
    var formattedDuration: String? {
        if let duration = duration {
            return duration
        }
        
        guard let started = started else { return nil }
        let end = ended ?? Date()
        let interval = end.timeIntervalSince(started)
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Computed property for timestamp display
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        if let started = started {
            return formatter.localizedString(for: started, relativeTo: Date())
        } else if let queued = queued {
            return "Queued \(formatter.localizedString(for: queued, relativeTo: Date()))"
        }
        return "Unknown"
    }
}
