import Foundation
import os
import Combine

/// SignalR negotiation response
private struct NegotiationResponse: Codable {
    let connectionId: String
    let negotiateVersion: Int
    let availableTransports: [Transport]?
    
    struct Transport: Codable {
        let transport: String
        let transferFormats: [String]
    }
}

/// A reusable networking client for SignalR over WebSockets.
/// Handles connection lifecycle, protocol handshakes, keep-alive pings, and automatic reconnection.
final class SignalRWebSocketClient: Sendable {
    
    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(Int)
        case error(String)
    }
    
    private let logger = Logger(subsystem: "com.stash.app", category: "SignalR")
    private let webSocketTask = OSAllocatedUnfairLock<URLSessionWebSocketTask?>(uncheckedState: nil)
    private let pingTimer = OSAllocatedUnfairLock<Timer?>(uncheckedState: nil)
    private let stateSubject = CurrentValueSubject<State, Never>(.disconnected)
    
    // Hub subscription management
    private let handlers = OSAllocatedUnfairLock<[String: @Sendable (String) -> Void]>(uncheckedState: [:])
    private let connectionParams = OSAllocatedUnfairLock<(url: URL, apiKey: String)?>(uncheckedState: nil)
    private let retryCount = OSAllocatedUnfairLock<Int>(uncheckedState: 0)
    private let maxRetryDelay: TimeInterval = 30.0
    
    var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    init() {}
    
    // MARK: - Connection
    
    /// Connects to the Whisparr SignalR hub. This must be called before any subscriptions can be started.
    func connect(to url: URL, apiKey: String) {
        connectionParams.withLock { $0 = (url, apiKey) }
        retryCount.withLock { $0 = 0 }
        performConnect()
    }
    
    private func performConnect() {
        guard let (url, apiKey) = connectionParams.withLock({ $0 }) else { return }
        
        disconnectInternal()
        
        let state = retryCount.withLock { $0 } > 0 ? State.reconnecting(retryCount.withLock { $0 }) : State.connecting
        stateSubject.send(state)
        
        // Perform negotiation in background
        Task {
            await performNegotiationAndConnect(url: url, apiKey: apiKey)
        }
    }
    
    private func performNegotiationAndConnect(url: URL, apiKey: String) async {
        // Step 1: Negotiate connection
        logger.info("📡 Starting SignalR negotiation...")
        
        // Construct negotiate URL: baseURL + /signalr/messages/negotiate
        var negotiateURL = url
        negotiateURL.appendPathComponent("signalr")
        negotiateURL.appendPathComponent("messages")
        negotiateURL.appendPathComponent("negotiate")
        
        logger.info("📡 Negotiation URL: \(negotiateURL.absoluteString, privacy: .public)")
        
        var request = URLRequest(url: negotiateURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Negotiation failed: no HTTP response")
                stateSubject.send(.error("Negotiation failed"))
                scheduleReconnect()
                return
            }
            
            logger.info("📡 Negotiation response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                logger.info("📡 Negotiation response body: \(responseString, privacy: .public)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("❌ Negotiation failed with status \(httpResponse.statusCode)")
                stateSubject.send(.error("Negotiation failed"))
                scheduleReconnect()
                return
            }
            
            let negotiation = try JSONDecoder().decode(NegotiationResponse.self, from: data)
            logger.info("✅ Negotiation successful, connectionId: \(negotiation.connectionId)")
            
            // Step 2: Connect WebSocket with connection ID
            await connectWebSocket(baseUrl: url, connectionToken: negotiation.connectionId, apiKey: apiKey)
            
        } catch {
            logger.error("❌ Negotiation error: \(error.localizedDescription, privacy: .public)")
            stateSubject.send(.error(error.localizedDescription))
            scheduleReconnect()
        }
    }
    
    private func connectWebSocket(baseUrl: URL, connectionToken: String, apiKey: String) async {
        // Build WebSocket URL from base URL
        var wsUrl = baseUrl
        wsUrl.appendPathComponent("signalr")
        wsUrl.appendPathComponent("messages")
        
        var components = URLComponents(url: wsUrl, resolvingAgainstBaseURL: false)!
        components.scheme = baseUrl.scheme == "https" ? "wss" : "ws"
        components.queryItems = [
            URLQueryItem(name: "id", value: connectionToken)
        ]
        
        guard let finalWsUrl = components.url else {
            logger.error("Failed to construct SignalR WebSocket URL")
            stateSubject.send(.error("Invalid URL"))
            return
        }
        
        logger.info("📡 WebSocket URL: \(finalWsUrl.absoluteString, privacy: .public)")
        
        var request = URLRequest(url: finalWsUrl)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        
        logger.info("📡 Connecting to SignalR WebSocket...")
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 50 * 1024 * 1024
        
        webSocketTask.withLock { $0 = task }
        task.resume()
        
        // Send SignalR handshake message immediately
        // Format: {"protocol":"json","version":1}<record separator>
        let handshake = "{\"protocol\":\"json\",\"version\":1}\u{001E}"
        task.send(.string(handshake)) { [weak self] error in
            if let error = error {
                self?.logger.error("❌ Failed to send handshake: \(error.localizedDescription, privacy: .public)")
            } else {
                self?.logger.info("🤝 Sent SignalR handshake")
            }
        }
        
        receiveMessages(task: task)
    }
    
    func disconnect() {
        connectionParams.withLock { $0 = nil }
        handlers.withLock { $0.removeAll() }
        disconnectInternal()
        stateSubject.send(.disconnected)
    }
    
    private func disconnectInternal() {
        webSocketTask.withLock { task in
            task?.cancel(with: URLSessionWebSocketTask.CloseCode.normalClosure, reason: nil)
            task = nil
        }
        pingTimer.withLock { timer in
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func scheduleReconnect() {
        let count = retryCount.withLock { count -> Int in
            let newCount = count + 1
            retryCount.withLock { $0 = newCount }
            return newCount
        }
        
        let delay = min(pow(2.0, Double(count)), maxRetryDelay)
        logger.info("🔄 Reconnecting in \(delay)s (attempt #\(count))...")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            if self?.connectionParams.withLock({ $0 }) != nil {
                self?.performConnect()
            }
        }
    }
    
    // MARK: - Hub Subscriptions
    
    /// Subscribes to a SignalR hub method.
    func subscribe(hubMethod: String, handler: @Sendable @escaping (String) -> Void) {
        handlers.withLock { $0[hubMethod] = handler }
        logger.debug("📥 Subscribed to hub method: \(hubMethod)")
    }
    
    /// Invokes a SignalR hub method (client-to-server call)
    func invoke(hubMethod: String, arguments: [Any] = []) {
        let message: [String: Any] = [
            "H": "commandHub",  // Hub name
            "M": hubMethod,     // Method name
            "A": arguments,     // Arguments array
            "I": 0              // Invocation ID
        ]
        sendInternal(json: message)
    }
    
    // MARK: - Internal Communication
    
    private func sendInternal(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask.withLock { task in
            task?.send(URLSessionWebSocketTask.Message.string(string)) { [weak self] (error: Error?) in
                if let error = error {
                    self?.logger.error("❌ Send error: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    private func receiveMessages(task: URLSessionWebSocketTask) {
        task.receive { [weak self] (result: Result<URLSessionWebSocketTask.Message, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                self.webSocketTask.withLock { currentTask in
                    if let current = currentTask, current === task {
                        self.logger.error("❌ WebSocket failure: \(error.localizedDescription, privacy: .public)")
                        self.stateSubject.send(.error(error.localizedDescription))
                        self.scheduleReconnect()
                    }
                }
                
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleProtocolMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleProtocolMessage(text)
                    }
                @unknown default:
                    break
                }
                
                self.webSocketTask.withLock { currentTask in
                    if let current = currentTask, current === task {
                        self.receiveMessages(task: task)
                    }
                }
            }
        }
    }
    
    private func handleProtocolMessage(_ text: String) {
        logger.debug("📡 Received message: \(text, privacy: .public)")
        
        // SignalR messages can be empty (heartbeat) or JSON objects
        guard !text.isEmpty else { return }
        
        // SignalR sends "{}\u{001E}" for initialization acknowledgment
        if text.hasPrefix("{}") {
            logger.info("✅ SignalR connection established")
            retryCount.withLock { $0 = 0 }
            stateSubject.send(.connected)
            startPing()
            return
        }
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try stripping record separator and retry
            let cleanText = text.replacingOccurrences(of: "\u{001E}", with: "")
            guard let cleanData = cleanText.data(using: .utf8),
                  let cleanJson = try? JSONSerialization.jsonObject(with: cleanData) as? [String: Any] else {
                return
            }
            // Process the cleaned JSON
            if let type = cleanJson["type"] as? Int, type == 1,
               let target = cleanJson["target"] as? String {
                if let handler = handlers.withLock({ $0[target] }) {
                    handler(cleanText)
                }
            }
            return
        }
        
        // Whisparr SignalR format: {"type": 1, "target": "receiveMessage", "arguments": [...]}
        if let type = json["type"] as? Int, type == 1,
           let target = json["target"] as? String {
            logger.info("📡 SignalR message - target: \(target)")
            
            // Log message details
            if let arguments = json["arguments"] as? [[String: Any]],
               let firstArg = arguments.first,
               let name = firstArg["name"] as? String,
               let action = firstArg["action"] as? String {
                logger.info("📬 Event type: \(name), action: \(action)")
            }
            
            // This is a SignalR invocation message
            let handlerExists = handlers.withLock { $0[target] != nil }
            logger.info("🔍 Looking for handler for target '\(target)': \(handlerExists ? "FOUND" : "NOT FOUND")")
            
            if let handler = handlers.withLock({ $0[target] }) {
                logger.info("🚀 Invoking handler for target '\(target)'")
                handler(text)
                logger.info("✅ Handler invocation completed for target '\(target)'")
            } else {
                logger.warning("⚠️ No handler registered for target: \(target)")
                let registeredTargets = handlers.withLock { Array($0.keys) }
                logger.info("📋 Registered targets: \(registeredTargets.joined(separator: ", "))")
            }
            
            // If this is the first message, mark as connected
            if target == "receiveMessage" && stateSubject.value != .connected {
                logger.info("✅ SignalR connection established (received first message)")
                retryCount.withLock { $0 = 0 }
                stateSubject.send(.connected)
                startPing()
            }
        }
        
        // Legacy SignalR hub format: {"H": "hubName", "M": "methodName", "A": [args]}
        if let methodName = json["M"] as? String {
            if let handler = handlers.withLock({ $0[methodName] }) {
                handler(text)
            }
        }
    }
    
    private func startPing() {
        pingTimer.withLock { timer in
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.webSocketTask.withLock { task in
                    task?.sendPing { error in
                        if let error = error {
                            self?.logger.error("❌ Ping failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }
        }
    }
}
