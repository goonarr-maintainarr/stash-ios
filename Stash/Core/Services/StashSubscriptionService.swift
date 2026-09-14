import Foundation
import Combine
import os
import Observation
import UIKit

// Global logger for unified subscription events
nonisolated fileprivate let logger = Logger(subsystem: "com.stash.app", category: "StashSubscriptionService")

// MARK: - Jobs Observable State

/// Observable state for jobs - separate from service to isolate observation
@MainActor
@Observable
final class JobsState {
    var jobs: [Job] = []
    var hasIdentifyJob = false
}

// MARK: - Main Service

/// A service that manages real-time job data streams over WebSocket.
@MainActor
final class StashSubscriptionService: ObservableObject {
    
    /// The singleton instance for global access.
    public static let shared = StashSubscriptionService()
    
    private let settings: any SettingsStoreProtocol
    
    // MARK: - Observable State
    
    /// Jobs state - observe this in views that display jobs
    let jobsState = JobsState()
    
    // MARK: - Connection State (Published for ObservableObject)
    
    @Published var isConnected = false
    @Published var connectionError: String?
    
    // MARK: - Private Properties
    
    private let client = GraphQLWebSocketClient()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init(settings: (any SettingsStoreProtocol)? = nil) {
        self.settings = settings ?? SettingsStore.shared
        setupBindings()
        setupLifecycleObservations()
        logger.debug("🌐 StashSubscriptionService initialized")
    }
    
    
    private func setupBindings() {
        client.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .connected:
                    self.isConnected = true
                    self.connectionError = nil
                    self.subscribeToJobs()
                case .connecting, .reconnecting:
                    self.isConnected = false
                    self.connectionError = nil
                case .disconnected:
                    self.isConnected = false
                case .error(let message):
                    self.isConnected = false
                    self.connectionError = message
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupLifecycleObservations() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleBackground()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleBackground() {
        logger.info("⏸️ App backgrounded - disconnecting socket")
        disconnect()
    }
    
    private func handleForeground() {
        logger.info("▶️ App foregrounded - reconnecting socket")
        if let url = settings.url {
            connect(url: url, apiKey: settings.apiKey)
        }
    }
    
    // MARK: - Connection Management
    
    func connect(url: URL, apiKey: String) {
        client.connect(to: url, apiKey: apiKey)
    }
    
    func disconnect() {
        client.disconnect()
    }
    
    // MARK: - Jobs Management
    
    private func subscribeToJobs() {
        let query = """
        subscription JobsSubscribe {
          jobsSubscribe {
            type
            job {
              id
              status
              subTasks
              description
              progress
              error
              startTime
            }
          }
        }
        """
        client.subscribe(id: "job-sub", query: query) { text in
            // Parse on background thread
            Task.detached {
                await StashSubscriptionService.shared.handleJobMessage(text)
            }
        }
        logger.info("📤 Subscribed to Jobs")
    }
    
    private func handleJobMessage(_ text: String) async {
        // Parse JSON off the main thread
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] as? [String: Any],
              let dataDict = payload["data"] as? [String: Any],
              let jobsSubscribe = dataDict["jobsSubscribe"] as? [String: Any],
              let jobData = jobsSubscribe["job"] as? [String: Any] else {
            return
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jobData),
           let job = try? JSONDecoder().decode(Job.self, from: jsonData) {
            await MainActor.run {
                self.updateJob(job)
            }
        }
    }
    
    @MainActor
    func updateJob(_ job: Job) {
        var isNewlyCompleted = false
        
        // Update or insert job immediately
        if let index = jobsState.jobs.firstIndex(where: { $0.id == job.id }) {
            let oldJob = jobsState.jobs[index]
            if !oldJob.isCompleted && job.isCompleted {
                isNewlyCompleted = true
            }
            jobsState.jobs[index] = job
        } else {
            jobsState.jobs.insert(job, at: 0)
            if job.isCompleted {
                isNewlyCompleted = true
            }
        }
        
        // Track identify jobs
        if let description = job.description, description.localizedCaseInsensitiveContains("Identify") {
            jobsState.hasIdentifyJob = true
        }
        
        // Handle completed job
        if isNewlyCompleted {
            NotificationCenter.default.post(name: .stashJobCompleted, object: nil, userInfo: ["job": job])
            
            // Schedule removal after 5 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                self.jobsState.jobs.removeAll { $0.id == job.id }
                if self.jobsState.jobs.isEmpty {
                    NotificationCenter.default.post(
                        name: .stashAllJobsCompleted,
                        object: nil,
                        userInfo: ["hasIdentify": self.jobsState.hasIdentifyJob]
                    )
                    self.jobsState.hasIdentifyJob = false
                }
            }
        }
    }
    
    // MARK: - Convenience Accessors
    
    /// Convenience accessor for jobs array
    var jobs: [Job] {
        jobsState.jobs
    }
    // MARK: - Job Controls
    
    func cancelJob(id: String) async throws {
        guard let url = settings.url else { return }
        
        // Create a temporary client for this mutation
        let client = StashClient(settings: settings)
        
        struct StopJobResult: Decodable {
            let stopJob: Bool
        }
        
        let _: StopJobResult = try await client.fetch(
            query: StashQueries.stopJob(jobId: id),
            variables: nil,
            url: url,
            apiKey: settings.apiKey
        )
        logger.info("🛑 Sent stop command for job \(id)")
    }

    func stopAllJobs() async throws {
        guard let url = settings.url else { return }
        
        // Create a temporary client for this mutation
        let client = StashClient(settings: settings)
        
        struct StopAllJobsResult: Decodable {
            let stopAllJobs: Bool
        }
        
        let _: StopAllJobsResult = try await client.fetch(
            query: StashQueries.stopAllJobs(),
            variables: nil,
            url: url,
            apiKey: settings.apiKey
        )
        logger.info("🛑 Sent stop-all command")
    }
}
