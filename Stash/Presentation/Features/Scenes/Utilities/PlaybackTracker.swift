import AVFoundation
import os

final class PlaybackTracker {
    // MARK: - Properties
    
    private var timeObserver: Any?
    private var totalPlayDuration: TimeInterval = 0
    private var currentPlayDuration: TimeInterval = 0
    private var playCountIncremented = false
    
    private let sceneId: String
    private let player: AVPlayer
    private let minimumPlayPercent: Double
    private let url: URL
    private let apiKey: String
    
    // Testing Hooks
    var isPlayingOverride: (() -> Bool)?
    var currentTimeOverride: (() -> Double)?
    var durationOverride: (() -> Double)?
    
    // Dependencies
    private let graphQLClient: StashClientProtocol
    
    // Callbacks
    var onSaveActivity: ((Double) -> Void)?
    
    // MARK: - Constants
    
    private let intervalSeconds: TimeInterval = 1.0
    private let sendInterval: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    init(
        sceneId: String,
        player: AVPlayer,
        minimumPlayPercent: Double = 0,
        graphQLClient: StashClientProtocol = StashClient(),
        url: URL,
        apiKey: String
    ) {
        self.sceneId = sceneId
        self.player = player
        self.minimumPlayPercent = minimumPlayPercent
        self.graphQLClient = graphQLClient
        self.url = url
        self.apiKey = apiKey
        
        setupTimeObserver()
        setupEndObserver()
        
        Logger.playback.debug("▶️ PlaybackTracker initialized for scene: \(sceneId, privacy: .public)")
    }
    
    deinit {
        Logger.playback.debug("🛑 PlaybackTracker deinitialized")
        removeTimeObserver()
        removeEndObserver()
    }
    
    // MARK: - Time Observer Setup
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: intervalSeconds, preferredTimescale: 600)
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            self?.trackPlayback()
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Send final update
        if currentPlayDuration > 0 {
            sendActivity()
        }
    }
    
    private func setupEndObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    private func removeEndObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    // MARK: - Tracking Logic
    
    // Internal for testing
    func trackPlayback() {
        // Only track if player is actually playing (rate > 0)
        let isPlaying = isPlayingOverride?() ?? (player.rate > 0)
        guard isPlaying else { return }
        
        totalPlayDuration += intervalSeconds
        currentPlayDuration += intervalSeconds
        
        // Send activity every 10 seconds of accumulated playback
        if totalPlayDuration.truncatingRemainder(dividingBy: sendInterval) == 0 {
            sendActivity()
        }
    }
    
    private func sendActivity() {
        guard currentPlayDuration > 0 else { return }
        
        let currentTime: Double
        let duration: Double
        
        if let c = currentTimeOverride?(), let d = durationOverride?() {
             currentTime = c
             duration = d
        } else {
             guard let currentItem = player.currentItem else { return }
             currentTime = player.currentTime().seconds
             duration = currentItem.duration.seconds
        }
        
        // Sanity check for valid duration
        guard duration.isFinite && duration > 0 else { return }
        
        let percentCompleted = (currentTime / duration) * 100
        let percentPlayed = (totalPlayDuration / duration) * 100
        
        // Increment play count ONCE when threshold reached
        if !playCountIncremented && percentPlayed >= minimumPlayPercent {
            incrementPlayCount()
            playCountIncremented = true
        }
        
        // 98% Rule: Reset resume time to 0 if video is nearly complete
        let resumeTime: Double
        if percentCompleted >= 98 {
            resumeTime = 0
            Logger.playback.info("🔄 Resetting resume time (completion > 98%)")
        } else {
            resumeTime = currentTime
        }
        
        // Save activity (fire and forget)
        saveActivity(resumeTime: resumeTime, playDuration: currentPlayDuration)
        
        // Reset current duration accumulator after sending
        currentPlayDuration = 0
    }
    
    func reset() {
        totalPlayDuration = 0
        currentPlayDuration = 0
        playCountIncremented = false
    }
    
    // MARK: - API Calls
    
    private func saveActivity(resumeTime: TimeInterval, playDuration: TimeInterval) {
        let query = StashQueries.sceneSaveActivity(
            id: sceneId,
            resumeTime: resumeTime,
            playDuration: playDuration
        )
        
        let onSave = self.onSaveActivity
        
        Task { [graphQLClient, url, apiKey, onSave] in
            do {
                // We define a transient struct just to capture the success output, 
                // though usually mutations return a specific type.
                // sceneSaveActivity returns Boolean! in schema.
                struct SaveResult: Decodable {
                    let sceneSaveActivity: Bool
                }
                
                let _: SaveResult = try await graphQLClient.fetch(
                    query: query,
                    variables: nil,
                    url: url,
                    apiKey: apiKey
                )
                Logger.playback.info("✅ Saved activity (resume: \(resumeTime, format: .fixed(precision: 2))s, play: \(playDuration, format: .fixed(precision: 2))s)")
                
                // Notify via callback to update local storage
                await MainActor.run {
                    onSave?(resumeTime)
                }
            } catch {
                Logger.playback.error("❌ Failed to save activity: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func incrementPlayCount() {
        let query = StashQueries.sceneIncrementPlayCount(id: sceneId)
        
        Task { [graphQLClient, url, apiKey] in
            do {
                struct IncrementResult: Decodable {
                    let sceneIncrementPlayCount: Int
                }
                
                let _: IncrementResult = try await graphQLClient.fetch(
                    query: query,
                    variables: nil,
                    url: url,
                    apiKey: apiKey
                )
                Logger.playback.info("📈 Incremented play count")
            } catch {
                Logger.playback.error("❌ Failed to increment play count: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // MARK: - Event Handlers
    
    @objc private func playerDidEnd() {
        // Send final update on playback completion
        if currentPlayDuration > 0 {
            sendActivity()
        }
    }
}
