import os
import SwiftUI
import NukeUI
import AVKit
import AVFoundation


private let logger = Logger(subsystem: "com.stash.app", category: "SceneMarkersSection")

/// Interactive list of scene markers.
///
/// **Used by:** `SceneDetailView`
struct SceneMarkersSection: View {
    let markers: [SceneMarker]
    let onSeek: (Double) -> Void
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Markers")
                    .font(.headline)
                if !markers.isEmpty {
                    HStack(spacing: 6) {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image("MapMarker")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .foregroundColor(.white)
                        Text("\(markers.count)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(markers) { marker in
                        SceneMarkerCard(marker: marker, onSeek: onSeek)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SceneMarkerCard: View {
    let marker: SceneMarker
    let onSeek: (Double) -> Void
    @EnvironmentObject var settings: SettingsStore
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var stopTask: Task<Void, Never>?
    @State private var wasVisible = false
    
    /// Delay before stopping player when scrolling off-screen (seconds)
    private let stopDelay: TimeInterval = 2.0
    
    var body: some View {
        Button(action: {
            HapticManager.mediumImpact()
            onSeek(marker.seconds)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Media
                ZStack(alignment: .bottomTrailing) {
                    if settings.showMarkerPreviews, let streamPath = marker.stream {
                        // Video Player
                        if let player = player {
                            VideoPlayer(player: player)
                                .disabled(true) // Disable player controls/interaction so button works
                                .aspectRatio(16/9, contentMode: .fill)
                                .blur(radius: settings.blurNsfw ? 20 : 0)
                        } else {
                            // Placeholder while loading - visibility logic handles starting
                            markerImage
                        }
                    } else {
                        // Static Image
                        markerImage
                    }
                    
                    // Timestamp badge
                    Text(formatDuration(marker.seconds))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(.trailing, 20)
                        .padding(.bottom, 6)
                }
                .frame(width: 320, height: 180) // Reduced height slightly for 16:9ish aspect
                .background(Color.black)
                .cornerRadius(8)
                .clipped()
                .onDisappear {
                    scheduleStopPlayer()
                }
                
                // Title
                Text(marker.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .frame(width: 320, alignment: .leading)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        checkVisibility(frame: geometry.frame(in: .global))
                    }
                    .onChange(of: geometry.frame(in: .global)) { frame in
                        checkVisibility(frame: frame)
                    }
            }
        )
    }
    
    /// Tracks visibility and only triggers actions on actual visibility changes
    private func checkVisibility(frame: CGRect) {
        let screenBounds = UIScreen.main.bounds
        let isNowVisible = frame.intersects(screenBounds)
        
        // Only act on visibility TRANSITIONS, not every frame
        if isNowVisible && !wasVisible {
            // Became visible
            wasVisible = true
            
            // Cancel any pending stop
            if stopTask != nil {
                logger.debug("🎬 [Marker] Cancel scheduled stop (visible again): \(marker.title)")
                stopTask?.cancel()
                stopTask = nil
            }
            
            if !isPlaying && settings.showMarkerPreviews, let path = marker.stream {
                startPlayer(path: path)
            }
        } else if !isNowVisible && wasVisible {
            // Became not visible
            wasVisible = false
            
            if isPlaying && stopTask == nil {
                scheduleStopPlayer()
            }
        }
    }
    
    @ViewBuilder
    private var markerImage: some View {
        if let url = settings.createImageUrl(path: marker.preview) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: settings.blurNsfw ? 20 : 0)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                }
            }
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
        }
    }
    
    private func startPlayer(path: String) {
        guard let url = settings.createImageUrl(path: path) else { return }
        
        logger.debug("🎬 [Marker] Starting player for: \(marker.title)")
        
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = true // Always mute marker previews
        newPlayer.actionAtItemEnd = .none
        
        // Loop logic
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        
        self.player = newPlayer
        newPlayer.play()
        isPlaying = true
    }
    
    /// Schedules player stop with a delay to avoid recreation during fast scrolling
    private func scheduleStopPlayer() {
        // Cancel any existing scheduled stop
        stopTask?.cancel()
        
        logger.debug("🎬 [Marker] Scheduling stop in \(stopDelay)s for: \(marker.title)")
        
        stopTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(stopDelay * 1_000_000_000))
            
            // Check if task was cancelled while sleeping
            guard !Task.isCancelled else {
                logger.debug("🎬 [Marker] Stop cancelled (view visible again): \(marker.title)")
                return
            }
            
            await MainActor.run {
                stopPlayer()
            }
        }
    }
    
    private func stopPlayer() {
        guard player != nil else { return }
        logger.debug("🎬 [Marker] Stopping player for: \(marker.title)")
        stopTask?.cancel()
        stopTask = nil
        player?.pause()
        player = nil // Release player
        isPlaying = false
        wasVisible = false // Reset so coming back on screen triggers restart
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "0:00"
    }
}

// Simple VideoPlayer wrapper since we are in a sub-file not importing Common
private struct VideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .black
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
}

