import Foundation

struct Log: Codable, Identifiable, Hashable, Sendable {
    let time: String
    let level: LogLevel
    let message: String
    
    var id: String { time + message }
    
    enum CodingKeys: String, CodingKey {
        case time
        case level
        case message
    }
}

enum LogLevel: String, Codable, CaseIterable, Sendable {
    case trace, debug, info, warning, error, progress
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        switch string.lowercased() {
        case "trace": self = .trace
        case "debug": self = .debug
        case "info": self = .info
        case "warning", "warn": self = .warning
        case "error": self = .error
        case "progress": self = .progress
        default: self = .info
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.displayName.uppercased())
    }
    
    var displayName: String {
        switch self {
        case .trace: return "Trace"
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .progress: return "Progress"
        }
    }
    
    var color: String {
        switch self {
        case .trace: return "gray"
        case .debug: return "blue"
        case .info: return "green"
        case .warning: return "orange"
        case .error: return "red"
        case .progress: return "blue"
        }
    }
}

struct LogsResult: Codable, Sendable {
    let logs: [Log]?
}
