import Foundation
import os
import Combine
import Observation

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrSignalRService")

/// Activity item from Whisparr SignalR
struct WhisparrActivity: Identifiable, Equatable, Codable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let title: String
    let detail: String?
    let status: Status?
    
    init(id: UUID = UUID(), timestamp: Date, eventType: EventType, title: String, detail: String?, status: Status?) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.title = title
        self.detail = detail
        self.status = status
    }
    
    enum EventType: String, Codable {
        case command = "command"
        case movie = "movie"
        case system = "system/task"
        case unknown = "unknown"
        
        var icon: String {
            switch self {
            case .command: return "gearshape"
            case .movie: return "film"
            case .system: return "arrow.triangle.2.circlepath"
            case .unknown: return "questionmark"
            }
        }
    }
    
    enum Status: String, Codable {
        case started
        case completed
        case failed
        case updated
    }
}

/// Whisparr SignalR service for real-time activity updates.
/// Maintains a SignalR connection to Whisparr and broadcasts activity events.
@MainActor
@Observable
final class WhisparrSignalRService {
    
    /// Singleton instance
    static let shared = WhisparrSignalRService()
    
    // MARK: - Observable State
    
    var activities: [WhisparrActivity] = []
    var isConnected = false
    var connectionState: String = "Disconnected"
    
    // MARK: - Private Properties
    
    private let signalRClient = SignalRWebSocketClient()
    private var cancellables = Set<AnyCancellable>()
    private let maxActivities = 50
    
    private static var activitiesFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("whisparr_activities.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadActivitiesFromFile()
        setupSignalRSubscriptions()
        logger.info("🌐 WhisparrSignalRService initialized with \(self.activities.count) cached activities")
    }
    
    // MARK: - Connection Management
    
    func connect(url: String, apiKey: String) {
        guard !url.isEmpty, !apiKey.isEmpty else {
            logger.warning("Cannot connect: Whisparr URL or API key not configured")
            return
        }
        
        guard let whisparrUrl = URL(string: url) else {
            logger.error("Invalid Whisparr URL: \(url)")
            return
        }
        
        logger.info("📡 Connecting to SignalR hub at \(whisparrUrl.absoluteString, privacy: .public)")
        signalRClient.connect(to: whisparrUrl, apiKey: apiKey)
    }
    
    func disconnect() {
        logger.info("🔌 Disconnecting from Whisparr SignalR hub...")
        signalRClient.disconnect()
        isConnected = false
        connectionState = "Disconnected"
    }
    
    // MARK: - SignalR Subscriptions
    
