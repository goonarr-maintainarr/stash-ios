# Playback Tracking - Stash API

This document explains how to implement playback tracking in the iOS app to match the behavior of the Stash web UI.

## Table of Contents

- [Overview](#overview)
- [Stash-GO Parity Requirements](#stash-go-parity-requirements)
- [How the Web UI Works](#how-the-web-ui-works)
- [GraphQL Mutations](#graphql-mutations)
- [iOS Implementation](#ios-implementation)
  - [Timer-Based Implementation](#swift-implementation)
  - [AVPlayerItemTimeObserver (Recommended)](#alternative-avplayeritemtimeobserver-recommended)
  - [Comparison](#comparison-avplayeritemtimeobserver-vs-timer)
- [Configuration](#configuration)
- [GraphQL Queries Setup](#add-to-graphqlqueriesswift)
- [Implementation Notes](#notes)

---

## Overview

Playback tracking in Stash is **not automatic**. The client must explicitly call mutations to track:
- **Play duration** - Total time the user has watched
- **Resume time** - Where the user left off (for resume functionality)
- **Play count** - Number of times the scene has been played
- **Play history** - Timestamps of when the scene was played

---

## Stash-GO Parity Requirements
Research into the `Stash-GO` codebase (`track-activity.ts`) confirms the following strict behavior that the iOS client **MUST** replicate:

1.  **Tracking Interval**: The client must check playback status every **1 second**.
2.  **Sync Interval**: The client must send activity updates to the server every **10 seconds** of accumulated playback time.
3.  **Play Count Increment**:
    *   **Once per session**: The play count must only be incremented **once** per viewing session.
    *   **Threshold**: Increment only when `percentPlayed >= minimumPlayPercent` (default 0).
    *   **Timing**: The check is performed during the 10-second sync cycle.
4.  **Resume Resets**: Resume time is explicitly set to `0` if the user watches past **98%** of the video duration.


---

## How the Web UI Works

The Stash web UI uses a VideoJS plugin (`track-activity.ts`) that implements the following behavior:

### Tracking Logic

1. **Checks playback every 1 second**
2. **Sends updates to server every 10 seconds**
3. **Increments play count once** when minimum play percentage is reached
4. **Automatically resets resume time** when video reaches 98% completion

### Key Implementation Details

```typescript
// Constants
const intervalSeconds = 1;      // Check every second
const sendInterval = 10;         // Send every 10 seconds

// Tracking logic (from track-activity.ts)
private intervalHandler() {
    this.totalPlayDuration += intervalSeconds;
    this.currentPlayDuration += intervalSeconds;
    
    if (this.totalPlayDuration % sendInterval === 0) {
        this.sendActivity();
    }
}

// Send activity update
private sendActivity() {
    let resumeTime = this.player?.currentTime();
    const videoDuration = this.player?.duration();
    const percentCompleted = (100 / videoDuration) * resumeTime;
    const percentPlayed = (100 / videoDuration) * this.totalPlayDuration;
    
    // Increment play count once when threshold reached
    if (!this.playCountIncremented && percentPlayed >= this.minimumPlayPercent) {
        this.incrementPlayCount();
        this.playCountIncremented = true;
    }
    
    // Reset resume time if video is 98% or more complete
    if (percentCompleted >= 98) {
        resumeTime = 0;
    }
    
    this.saveActivity(resumeTime, this.currentPlayDuration);
    this.currentPlayDuration = 0;
}
```

### Event Handlers

The plugin starts/stops tracking based on video events:
- **Start tracking**: `playing` event
- **Stop tracking**: `pause`, `waiting`, `stalled`, `ended`, `dispose` events

When tracking stops, it sends a final activity update with accumulated duration.

---

## GraphQL Mutations

### 1. Save Activity (Called Every 10 Seconds)

Updates resume time and adds to play duration.

```graphql
mutation SaveSceneActivity($sceneId: ID!, $resumeTime: Float, $playDuration: Float) {
  sceneSaveActivity(
    id: $sceneId
    resume_time: $resumeTime
    playDuration: $playDuration
  )
}
```

**Variables:**
```json
{
  "sceneId": "123",
  "resumeTime": 145.5,
  "playDuration": 10.0
}
```

**Response:**
```json
{
  "data": {
    "sceneSaveActivity": true
  }
}
```

### 2. Increment Play Count (Called Once Per Session)

Increments play count and adds timestamp to play history.

```graphql
mutation IncrementPlayCount($sceneId: ID!) {
  sceneIncrementPlayCount(id: $sceneId)
}
```

**Variables:**
```json
{
  "sceneId": "123"
}
```

**Response:**
```json
{
  "data": {
    "sceneIncrementPlayCount": 1
  }
}
```

### 3. Alternative: Add Play with Custom Timestamp

For more control, use `sceneAddPlay` which returns full history:

```graphql
mutation AddPlay($sceneId: ID!, $times: [Timestamp!]) {
  sceneAddPlay(id: $sceneId, times: $times) {
    count
    history
  }
}
```

**Variables (current time):**
```json
{
  "sceneId": "123",
  "times": []
}
```

**Variables (specific time):**
```json
{
  "sceneId": "123",
  "times": ["2024-12-23T18:30:00Z"]
}
```

**Response:**
```json
{
  "data": {
    "sceneAddPlay": {
      "count": 5,
      "history": [
        "2024-12-20T10:00:00Z",
        "2024-12-21T15:30:00Z",
        "2024-12-23T18:30:00Z"
      ]
    }
  }
}
```

---

## iOS Implementation

### Swift Implementation

```swift
import AVFoundation

class PlaybackTracker {
    // MARK: - Properties
    
    private var playbackTimer: Timer?
    private var totalPlayDuration: TimeInterval = 0
    private var currentPlayDuration: TimeInterval = 0
    private var playCountIncremented = false
    
    private let sceneId: String
    private let player: AVPlayer
    private let minimumPlayPercent: Double
    
    // GraphQL client
    private let graphQLClient: GraphQLClientProtocol
    private let stashURL: URL
    private let apiKey: String
    
    // MARK: - Constants
    
    private let intervalSeconds: TimeInterval = 1.0
    private let sendInterval: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    init(
        sceneId: String,
        player: AVPlayer,
        minimumPlayPercent: Double = 0,
        graphQLClient: GraphQLClientProtocol,
        stashURL: URL,
        apiKey: String
    ) {
        self.sceneId = sceneId
        self.player = player
        self.minimumPlayPercent = minimumPlayPercent
        self.graphQLClient = graphQLClient
        self.stashURL = stashURL
        self.apiKey = apiKey
        
        setupObservers()
    }
    
    deinit {
        stopTracking()
        removeObservers()
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidStart),
            name: .AVPlayerItemNewAccessLogEntry,
            object: player.currentItem
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Tracking Control
    
    func startTracking() {
        guard playbackTimer == nil else { return }
        
        playbackTimer = Timer.scheduledTimer(
            withTimeInterval: intervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.trackPlayback()
        }
    }
    
    func stopTracking() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        // Send final update
        if currentPlayDuration > 0 {
            sendActivity()
        }
    }
    
    func reset() {
        stopTracking()
        totalPlayDuration = 0
        currentPlayDuration = 0
        playCountIncremented = false
    }
    
    // MARK: - Tracking Logic
    
    private func trackPlayback() {
        totalPlayDuration += intervalSeconds
        currentPlayDuration += intervalSeconds
        
        // Send activity every 10 seconds
        if totalPlayDuration.truncatingRemainder(dividingBy: sendInterval) == 0 {
            sendActivity()
        }
    }
    
    private func sendActivity() {
        guard currentPlayDuration > 0 else { return }
        guard let currentItem = player.currentItem else { return }
        
        let currentTime = player.currentTime().seconds
        let duration = currentItem.duration.seconds
        
        guard duration.isFinite && duration > 0 else { return }
        
        let percentCompleted = (currentTime / duration) * 100
        let percentPlayed = (totalPlayDuration / duration) * 100
        
        // Increment play count once when threshold reached
        if !playCountIncremented && percentPlayed >= minimumPlayPercent {
            incrementPlayCount()
            playCountIncremented = true
        }
        
        // Reset resume time if video is 98% or more complete
        let resumeTime = percentCompleted >= 98 ? 0 : currentTime
        
        // Save activity (detached to avoid blocking main thread)
        Task.detached { [weak self] in
            await self?.saveActivity(resumeTime: resumeTime, playDuration: currentPlayDuration)
        }
        
        currentPlayDuration = 0
    }
    
    // MARK: - API Calls
    
    private func saveActivity(resumeTime: TimeInterval, playDuration: TimeInterval) async {
        let mutation = """
        mutation SaveSceneActivity($sceneId: ID!, $resumeTime: Float, $playDuration: Float) {
            sceneSaveActivity(
                id: $sceneId
                resume_time: $resumeTime
                playDuration: $playDuration
            )
        }
        """
        
        let variables: [String: Any] = [
            "sceneId": sceneId,
            "resumeTime": resumeTime,
            "playDuration": playDuration
        ]
        
        do {
            let _: SaveActivityResult = try await graphQLClient.fetch(
                query: mutation,
                variables: variables,
                url: stashURL,
                apiKey: apiKey
            )
        } catch {
            print("Failed to save activity: \(error)")
        }
    }
    
    private func incrementPlayCount() {
        let mutation = """
        mutation IncrementPlayCount($sceneId: ID!) {
            sceneIncrementPlayCount(id: $sceneId)
        }
        """
        
        let variables: [String: Any] = [
            "sceneId": sceneId
        ]
        
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let _: IncrementPlayCountResult = try await self.graphQLClient.fetch(
                    query: mutation,
                    variables: variables,
                    url: self.stashURL,
                    apiKey: self.apiKey
                )
            } catch {
                print("Failed to increment play count: \(error)")
            }
        }
    }
    
    // MARK: - Event Handlers
    
    @objc private func playerDidStart() {
        startTracking()
    }
    
    @objc private func playerDidEnd() {
        stopTracking()
    }
}

// MARK: - Models

struct SaveActivityResult: Decodable {
    let sceneSaveActivity: Bool
}

struct IncrementPlayCountResult: Decodable {
    let sceneIncrementPlayCount: Int
}
```

### Usage in Video Player View

```swift
import SwiftUI
import AVKit

struct ScenePlayerView: View {
    let scene: Scene
    @StateObject private var playerManager = VideoPlayerManager()
    
    var body: some View {
        VideoPlayer(player: playerManager.player)
            .onAppear {
                playerManager.setupPlaybackTracking(for: scene)
                playerManager.play()
            }
            .onDisappear {
                playerManager.stopPlaybackTracking()
            }
    }
}

class VideoPlayerManager: ObservableObject {
    let player = AVPlayer()
    private var playbackTracker: PlaybackTracker?
    
    func setupPlaybackTracking(for scene: Scene) {
        // Ensure server URL and API key are configured
        guard let serverURLString = SettingsStore.shared.serverURL,
              let serverURL = URL(string: serverURLString),
              let apiKey = SettingsStore.shared.apiKey else {
            print("Cannot setup tracking: missing server URL or API key")
            return
        }
        
        playbackTracker = PlaybackTracker(
            sceneId: scene.id,
            player: player,
            minimumPlayPercent: 0, // Configure as needed
            graphQLClient: GraphQLClient(),
            stashURL: serverURL,
            apiKey: apiKey
        )
    }
    
    func play() {
        player.play()
    }
    
    func stopPlaybackTracking() {
        playbackTracker?.stopTracking()
        playbackTracker = nil
    }
}
```

### Alternative: AVPlayerItemTimeObserver (Recommended)

`AVPlayerItemTimeObserver` is the native AVFoundation approach for periodic playback tracking. It offers several advantages over `Timer`:

**Advantages:**
- **Player-aware**: Automatically pauses when player pauses (no manual KVO needed)
- **Frame-accurate**: Syncs with video timeline, not wall clock
- **Native integration**: Designed specifically for AVPlayer time-based observations
- **Simpler lifecycle**: No need to manage Timer invalidation separately

**Implementation:**

```swift
import AVFoundation

class PlaybackTracker {
    // MARK: - Properties
    
    private var timeObserver: Any?
    private var totalPlayDuration: TimeInterval = 0
    private var currentPlayDuration: TimeInterval = 0
    private var playCountIncremented = false
    
    private let sceneId: String
    private let player: AVPlayer
    private let minimumPlayPercent: Double
    
    // GraphQL client
    private let graphQLClient: GraphQLClientProtocol
    private let stashURL: URL
    private let apiKey: String
    
    // MARK: - Constants
    
    private let intervalSeconds: TimeInterval = 1.0
    private let sendInterval: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    init(
        sceneId: String,
        player: AVPlayer,
        minimumPlayPercent: Double = 0,
        graphQLClient: GraphQLClientProtocol,
        stashURL: URL,
        apiKey: String
    ) {
        self.sceneId = sceneId
        self.player = player
        self.minimumPlayPercent = minimumPlayPercent
        self.graphQLClient = graphQLClient
        self.stashURL = stashURL
        self.apiKey = apiKey
        
        setupTimeObserver()
        setupEndObserver()
    }
    
    deinit {
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
    
    private func trackPlayback() {
        // Only track if player is actually playing
        guard player.rate > 0 else { return }
        
        totalPlayDuration += intervalSeconds
        currentPlayDuration += intervalSeconds
        
        // Send activity every 10 seconds
        if totalPlayDuration.truncatingRemainder(dividingBy: sendInterval) == 0 {
            sendActivity()
        }
    }
    
    private func sendActivity() {
        guard currentPlayDuration > 0 else { return }
        guard let currentItem = player.currentItem else { return }
        
        let currentTime = player.currentTime().seconds
        let duration = currentItem.duration.seconds
        
        guard duration.isFinite && duration > 0 else { return }
        
        let percentCompleted = (currentTime / duration) * 100
        let percentPlayed = (totalPlayDuration / duration) * 100
        
        // Increment play count once when threshold reached
        if !playCountIncremented && percentPlayed >= minimumPlayPercent {
            incrementPlayCount()
            playCountIncremented = true
        }
        
        // Reset resume time if video is 98% or more complete
        let resumeTime = percentCompleted >= 98 ? 0 : currentTime
        
        // Save activity (detached to avoid blocking main thread)
        Task.detached { [weak self] in
            await self?.saveActivity(resumeTime: resumeTime, playDuration: currentPlayDuration)
        }
        
        currentPlayDuration = 0
    }
    
    func reset() {
        totalPlayDuration = 0
        currentPlayDuration = 0
        playCountIncremented = false
    }
    
    // MARK: - API Calls
    
    private func saveActivity(resumeTime: TimeInterval, playDuration: TimeInterval) async {
        let mutation = """
        mutation SaveSceneActivity($sceneId: ID!, $resumeTime: Float, $playDuration: Float) {
            sceneSaveActivity(
                id: $sceneId
                resume_time: $resumeTime
                playDuration: $playDuration
            )
        }
        """
        
        let variables: [String: Any] = [
            "sceneId": sceneId,
            "resumeTime": resumeTime,
            "playDuration": playDuration
        ]
        
        do {
            let _: SaveActivityResult = try await graphQLClient.fetch(
                query: mutation,
                variables: variables,
                url: stashURL,
                apiKey: apiKey
            )
        } catch {
            print("Failed to save activity: \(error)")
        }
    }
    
    private func incrementPlayCount() {
        let mutation = """
        mutation IncrementPlayCount($sceneId: ID!) {
            sceneIncrementPlayCount(id: $sceneId)
        }
        """
        
        let variables: [String: Any] = [
            "sceneId": sceneId
        ]
        
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let _: IncrementPlayCountResult = try await self.graphQLClient.fetch(
                    query: mutation,
                    variables: variables,
                    url: self.stashURL,
                    apiKey: self.apiKey
                )
            } catch {
                print("Failed to increment play count: \(error)")
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

// MARK: - Models

struct SaveActivityResult: Decodable {
    let sceneSaveActivity: Bool
}

struct IncrementPlayCountResult: Decodable {
    let sceneIncrementPlayCount: Int
}
```

**Key Differences from Timer Approach:**
1. **No manual start/stop**: The observer fires automatically when player is playing
2. **Rate check**: Added `guard player.rate > 0` to ensure we only track during actual playback
3. **Simpler cleanup**: Just remove the observer, no timer invalidation
4. **No KVO needed**: Player state is implicitly handled by checking `rate`

### Alternative: Observing Player State Changes (Timer Approach)

If you prefer explicit control with Timer, observe player rate changes:

```swift
private var playerObserver: NSKeyValueObservation?

private func observePlayerState() {
    playerObserver = player.observe(\.rate, options: [.new]) { [weak self] player, change in
        guard let rate = change.newValue else { return }
        
        if rate > 0 {
            // Playing
            self?.startTracking()
        } else {
            // Paused/Stopped
            self?.stopTracking()
        }
    }
}
```

### Comparison: AVPlayerItemTimeObserver vs Timer

| Feature | AVPlayerItemTimeObserver | Timer |
|---------|-------------------------|-------|
| **Automatic pause handling** | Yes (via rate check) | No (needs KVO) |
| **Player synchronization** | Frame-accurate | Wall-clock based |
| **Complexity** | Simpler | More boilerplate |
| **Explicit control** | Less explicit | Very explicit |
| **Background behavior** | Pauses automatically | Continues running |
| **Best for** | Video playback tracking | General-purpose timing |

**Recommendation**: Use `AVPlayerItemTimeObserver` for this use case. It's designed for exactly this purpose and reduces the amount of state management code you need to write.

---

## Configuration

### User Preferences

You may want to make tracking configurable:

```swift
struct PlaybackSettings {
    var trackActivity: Bool = true
    var minimumPlayPercent: Double = 0.0 // 0-100
}

// In PlaybackTracker init
if !settings.trackActivity {
    // Don't start tracking
    return
}
```

### Resume Time on Launch

When loading a scene, check for existing resume time:

```swift
func loadScene(_ scene: Scene) {
    // Set player to resume time if available
    if let resumeTime = scene.resume_time, resumeTime > 0 {
        player.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600))
    }
    
    // Setup tracking
    setupPlaybackTracking(for: scene)
}
```

---

## Add to GraphQLQueries.swift

```swift
// MARK: - Playback Tracking Mutations

static let saveSceneActivity = """
mutation SaveSceneActivity($sceneId: ID!, $resumeTime: Float, $playDuration: Float) {
    sceneSaveActivity(
        id: $sceneId
        resume_time: $resumeTime
        playDuration: $playDuration
    )
}
"""

static let incrementPlayCount = """
mutation IncrementPlayCount($sceneId: ID!) {
    sceneIncrementPlayCount(id: $sceneId)
}
"""

static let addPlay = """
mutation AddPlay($sceneId: ID!, $times: [Timestamp!]) {
    sceneAddPlay(id: $sceneId, times: $times) {
        count
        history
    }
}
"""
```

---

## Notes

- **Not Automatic**: Tracking must be explicitly implemented by the client
- **10 Second Intervals**: Web UI sends updates every 10 seconds to balance accuracy and network overhead
- **98% Rule**: Resume time is reset to 0 when video is 98% complete (to avoid starting at the very end)
- **Minimum Play Percent**: Play count only increments after watching a configurable percentage (default: 0%)
- **Single Increment**: Play count is only incremented once per playback session
- **Observer Cleanup**: Always remove observers when the tracker is deallocated or the view disappears
- **Threading**: Network calls use `Task.detached` to avoid blocking the main thread. The tracking callbacks run on main thread (from Timer/observer) but don't need to.
- **Protocol Injection**: Use `GraphQLClientProtocol` instead of concrete `GraphQLClient` for dependency injection and testability (per MVVM architecture)
- **Background Playback**: The AVPlayerItemTimeObserver approach automatically handles backgrounding since it only fires when `player.rate > 0`. For Timer-based approach, add:
  ```swift
  NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
  )
  
  @objc private func appDidEnterBackground() {
      stopTracking()  // Pause tracking when app backgrounds
  }
  ```
- **Network Failures**: The web UI doesn't retry failed updates, but iOS apps should consider implementing retry logic due to intermittent cellular connectivity
