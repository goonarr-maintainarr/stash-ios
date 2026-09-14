import SwiftUI
import AVFoundation
import Combine

/// A video scrubber slider with sprite thumbnail preview during seeking.
///
/// Shows a thumbnail preview above the scrubber when the user drags to seek.
/// An interactive thumbnail scrubber for previewing scene content.
///
/// **Used by:**
/// - `SceneCard`
/// - `SceneDetailView`
struct VideoScrubber: View {
    let player: AVPlayer
    let spriteManager: SpriteManager?
    let duration: TimeInterval
    var tintColor: Color = .red
    var markers: [SceneMarker] = []
    
    @State private var scrubberValue: Double = 0
    @State private var isScrubbing = false
    @State private var showPreview = false
    @State private var previewTime: TimeInterval = 0
    @State private var previewImage: UIImage?
    @State private var previewPosition: CGFloat = 0
    @State private var timeObserverToken: Any?
    @State private var lastHapticMarker: Int = 0
    @State private var isPlaying: Bool = false
    @State private var isMuted: Bool = false
    @State private var hoveredMarker: SceneMarker? = nil
    
    // Haptic every 60 seconds of scrubbing
    private let hapticInterval: Int = 60
    // Proximity threshold for marker hover (in seconds)
    private let markerProximity: Double = 10.0
    
    // Thumbnail constants (approx 30% larger than 160x90)
    private let thumbWidth: CGFloat = 208
    private let thumbHeight: CGFloat = 117
    private let thumbOffset: CGFloat = -155
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                // Main control row: Play - Slider - Mute
                HStack(spacing: 12) {
                    // Play/Pause button
                    Button(action: {
                        HapticManager.mediumImpact()
                        togglePlayback()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .frame(width: 28)
                    }
                    .foregroundColor(tintColor)
                    
                    // Slider
                    Slider(
                        value: $scrubberValue,
                        in: 0...max(duration, 1),
                        onEditingChanged: { editing in
                            isScrubbing = editing
                            showPreview = editing && spriteManager != nil
                            
                            if editing {
                                lastHapticMarker = Int(scrubberValue) / hapticInterval
                            }
                            
                            if !editing {
                                player.seek(to: CMTime(seconds: scrubberValue, preferredTimescale: 600))
                            }
                        }
                    )
                    .tint(tintColor)
                    .overlay(alignment: .bottom) {
                        // Marker tick marks overlaid on slider
                        if !markers.isEmpty {
                            GeometryReader { sliderGeom in
                                ForEach(markers) { marker in
                                    let position = CGFloat(marker.seconds / max(duration, 1)) * sliderGeom.size.width
                                    Rectangle()
                                        .fill(tintColor)
                                        .frame(width: 2, height: 9)
                                        .offset(x: position - 1, y: 0)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: scrubberValue) { _, newValue in
                        if isScrubbing {
                            previewTime = newValue
                            updatePreview(time: newValue, in: geometry)
                            updateHoveredMarker(time: newValue)
                            
                            let currentMarker = Int(newValue) / hapticInterval
                            if currentMarker != lastHapticMarker {
                                HapticManager.selection()
                                lastHapticMarker = currentMarker
                            }
                        }
                    }
                    
                    // Mute button
                    Button(action: {
                        HapticManager.lightImpact()
                        toggleMute()
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 22))
                            .frame(width: 28)
                    }
                    .foregroundColor(tintColor)
                }
                
                // Time labels and hovered marker name
                ZStack(alignment: .bottom) {
                    // Time labels at edges (always in same position)
                    HStack {
                        Text(formatTime(scrubberValue))
                            .font(.footnote)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(tintColor)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.footnote)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(tintColor)
                    }
                    .padding(.top, 4)
                    
                    // Marker name centered (overlaid, doesn't affect layout)
                    if isScrubbing, let marker = hoveredMarker {
                        Text(marker.title)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(tintColor)
                            .lineLimit(1)
                    }
                }
                .frame(height: 24)
                .padding(.bottom, 4)
            }
            .overlay(alignment: .top) {
                // Thumbnail preview overlaying above (over the video player)
                if showPreview, let image = previewImage {
                    thumbnailPreview(image: image)
                        .offset(x: clampedPreviewOffset(in: geometry), y: thumbOffset)
                }
            }
        }
        .frame(height: 60)
        .onAppear {
            setupTimeObserver()
            isPlaying = player.timeControlStatus == .playing
            isMuted = player.isMuted
        }
        .onDisappear {
            removeTimeObserver()
        }
        .onReceive(player.publisher(for: \.timeControlStatus)) { status in
            isPlaying = (status == .playing)
        }
    }
    
    // MARK: - Playback Controls
    
    private func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func toggleMute() {
        player.isMuted.toggle()
        isMuted = player.isMuted
    }
    
    // MARK: - Thumbnail Preview
    
    @ViewBuilder
    private func thumbnailPreview(image: UIImage) -> some View {
        VStack(spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: thumbWidth, height: thumbHeight)
                .background(Color.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.5), radius: 10)
            
            Text(formatTime(previewTime))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
        }
    }
    
    // MARK: - Helpers
    
    private func updatePreview(time: TimeInterval, in geometry: GeometryProxy) {
        // Get thumbnail for this time
        previewImage = spriteManager?.thumbnail(for: time)
        
        // Calculate preview position based on scrubber progress
        let progress = CGFloat(time / max(duration, 1))
        previewPosition = progress * geometry.size.width
    }
    
    private func clampedPreviewPosition(in geometry: GeometryProxy) -> CGFloat {
        // Keep preview within bounds
        let previewWidth: CGFloat = thumbWidth
        let minX = previewWidth / 2
        let maxX = geometry.size.width - previewWidth / 2
        return max(minX, min(previewPosition, maxX))
    }
    
    private func clampedPreviewOffset(in geometry: GeometryProxy) -> CGFloat {
        // Calculate offset from center for .offset() modifier
        let previewWidth: CGFloat = thumbWidth
        let centerX = geometry.size.width / 2
        let minX = previewWidth / 2
        let maxX = geometry.size.width - previewWidth / 2
        let clampedX = max(minX, min(previewPosition, maxX))
        return clampedX - centerX
    }
    
    private func updateHoveredMarker(time: TimeInterval) {
        // Find closest marker within proximity threshold
        let newMarker = markers.first { marker in
            abs(marker.seconds - time) <= markerProximity
        }
        
        // Heavy haptic when entering a new marker zone
        if let new = newMarker, new.id != hoveredMarker?.id {
            HapticManager.heavyImpact()
        }
        
        hoveredMarker = newMarker
    }
    
    private func clampedMarkerLabelOffset(position: CGFloat, in geometry: GeometryProxy) -> CGFloat {
        // Keep marker label within bounds
        let labelWidth: CGFloat = 100 // Approximate
        let minX = labelWidth / 2
        let maxX = geometry.size.width - labelWidth / 2
        let clampedX = max(minX, min(position, maxX))
        return clampedX - labelWidth / 2
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !isScrubbing {
                scrubberValue = time.seconds
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VideoScrubber(
            player: AVPlayer(),
            spriteManager: nil,
            duration: 3600
        )
        .padding()
    }
}
