import Foundation
import Combine
import Observation
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "HomeJobManager")

/// Manages job notifications and debouncing for identify jobs.
@MainActor
@Observable
class HomeJobManager {
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    private var debounceTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var onRefreshTriggered: (() async -> Void)?
    
    // MARK: - Initialization
    
    init() {
        logger.debug("🔧 HomeJobManager initialized")
        setupJobSubscription()
    }
    
    // MARK: - Setup
    
    /// Sets up callback for when refresh is triggered.
    func setupRefreshCallback(onRefreshTriggered: @escaping () async -> Void) {
        logger.debug("🔗 Setting up refresh callback")
        self.onRefreshTriggered = onRefreshTriggered
    }
    
    // MARK: - Job Subscription
    
    private func setupJobSubscription() {
        logger.debug("📡 Setting up job subscription")
        
        NotificationCenter.default.publisher(for: .stashJobCompleted)
            .handleEvents(receiveOutput: { notification in
                if let job = notification.userInfo?["job"] as? Job {
                    logger.debug("📩 Received job completion: \(job.description ?? "nil", privacy: .public)")
                }
            })
            .compactMap { notification -> Job? in
                guard let job = notification.userInfo?["job"] as? Job,
                      let description = job.description,
                      description.localizedCaseInsensitiveContains("Identify"),
                      job.status == .finished else { return nil }
                return job
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] job in
                guard let self = self else { return }
                
                logger.info("🔍 'Identify' job found. Cancelling existing timer: \(self.debounceTask != nil)")
                
                // Cancel existing timeout to reset the debounce timer
                self.debounceTask?.cancel()
                
                logger.info("⏳ Starting 10s debounce countdown...")
                
                // Standard debounce: if no new jobs come in 10 seconds, then it fires
                self.debounceTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(nanoseconds: 10_000_000_000)
                        guard let self = self else { return }
                        logger.info("⏰ Identify job debounce triggered (10s elapsed). Refreshing!")
                        self.triggerRefresh()
                    } catch {
                        // Task was cancelled, which is expected when debounce resets
                    }
                }
            }
            .store(in: &cancellables)
        
        logger.info("✅ Job subscription set up successfully")
    }
    
    // MARK: - Refresh Trigger
    
    private func triggerRefresh() {
        logger.info("🔄 Triggering refresh from identify job completion")
        
        refreshTask?.cancel()
        refreshTask = Task {
            await onRefreshTriggered?()
        }
    }
}