    private func setupSignalRSubscriptions() {
        // Subscribe to state changes
        signalRClient.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isConnected = state == .connected
                    
                    switch state {
                    case .disconnected:
                        self.connectionState = "Disconnected"
                    case .connecting:
                        self.connectionState = "Connecting..."
                    case .connected:
                        self.connectionState = "Connected"
                    case .reconnecting(let attempt):
                        self.connectionState = "Reconnecting (\(attempt))..."
                    case .error(let message):
                        self.connectionState = "Error: \(message)"
                    }
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to hub messages
        signalRClient.subscribe(hubMethod: "receiveMessage") { [weak self] messageJson in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleHubMessage(messageJson)
            }
        }
    }
    
    // MARK: - Message Handling
    
    func handleHubMessage(_ json: String) {
        guard let data = json.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arguments = envelope["arguments"] as? [[String: Any]],
              let firstArg = arguments.first,
              let name = firstArg["name"] as? String else {
            logger.debug("❌ Failed to parse SignalR message")
            return
        }
        
        let action = firstArg["action"] as? String
        let body = firstArg["body"] as? [String: Any]
        
        switch name {
        case "command":
            handleCommandEvent(body: body, action: action)
        case "movie":
            handleMovieEvent(body: body, action: action)
        case "system/task":
            handleSystemEvent(body: body, action: action)
        case "version":
            if let version = body?["version"] as? String {
                logger.debug("ℹ️ Whisparr Version: \(version)")
            }
            
        case "queue", "queue/details":
            // These just indicate something changed in the queue
            // We can log it as a debug event, or update a timestamp if we wanted to be reactive
            logger.debug("📥 Queue update received: \(name) (\(action ?? "unknown"))")
            
        case "queue/status":
            // Status update (e.g. counts)
            if let resource = body?["resource"] as? [String: Any] {
                logger.debug("📥 Queue Status: \(resource)")
            } else {
                logger.debug("📥 Queue Status update received")
            }
            
        default:
            logger.debug("⚠️ Unhandled event type: \(name)")
        }
    }
    
    private func handleCommandEvent(body: [String: Any]?, action: String?) {
        guard let resource = body?["resource"] as? [String: Any] else { return }
        
        let commandName = resource["commandName"] as? String ?? "Command"
        let message = resource["message"] as? String ?? ""
        let statusStr = resource["status"] as? String ?? ""
        
        let status: WhisparrActivity.Status? = {
            switch statusStr {
            case "started": return .started
            case "completed": return .completed
            case "failed": return .failed
            default: return .updated
            }
        }()
        
        // Suppress "Refresh Monitored Downloads" from the UI log unless it failed
        // It runs too frequently (every 2.5s) and spamming the UI list is bad UX
        if commandName == "Refresh Monitored Downloads" && status != .failed {
            logger.debug("⚙️ Refresh Monitored Downloads - \(statusStr)")
            return
        }
        
        let activity = WhisparrActivity(
            timestamp: Date(),
            eventType: .command,
            title: commandName,
            detail: message.isEmpty ? nil : message,
            status: status
        )
        
        addActivity(activity)
        logger.info("⚙️ Command: \(commandName) - \(statusStr)")
    }
    
    private func handleMovieEvent(body: [String: Any]?, action: String?) {
        guard let resource = body?["resource"] as? [String: Any] else { return }
        
        let title = resource["title"] as? String ?? "Movie"
        
        let activity = WhisparrActivity(
            timestamp: Date(),
            eventType: .movie,
            title: title,
            detail: action,
            status: .updated
        )
        
        addActivity(activity)
        logger.info("🎬 Movie: \(title) - \(action ?? "")")
        
        // Broadcast update to view models
        if let id = resource["id"] as? Int {
             NotificationCenter.default.post(
                name: .whisparrMovieUpdated,
                object: nil,
                userInfo: ["movieId": id]
            )
        }
    }
    
    private func handleSystemEvent(body: [String: Any]?, action: String?) {
        // System tasks like "sync" are noisy, log as debug and don't add to UI
        logger.debug("🔄 System: \(action ?? "sync")")
    }
    
    func addActivity(_ activity: WhisparrActivity) {
        // Insert at beginning (most recent first)
        activities.insert(activity, at: 0)
        
        // Cap at maxActivities
        if activities.count > maxActivities {
            activities = Array(activities.prefix(maxActivities))
        }
        
        // Persist to file
        saveActivitiesToFile()
    }
    
    /// Clear all activities
    func clearActivities() {
        activities.removeAll()
        saveActivitiesToFile()
    }
    
    // MARK: - File Persistence
    
    private func loadActivitiesFromFile() {
        let fileURL = Self.activitiesFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.debug("📂 No activities file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            activities = try JSONDecoder().decode([WhisparrActivity].self, from: data)
            logger.info("📂 Loaded \(self.activities.count) activities from file")
        } catch {
            logger.error("❌ Failed to load activities: \(error.localizedDescription)")
        }
    }
    
    private func saveActivitiesToFile() {
        let fileURL = Self.activitiesFileURL
        
        do {
            let data = try JSONEncoder().encode(activities)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("❌ Failed to save activities: \(error.localizedDescription)")
        }
    }
}
