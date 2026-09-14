import Foundation
import Combine

struct WhisparrQueueItem: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let movieId: Int
    let title: String
    let size: Int64
    let sizeleft: Int64
    let status: String
    let trackedDownloadStatus: String?
    let statusMessages: [WhisparrQueueStatusMessage]?
    let downloadId: String?
    let downloadProtocol: String?
    let downloadClient: String?
    let indexer: String?
    let outputPath: String?
    let timeleft: String?
    let estimatedCompletionTime: String?
    let movie: WhisparrQueueMovie?
    
    enum CodingKeys: String, CodingKey {
        case id, movieId, title, size, sizeleft, status
        case trackedDownloadStatus, statusMessages, downloadId
        case downloadProtocol = "protocol"
        case downloadClient, indexer, outputPath, timeleft, estimatedCompletionTime
        case movie
    }
    
    var progress: Double {
        guard size > 0 else { return 0 }
        let downloaded = size - sizeleft
        return Double(downloaded) / Double(size) * 100
    }
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var remainingString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeleft)
    }
    
    var displayStatus: String {
        // Use tracked status if available and meaningful
        if let tracked = trackedDownloadStatus, !tracked.isEmpty, tracked.lowercased() != "ok" {
            // Split CamelCase for display if needed, or just return as is.
            // valid states: Downloading, ImportPending, Importing, Imported, FailedPending, Failed, Ignored
            // We'll add spaces for readability: "ImportPending" -> "Import Pending"
            return tracked.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression, range: tracked.index(after: tracked.startIndex)..<tracked.endIndex).trimmingCharacters(in: .whitespaces)
        }
        
        // Fallback to queue item status
        if status.lowercased() == "completed" {
            return "Waiting to Import"
        }
        
        return status
    }
}

struct WhisparrQueueStatusMessage: Codable, Equatable, Hashable {
    let title: String
    let messages: [String]
}

struct WhisparrQueueResponse: Codable {
    let page: Int
    let pageSize: Int
    let sortKey: String
    let sortDirection: String
    let totalRecords: Int
    let records: [WhisparrQueueItem]
}

struct WhisparrQueueMovie: Codable, Equatable, Hashable {
    let id: Int
    let title: String
    let images: [WhisparrImage]?
    
    var imageUrl: String? {
        images?.first(where: { $0.coverType == "screenshot" })?.remoteUrl
    }
}
