# Video Scrubber Implementation - iOS

This document explains how to implement a video scrubber with thumbnail previews using Stash's sprite system.

## Table of Contents

- [Overview](#overview)
- [GraphQL Queries](#graphql-queries)
- [VTT Parser](#vtt-parser)
- [Sprite Manager](#sprite-manager)
- [SwiftUI Implementation](#swiftui-implementation)
- [UIKit Implementation](#uikit-implementation)
- [Loading from Stash](#loading-from-stash)
- [Usage Examples](#usage-examples)

---

## Overview

Stash generates two files for video timeline scrubbing:

1. **Sprite Image** - A single JPEG containing a grid of thumbnails from the video
2. **VTT File** - WebVTT file mapping timestamps to sprite coordinates

### How It Works

1. Query Stash for sprite and VTT URLs
2. Download both files
3. Parse VTT to get timestamp-to-coordinate mappings
4. On scrubber drag, calculate current timestamp
5. Crop sprite image at appropriate coordinates
6. Display thumbnail preview above scrubber

---

## GraphQL Queries

### Get Sprite URLs

```graphql
query GetSceneSprites($sceneId: ID!) {
  findScene(id: $sceneId) {
    id
    title
    paths {
      sprite
      vtt
    }
  }
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
    "findScene": {
      "id": "123",
      "title": "Scene Title",
      "paths": {
        "sprite": "http://localhost:9999/scene/123_sprite.jpg",
        "vtt": "http://localhost:9999/scene/123_thumbs.vtt"
      }
    }
  }
}
```

### VTT Format Example

```
WEBVTT

00:00:00.000 --> 00:00:10.000
/scene/123_sprite.jpg#xywh=0,0,160,90

00:00:10.000 --> 00:00:20.000
/scene/123_sprite.jpg#xywh=160,0,160,90

00:00:20.000 --> 00:00:30.000
/scene/123_sprite.jpg#xywh=320,0,160,90
```

Each entry contains:
- Start and end timestamp
- Sprite image path with `xywh=` coordinates (x, y, width, height)

---

## VTT Parser

### Data Model

```swift
struct SpriteFrame {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}
```

### Parser Implementation

```swift
class VTTParser {
    static func parse(_ vttContent: String) -> [SpriteFrame] {
        var frames: [SpriteFrame] = []
        let lines = vttContent.components(separatedBy: .newlines)
        
        var currentStartTime: TimeInterval?
        var currentEndTime: TimeInterval?
        
        for line in lines {
            // Parse timestamp line: "00:00:10.000 --> 00:00:20.000"
            if line.contains("-->") {
                let times = line.components(separatedBy: " --> ")
                currentStartTime = parseTimestamp(times[0])
                currentEndTime = parseTimestamp(times[1])
            }
            // Parse coordinate line: "/scene/123_sprite.jpg#xywh=160,0,160,90"
            else if line.contains("#xywh="), 
                    let start = currentStartTime,
                    let end = currentEndTime {
                if let coords = parseCoordinates(line) {
                    frames.append(SpriteFrame(
                        startTime: start,
                        endTime: end,
                        x: coords.x,
                        y: coords.y,
                        width: coords.width,
                        height: coords.height
                    ))
                }
                currentStartTime = nil
                currentEndTime = nil
            }
        }
        
        return frames
    }
    
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        // Parse "00:00:10.000" format
        let cleaned = timestamp.trimmingCharacters(in: .whitespaces)
        let components = cleaned.components(separatedBy: ":")
        
        guard components.count == 3 else { return nil }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private static func parseCoordinates(_ line: String) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)? {
        // Parse "#xywh=160,0,160,90"
        guard let xywh = line.components(separatedBy: "#xywh=").last else { return nil }
        let values = xywh.components(separatedBy: ",").compactMap { CGFloat(Double($0) ?? 0) }
        
        guard values.count == 4 else { return nil }
        return (x: values[0], y: values[1], width: values[2], height: values[3])
    }
}
```

---

## Sprite Manager

Manages sprite image and provides thumbnail extraction:

```swift
import UIKit

class SpriteManager {
    private let spriteImage: UIImage
    private let frames: [SpriteFrame]
    
    init(spriteImage: UIImage, frames: [SpriteFrame]) {
        self.spriteImage = spriteImage
        self.frames = frames
    }
    
    /// Get thumbnail for specific timestamp
    func thumbnail(for time: TimeInterval) -> UIImage? {
        // Find the frame for this timestamp
        guard let frame = frames.first(where: { time >= $0.startTime && time < $0.endTime }) else {
            return nil
        }
        
        // Calculate scale factor
        let scale = spriteImage.scale
        let rect = CGRect(
            x: frame.x * scale,
            y: frame.y * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
        
        // Crop the sprite to get the thumbnail
        guard let cgImage = spriteImage.cgImage?.cropping(to: rect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: spriteImage.imageOrientation)
    }
}
```

---

## SwiftUI Implementation

### Custom Scrubber View

```swift
import SwiftUI
import AVFoundation
import Combine

struct VideoScrubber: View {
    let player: AVPlayer
    let spriteManager: SpriteManager?
    let duration: TimeInterval
    
    @State private var scrubberValue: Double = 0
    @State private var isScrubbing = false
    @State private var showPreview = false
    @State private var previewTime: TimeInterval = 0
    @State private var previewImage: UIImage?
    @State private var previewPosition: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Thumbnail preview
                if showPreview, let image = previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 90)
                        .background(Color.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 10)
                        .position(x: previewPosition, y: 50)
                        .zIndex(1)
                }
                
                Spacer()
                    .frame(height: showPreview ? 100 : 0)
                
                // Scrubber slider
                Slider(
                    value: $scrubberValue,
                    in: 0...duration,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        showPreview = editing
                        
                        if !editing {
                            // Seek when user releases
                            player.seek(to: CMTime(seconds: scrubberValue, preferredTimescale: 600))
                        }
                    }
                )
                .onChange(of: scrubberValue) { newValue in
                    if isScrubbing {
                        previewTime = newValue
                        updatePreview(time: newValue, in: geometry)
                    }
                }
                
                // Time labels
                HStack {
                    Text(formatTime(scrubberValue))
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(duration))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .frame(height: 150)
        .onReceive(player.periodicTimePublisher()) { time in
            if !isScrubbing {
                scrubberValue = time.seconds
            }
        }
    }
    
    private func updatePreview(time: TimeInterval, in geometry: GeometryProxy) {
        // Get thumbnail for this time
        previewImage = spriteManager?.thumbnail(for: time)
        
        // Calculate preview position
        let progress = CGFloat(time / duration)
        var xPosition = progress * geometry.size.width
        
        // Keep preview within bounds
        let previewWidth: CGFloat = 160
        xPosition = max(previewWidth / 2, min(xPosition, geometry.size.width - previewWidth / 2))
        
        previewPosition = xPosition
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
```

### AVPlayer Helper Extension

```swift
import AVFoundation
import Combine

extension AVPlayer {
    func periodicTimePublisher(interval: TimeInterval = 0.5) -> AnyPublisher<CMTime, Never> {
        let subject = PassthroughSubject<CMTime, Never>()
        
        let observer = addPeriodicTimeObserver(
            forInterval: CMTime(seconds: interval, preferredTimescale: 600),
            queue: .main
        ) { time in
            subject.send(time)
        }
        
        return subject
            .handleEvents(receiveCancel: { [weak self] in
                self?.removeTimeObserver(observer)
            })
            .eraseToAnyPublisher()
    }
}
```

---

## UIKit Implementation

For UIKit-based apps:

```swift
import UIKit
import AVFoundation

class VideoScrubberView: UIView {
    private let slider = UISlider()
    private let previewImageView = UIImageView()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    
    private var spriteManager: SpriteManager?
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Setup slider
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        
        // Setup preview
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.layer.cornerRadius = 8
        previewImageView.layer.borderWidth = 2
        previewImageView.layer.borderColor = UIColor.white.cgColor
        previewImageView.clipsToBounds = true
        previewImageView.isHidden = true
        
        // Setup labels
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // Add subviews
        addSubview(previewImageView)
        addSubview(slider)
        addSubview(currentTimeLabel)
        addSubview(durationLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            previewImageView.widthAnchor.constraint(equalToConstant: 160),
            previewImageView.heightAnchor.constraint(equalToConstant: 90),
            previewImageView.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -10),
            
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            currentTimeLabel.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            currentTimeLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            
            durationLabel.trailingAnchor.constraint(equalTo: slider.trailingAnchor),
            durationLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4)
        ])
    }
    
    func configure(player: AVPlayer, spriteManager: SpriteManager?, duration: TimeInterval) {
        self.player = player
        self.spriteManager = spriteManager
        slider.maximumValue = Float(duration)
        durationLabel.text = formatTime(duration)
        
        // Add periodic time observer
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.updateCurrentTime(time.seconds)
        }
    }
    
    @objc private func sliderTouchDown() {
        previewImageView.isHidden = false
    }
    
    @objc private func sliderTouchUp() {
        previewImageView.isHidden = true
        player?.seek(to: CMTime(seconds: Double(slider.value), preferredTimescale: 600))
    }
    
    @objc private func sliderValueChanged() {
        let time = TimeInterval(slider.value)
        
        // Update preview image
        if let thumbnail = spriteManager?.thumbnail(for: time) {
            previewImageView.image = thumbnail
        }
        
        // Update preview position
        updatePreviewPosition()
        
        // Update time label
        currentTimeLabel.text = formatTime(time)
    }
    
    private func updatePreviewPosition() {
        let progress = CGFloat(slider.value) / CGFloat(slider.maximumValue)
        let sliderWidth = slider.bounds.width
        var xPosition = slider.frame.minX + progress * sliderWidth
        
        // Keep within bounds
        let previewWidth: CGFloat = 160
        xPosition = max(previewWidth / 2, min(xPosition, bounds.width - previewWidth / 2))
        
        previewImageView.center = CGPoint(x: xPosition, y: previewImageView.center.y)
    }
    
    private func updateCurrentTime(_ time: TimeInterval) {
        if !slider.isTracking {
            slider.value = Float(time)
            currentTimeLabel.text = formatTime(time)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}
```

---

## Loading from Stash

### Sprite Loader Service

```swift
import UIKit

class SceneScrubberLoader {
    enum LoadError: Error {
        case invalidURL
        case invalidSprite
        case invalidVTT
    }
    
    func loadScrubber(for scene: Scene) async throws -> SpriteManager? {
        guard let spriteURLString = scene.paths.sprite,
              let vttURLString = scene.paths.vtt else {
            return nil
        }
        
        guard let spriteURL = URL(string: spriteURLString),
              let vttURL = URL(string: vttURLString) else {
            throw LoadError.invalidURL
        }
        
        // Download sprite image
        let (spriteData, _) = try await URLSession.shared.data(from: spriteURL)
        guard let spriteImage = UIImage(data: spriteData) else {
            throw LoadError.invalidSprite
        }
        
        // Download and parse VTT
        let (vttData, _) = try await URLSession.shared.data(from: vttURL)
        guard let vttContent = String(data: vttData, encoding: .utf8) else {
            throw LoadError.invalidVTT
        }
        
        let frames = VTTParser.parse(vttContent)
        
        return SpriteManager(spriteImage: spriteImage, frames: frames)
    }
}
```

---

## Usage Examples

### SwiftUI Video Player with Scrubber

```swift
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let scene: Scene
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var spriteManager: SpriteManager?
    @State private var duration: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Video player
            VideoPlayer(player: playerManager.player)
            
            // Scrubber with thumbnails
            if let spriteManager = spriteManager, duration > 0 {
                VideoScrubber(
                    player: playerManager.player,
                    spriteManager: spriteManager,
                    duration: duration
                )
                .padding()
                .background(Color.black.opacity(0.8))
            }
        }
        .task {
            await loadVideo()
        }
    }
    
    private func loadVideo() async {
        // Load video stream
        if let stream = scene.sceneStreams.first(where: { $0.mime_type == "application/vnd.apple.mpegurl" }),
           let streamURL = URL(string: stream.url) {
            playerManager.player.replaceCurrentItem(with: AVPlayerItem(url: streamURL))
        }
        
        // Load sprites
        do {
            spriteManager = try await SceneScrubberLoader().loadScrubber(for: scene)
        } catch {
            print("Failed to load scrubber: \(error)")
        }
        
        // Get duration
        if let item = playerManager.player.currentItem {
            let durationTime = try? await item.asset.load(.duration)
            duration = durationTime?.seconds ?? 0
        }
    }
}

class VideoPlayerManager: ObservableObject {
    let player = AVPlayer()
}
```

### UIKit Video Player with Scrubber

```swift
import UIKit
import AVFoundation
import AVKit

class VideoPlayerViewController: UIViewController {
    private let playerViewController = AVPlayerViewController()
    private let scrubberView = VideoScrubberView()
    private let player = AVPlayer()
    
    private var scene: Scene
    
    init(scene: Scene) {
        self.scene = scene
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPlayerViewController()
        setupScrubber()
        loadVideo()
    }
    
    private func setupPlayerViewController() {
        playerViewController.player = player
        
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        playerViewController.didMove(toParent: self)
    }
    
    private func setupScrubber() {
        view.addSubview(scrubberView)
        scrubberView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: scrubberView.topAnchor),
            
            scrubberView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrubberView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrubberView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrubberView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func loadVideo() {
        Task {
            // Load video stream
            if let stream = scene.sceneStreams.first(where: { $0.mime_type == "application/vnd.apple.mpegurl" }),
               let streamURL = URL(string: stream.url) {
                let item = AVPlayerItem(url: streamURL)
                player.replaceCurrentItem(with: item)
            }
            
            // Load sprites
            let spriteManager = try? await SceneScrubberLoader().loadScrubber(for: scene)
            
            // Get duration
            if let item = player.currentItem {
                let durationTime = try? await item.asset.load(.duration)
                let duration = durationTime?.seconds ?? 0
                
                // Configure scrubber
                await MainActor.run {
                    scrubberView.configure(
                        player: player,
                        spriteManager: spriteManager,
                        duration: duration
                    )
                }
            }
        }
    }
}
```

---

## Notes

- **Sprite Generation**: Sprites must be generated in Stash first (via Generate task)
- **Performance**: Sprite image cropping is fast; no performance concerns
- **Caching**: Consider caching downloaded sprites for offline use
- **Error Handling**: Gracefully degrade if sprites aren't available (show scrubber without previews)
- **Accessibility**: Ensure scrubber works with VoiceOver
- **Network**: Sprites can be large (1-2MB); consider showing loading indicator
- **Orientation**: Handle device rotation for preview positioning

---

## Add to GraphQLQueries.swift

```swift
// MARK: - Scene Sprites

static let sceneSprites = """
query GetSceneSprites($sceneId: ID!) {
    findScene(id: $sceneId) {
        id
        title
        paths {
            sprite
            vtt
        }
    }
}
"""
```

---

## Model Extension

Add sprite paths to your Scene model:

```swift
extension Scene {
    var hasSprites: Bool {
        paths.sprite != nil && paths.vtt != nil
    }
}
```
