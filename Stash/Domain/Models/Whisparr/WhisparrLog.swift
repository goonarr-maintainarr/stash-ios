import Foundation
import Combine

struct WhisparrLog: Codable, Identifiable, Hashable {
    let time: String
    let level: String
    let logger: String?
    let message: String?
    let exception: String?
    let exceptionType: String?
    
    var id: String { time + (message ?? "") + (logger ?? "") }
    
    var logLevel: WhisparrLogLevel {
        WhisparrLogLevel(rawValue: level.capitalized) ?? .info
    }
    
    var displayMessage: String {
        if let msg = message {
            return msg
        }
        if let exc = exception {
            return exc
        }
        return logger ?? "Unknown"
    }
}

enum WhisparrLogLevel: String, Codable {
    case trace = "Trace"
    case debug = "Debug"
    case info = "Info"
    case warn = "Warn"
    case error = "Error"
    case fatal = "Fatal"
    
    var color: String {
        switch self {
        case .trace: return "gray"
        case .debug: return "blue"
        case .info: return "green"
        case .warn: return "orange"
        case .error: return "red"
        case .fatal: return "purple"
        }
    }
}

struct WhisparrLogFile: Codable {
    let filename: String
    let lastWriteTime: String
    let downloadUrl: String
}

struct WhisparrLogFileResponse: Codable {
    let logFiles: [WhisparrLogFile]
}
