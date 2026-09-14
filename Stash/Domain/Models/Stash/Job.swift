import Foundation

struct Job: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let addTime: String? // Changed to optional as subscription might not send it
    let description: String? // Changed to optional
    let status: JobStatus
    let progress: Double?
    let startTime: String?
    let endTime: String?
    let error: String?
    let subTasks: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case addTime
        case description
        case status
        case progress
        case startTime
        case endTime
        case error
        case subTasks
    }
    
    var isCompleted: Bool {
        status == .finished || status == .failed || status == .cancelled
    }
}

enum JobStatus: String, Codable {
    case ready = "READY"
    case running = "RUNNING"
    case stopping = "STOPPING"
    case cancelled = "CANCELLED"
    case finished = "FINISHED"
    case failed = "FAILED"
    
    var displayName: String {
        switch self {
        case .ready: return "Ready"
        case .running: return "Running"
        case .stopping: return "Stopping"
        case .cancelled: return "Cancelled"
        case .finished: return "Finished"
        case .failed: return "Failed"
        }
    }
    
    var color: String {
        switch self {
        case .ready: return "blue"
        case .running: return "green"
        case .stopping: return "orange"
        case .cancelled: return "gray"
        case .finished: return "blue"
        case .failed: return "red"
        }
    }
}

struct JobQueueResult: Codable {
    let jobQueue: [Job]?
}
