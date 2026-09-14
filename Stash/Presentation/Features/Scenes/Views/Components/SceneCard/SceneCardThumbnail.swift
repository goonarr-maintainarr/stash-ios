import SwiftUI
import NukeUI
import AVKit

/// Displays the scene image or animated preview with status overlays.
///
/// **Used by:** `SceneCard`
struct SceneCardThumbnail: View {
    let config: SceneCardConfiguration
    @Binding var isPlayingPreview: Bool
    let player: AVPlayer?
    @Binding var scrubTime: Double?
    let actions: SceneCardActions
    @Binding var isPressed: Bool  // For bounce animation (controlled by parent)
    @EnvironmentObject var settings: SettingsStore
    
    @State private var spriteManager: SpriteManager?
    @State private var isScrubbing = false
    @State private var isScrubberArmed = false  // Long-press activated
    @State private var scrubImage: UIImage?
    @State private var scrubProgress: Double = 0
    @State private var loadTask: Task<Void, Never>?
    @State private var lastHapticFrameIndex: Int?
    
    /// Whether scrubbing is available (requires sprite data)
    private var canScrub: Bool {
        config.spriteUrl != nil && config.vttUrl != nil && config.duration != nil && config.duration! > 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isPlayingPreview, let player = player {
                // Show video player
                ZStack {
                    // Use CustomVideoPlayer with fill config
                    CustomVideoPlayer(player: player, configuration: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    
                    // Tap to stop preview
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.lightImpact()
                            isPlayingPreview = false
                        }
                }
            } else {
                thumbnailImage(geometry)
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    @ViewBuilder
    private func thumbnailImage(_ geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            // Base Image or Scrub Image
            if let scrubImage = scrubImage, scrubTime != nil {
                Image(uiImage: scrubImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                if let url = config.imageUrl {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .blur(radius: settings.blurNsfw ? 20 : 0)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            
            // Status/Overlay - hidden when scrubbing
            if scrubTime == nil {
                if let statusColor = config.statusColor {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(statusColor)
                        
                        if let statusText = config.statusText {
                            Text(statusText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(statusColor)
                                .lineLimit(1)
                        }
                    }
                    .frame(height: config.statusText != nil ? nil : 4)
                }
                
                // Playback Progress Bar (existing)
                if let resumeTime = config.resumeTime,
                   let duration = config.duration,
                   duration > 0,
                   resumeTime > 0,
                   resumeTime < duration {
                    
                    let progress = min(max(resumeTime / duration, 0), 1)
                    
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.black.opacity(0.4))
                        Rectangle()
                            .fill(Color(red: 0x2C/255.0, green: 0xB6/255.0, blue: 0xFF/255.0))
                            .frame(width: geometry.size.width * progress)
                    }
                    .frame(height: 4)
                }
            }
            
            // Scrubber Progress Bar (Active)
            if scrubTime != nil {
                ZStack(alignment: .leading) {
                     Rectangle().fill(Color.black.opacity(0.4))
                     Rectangle()
                         .fill(Color(red: 0x2C/255.0, green: 0xB6/255.0, blue: 0xFF/255.0))
                         .frame(width: geometry.size.width * scrubProgress)
                 }
                .frame(height: 4)
                .transition(.opacity)
            }
            
            // Navigation Area - for tapping to open scene
            // Covers top 75% if scrubbing is available, otherwise full area
            VStack {
                Color.clear
                    .frame(height: canScrub ? geometry.size.height * 0.75 : geometry.size.height)
                    .contentShape(Rectangle())
                    .onPress(isPressed: $isPressed) {
                        actions.onSceneClick?(scrubTime)
                    }
                    .onPreviewGesture(enabled: settings.showScenePreviews && config.videoPreviewUrl != nil) {
                        isPlayingPreview = true
                    }
                if canScrub {
                    Spacer()
                }
            }
            
            // Scrubbing Area (Bottom 25%) - only for local scenes with sprites
            // Requires long press to activate, then drag to scrub
            if canScrub {
                Color.clear
                    .frame(height: geometry.size.height * 0.25)
                    // Reduce touch target width to prevent accidental scrubbing when scrolling from edges
                    .frame(width: max(0, geometry.size.width - 40))
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.75)
                            .onEnded { _ in
                                // Arm the scrubber after long press
                                isScrubberArmed = true
                                HapticManager.heavyImpact()
                                // Load sprites preemptively
                                if spriteManager == nil {
                                    loadSprites()
                                }
                            }
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                switch value {
                                case .first(_):
                                    // Still in long press phase - do nothing
                                    break
                                case .second(_, let dragValue):
                                    // Long press completed, now dragging
                                    if isScrubberArmed, let drag = dragValue {
                                        handleScrub(value: drag, geometry: geometry)
                                    }
                                }
                            }
                            .onEnded { _ in
                                // Reset states when gesture ends
                                isScrubbing = false
                                isScrubberArmed = false
                                lastHapticFrameIndex = nil
                            }
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Group {
                if let time = scrubTime {
                    Text(Self.timeFormatter.string(from: time) ?? "")
                } else if let runtime = config.runtime {
                    Text(runtime)
                }
            }
            .font(.caption2)
            .bold()
            .padding(4)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(8)
        }
    }
    
    private func handleScrub(value: DragGesture.Value, geometry: GeometryProxy) {
        // Init Sprite Manager if needed
        if spriteManager == nil {
            loadSprites()
        }
        
        if !isScrubbing {
            isScrubbing = true
        }
        let width = geometry.size.width
        let location = value.location.x
        
        // Calculate progress
        let progress = min(max(location / width, 0), 1)
        scrubProgress = progress
        
        // Calculate time
        if let duration = config.duration, duration > 0 {
            let time = duration * progress
            scrubTime = time
            
            // Update image and trigger haptics
            if let manager = spriteManager {
                // Haptic feedback on frame change
                if let index = manager.frameIndex(for: time) {
                    if index != lastHapticFrameIndex {
                        HapticManager.selection()
                        lastHapticFrameIndex = index
                    }
                }
                
                if let thumb = manager.thumbnail(for: time) {
                    scrubImage = thumb
                }
            }
        }
    }
    
    private func loadSprites() {
        guard loadTask == nil, spriteManager == nil,
              let spriteUrl = config.spriteUrl,
              let vttUrl = config.vttUrl else { return }
        
        loadTask = Task {
            let loader = SceneScrubberLoader(settings: settings)
            if let manager = try? await loader.loadScrubber(spriteUrl: spriteUrl, vttUrl: vttUrl) {
                await MainActor.run {
                    self.spriteManager = manager
                    // Trigger initial update if already scrubbing?
                    if let time = scrubTime {
                         self.scrubImage = manager.thumbnail(for: time)
                    }
                }
            }
        }
    }
}
