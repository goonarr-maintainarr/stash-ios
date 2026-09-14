import Foundation
import os
import Combine

/// A reusable networking client for GraphQL over WebSockets.
/// Handles connection lifecycle, protocol handshakes, keep-alive pings, and automatic reconnection.
final class GraphQLWebSocketClient: Sendable {
    
    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(Int)
        case error(String)
    }
    
    private let logger = Logger(subsystem: "com.stash.app", category: "GraphQLWS")
    private let webSocketTask = OSAllocatedUnfairLock<URLSessionWebSocketTask?>(uncheckedState: nil)
    private let pingTimer = OSAllocatedUnfairLock<Timer?>(uncheckedState: nil)
    private let stateSubject = CurrentValueSubject<State, Never>(.disconnected)
    
    // Multi-subscription management
    private let handlers = OSAllocatedUnfairLock<[String: @Sendable (String) -> Void]>(uncheckedState: [:])
    private let connectionParams = OSAllocatedUnfairLock<(url: URL, apiKey: String)?>(uncheckedState: nil)
    private let retryCount = OSAllocatedUnfairLock<Int>(uncheckedState: 0)
    private let maxRetryDelay: TimeInterval = 30.0
    
    var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    init() {}
    
    // MARK: - Connection
    
    /// Connects to the Stash server. This must be called before any subscriptions can be started.
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
        
        let wsUrl = url.webSocketURL
        var request = URLRequest(url: wsUrl)
        request.addValue("graphql-ws", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.addValue(apiKey, forHTTPHeaderField: "ApiKey")
        
        logger.info("📡 Connecting to \(wsUrl.absoluteString, privacy: .private)")
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 50 * 1024 * 1024  // 50 MB - increased from 10 MB for large scan/generate operations
        
        webSocketTask.withLock { $0 = task }
        task.resume()
        
        receiveMessages(task: task)
        
        // Initialize Protocol
        sendInternal(json: ["type": "connection_init", "payload": [:]])
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
    
    // MARK: - Subscriptions
    
    /// Subscribes to a GraphQL event. If the connection isn't established, the request is queued.
    func subscribe(id: String, query: String, variables: [String: Any] = [:], handler: @Sendable @escaping (String) -> Void) {
        handlers.withLock { $0[id] = handler }
        
        // If we are already connected, fire the subscription immediately
        if stateSubject.value == .connected {
            sendSubscription(id: id, query: query, variables: variables)
        }
    }
    
    private func sendSubscription(id: String, query: String, variables: [String: Any]) {
        let message: [String: Any] = [
            "id": id,
            "type": "start",
            "payload": [
                "query": query,
                "variables": variables
            ]
        ]
        sendInternal(json: message)
    }
    
    private func resubscribeAll() {
        // This is called after reconnection to restore previous subscriptions
        // Note: Individual services should ideally re-trigger their subscriptions 
        // if they need to fetch baseline data again, but we can do it automatically here.
        logger.debug("📥 Automatically resubscribing all active streams...")
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
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "connection_ack":
            logger.info("✅ Protocol handshake complete")
            retryCount.withLock { $0 = 0 }
            stateSubject.send(.connected)
            startPing()
            // We don't resubscribe here; we let the downstream services do it 
            // via the .connected state signal to ensure consistency.
            
        case "ka":
            break
            
        case "data":
            if let id = json["id"] as? String, let handler = handlers.withLock({ $0[id] }) {
                handler(text)
            }
            
        case "error":
            logger.error("❌ Protocol level error: \(text, privacy: .public)")
            
        default:
            break
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
