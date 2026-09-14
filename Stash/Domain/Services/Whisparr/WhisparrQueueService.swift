import Foundation
import SwiftUI
import os

fileprivate let logger = Logger(subsystem: "com.stash.app", category: "WhisparrQueueService")

/// Whisparr queue service with continuous background polling
/// Uses @Observable macro for modern SwiftUI integration
@Observable
final class WhisparrQueueService {
    static let shared = WhisparrQueueService(
        settings: SettingsStore.shared,
        database: WhisparrDatabase.shared,
        client: WhisparrClient(settings: SettingsStore.shared as SettingsStoreProtocol)
    )
    
    // UI-bound properties (updated on MainActor)
    @MainActor var items: [WhisparrQueueItem] = []
    @MainActor var isLoading = false
    @MainActor var itemsWithIssues: Int = 0
    @MainActor var performRefresh = true
    
    private var previousQueueItems: [Int: Int] = [:] // queueId -> movieId
    private var activeItemStatuses: [Int: String] = [:] // queueId -> status
    private var lastClientRefresh: Date = .distantPast
    private var backgroundTask: Task<Void, Never>?
    private let settingsStore: SettingsStore
    private let whisparrDatabase: WhisparrDatabase
    private let whisparrClient: WhisparrClientProtocol
    
    /// Polling interval in seconds (slows down when queue is empty)
    private let activePollingInterval: TimeInterval = 2.5
    private let idlePollingInterval: TimeInterval = 30.0
    
    init(settings: SettingsStore, database: WhisparrDatabase, client: WhisparrClientProtocol) {
        self.settingsStore = settings
        self.whisparrDatabase = database
        self.whisparrClient = client
        
        // Start continuous polling
        startContinuousPolling()
    }
    
    
    deinit {
        backgroundTask?.cancel()
    }
    
    // MARK: - Continuous Polling
    
    private func startContinuousPolling() {
        backgroundTask?.cancel()
        backgroundTask = Task {
            logger.info("Started continuous queue polling (interval: \(self.activePollingInterval)s)")
            
            while !Task.isCancelled {
                // Check if polling is enabled
                let shouldRefresh = await MainActor.run { performRefresh }
                
                if shouldRefresh {
                    logger.debug("🔄 Polling Whisparr queue...")
                    await refreshDownloadClientsAndQueue()
                }
                
                // Wait for next interval
                try? await Task.sleep(nanoseconds: UInt64(activePollingInterval * 1_000_000_000))
            }
        }
    }
    
    // MARK: - Public Methods
    
    func fetchQueue(showLoading: Bool = true) async {
        let (whisparrUrl, whisparrApiKey) = await (settingsStore.whisparrUrl, settingsStore.whisparrApiKey)
        guard !whisparrUrl.isEmpty,
              !whisparrApiKey.isEmpty else {
            return
        }
        
        if showLoading {
            await MainActor.run { isLoading = true }
        }
        
        do {
            let queueItems = try await whisparrClient.fetchQueue(
                url: whisparrUrl,
                apiKey: whisparrApiKey
            )
            
            
            // Process queue logic in background
            await processQueueItems(queueItems)
            
        } catch {
            logger.error("Failed to fetch queue: \(error.localizedDescription, privacy: .public)")
        }
        
        if showLoading {
            await MainActor.run { isLoading = false }
        }
    }
    
    /// Combined refresh logic to run in background loop
    private func refreshDownloadClientsAndQueue() async {
        let (whisparrUrl, whisparrApiKey) = await (settingsStore.whisparrUrl, settingsStore.whisparrApiKey)
        guard !whisparrUrl.isEmpty,
              !whisparrApiKey.isEmpty else {
            return
        }
        
        // 1. Trigger Refresh (Always runs with every poll now)
        do {
            try await whisparrClient.refreshDownloads(
                url: whisparrUrl,
                apiKey: whisparrApiKey
            )
            // lastClientRefresh = Date() // Not strictly needed if not throttling, but good for debug if we kept it
        } catch {
            // Continue anyway to fetch queue
        }
        
        // 2. Fetch Queue (Quietly)
        await fetchQueue(showLoading: false)
    }
    
    /// Processes queue items and detects completions/changes
    private func processQueueItems(_ queueItems: [WhisparrQueueItem]) async {
        // Detect completed downloads and refresh those specific movies
        let currentQueueItems = Dictionary(uniqueKeysWithValues: queueItems.map { ($0.id, $0.movieId) })
        
        // Logic for detecting completions
        if !previousQueueItems.isEmpty {
            let completedQueueIds = Set(previousQueueItems.keys).subtracting(Set(currentQueueItems.keys))
            if !completedQueueIds.isEmpty {
                logger.info("✅ Detected \(completedQueueIds.count) completed download(s)")
                // Get the movieIds for completed downloads
                let completedMovieIds = completedQueueIds.compactMap { previousQueueItems[$0] }
                for movieId in completedMovieIds {
                    logger.info("🎬 Refreshing movie ID: \(movieId)")
                    Task.detached {
                        await self.refreshCompletedMovie(movieId: movieId)
                    }
                }
            }
        }
        previousQueueItems = currentQueueItems
        
        // Update UI only if changed (Smart Update)
        await MainActor.run {
            // Simple equality check to avoid re-publishing identical data
            // This prevents SwiftUI views from invalidating if nothing changed
            if self.items != queueItems {
                logger.info("⚡️ Queue changed - updating UI (New count: \(queueItems.count))")
                self.items = queueItems
                
                // Calculate items with issues
                self.itemsWithIssues = queueItems.filter { item in
                    item.statusMessages?.isEmpty == false
                }.count
            } else {
                logger.debug("💤 Queue unchanged - skipping UI update")
            }
        }
    }
    
    func removeFromQueue(itemId: Int, removeFromClient: Bool = true, blocklist: Bool = false) async throws {
        let (whisparrUrl, whisparrApiKey) = await (settingsStore.whisparrUrl, settingsStore.whisparrApiKey)
        try await whisparrClient.removeQueueItem(
            id: itemId,
            url: whisparrUrl,
            apiKey: whisparrApiKey,
            removeFromClient: removeFromClient,
            blocklist: blocklist
        )
        
        logger.info("Removed queue item \(itemId)")
        
        // Remove from local list immediately (optimistic)
        await MainActor.run {
            items.removeAll { $0.id == itemId }
        }
        
        // Refresh to get updated state
        await fetchQueue()
    }
    
    private func refreshCompletedMovie(movieId: Int) async {
        do {
            let (whisparrUrl, whisparrApiKey) = await (settingsStore.whisparrUrl, settingsStore.whisparrApiKey)
            // Fetch the updated movie from API
            let updatedMovie = try await whisparrClient.fetchScene(
                id: movieId,
                url: whisparrUrl,
                apiKey: whisparrApiKey
            )
            
            // Save to database
            try await whisparrDatabase.saveScenes([updatedMovie])
            
            // Post notification with the movie ID so the scene list can update just this item
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .whisparrMovieUpdated,
                    object: nil,
                    userInfo: ["movieId": movieId, "movie": updatedMovie]
                )
            }
            
            logger.info("✅ Updated movie \(movieId) in database and notified listeners")
        } catch {
            logger.error("❌ Failed to refresh completed movie: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a movie is currently in the download queue (MainActor safe)
    @MainActor
    func isMovieInQueue(_ movieId: Int) -> Bool {
        items.contains { $0.movieId == movieId }
    }
    
    /// Get queue item for a specific movie (MainActor safe)
    @MainActor
    func queueItem(for movieId: Int) -> WhisparrQueueItem? {
        items.first { $0.movieId == movieId }
    }
}
