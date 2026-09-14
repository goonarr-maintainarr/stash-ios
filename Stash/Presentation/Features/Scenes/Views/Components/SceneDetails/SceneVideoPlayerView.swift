import SwiftUI
import AVKit
import NukeUI

/// Inline video player component.
///
/// **Used by:** `SceneDetailView`
struct SceneVideoPlayerView: View {
    let player: AVPlayer?
    let isPlayerLoaded: Bool
    let onPlayerLoadedChange: (Bool) -> Void
    @State private var thumbnailUrl: URL?
    @EnvironmentObject var settings: SettingsStore
    let scene: Scene
    
    // New properties for stream selection
    let availableStreams: [SceneStreamEndpoint]
    let selectedStream: SceneStreamEndpoint?
    let onSelectStream: (SceneStreamEndpoint) -> Void
    
    // Sprite manager for scrubber thumbnails
    let spriteManager: SpriteManager?
    
    // Accent color from hero image for scrubber tint
    let heroAccentColor: Color
    
    var body: some View {
        Group {
            if isPlayerLoaded, let player = player {
                VStack(spacing: 8) {
                    CustomVideoPlayer(
                        player: player
                    )
                    .frame(height: 300)
                    .background(Color.black)
                    
                    // Video Scrubber with settings menu
                    if let duration = scene.files?.first?.duration, duration > 0 {
                        HStack(alignment: .top, spacing: 8) {
                            VideoScrubber(
                                player: player,
                                spriteManager: spriteManager,
                                duration: duration,
                                tintColor: heroAccentColor,
                                markers: scene.scene_markers ?? []
                            )
                            
                            streamSettingsMenu
                        }
                        .padding(.horizontal, 8)
                    }
                }
            } else {
                // Show thumbnail with play button overlay
                ZStack {
                    // Background thumbnail
                    if let url = settings.createImageUrl(path: scene.paths?.screenshot) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: UIScreen.main.bounds.width - 16, height: 300)
                                    .clipped()
                                    .blur(radius: settings.blurNsfw ? 20 : 0) // Blur if NSFW setting enabled
                            } else {
                                Rectangle().fill(Color.black)
                                    .frame(height: 300)
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 300)
                    }

                    // Foreground overlay
                    if player != nil {
                        // Auto-load the player when ready
                        Color.clear
                            .onAppear {
                                onPlayerLoadedChange(true)
                            }
                    } else {
                        VStack {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No Stream Available")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Stream settings even when not playing
                    VStack {
                        HStack {
                            Spacer()
                            streamSettingsMenu
                                .padding(12)
                        }
                        Spacer()
                    }
                    
                    // Playback Progress Bar
                    if let resumeTime = scene.resume_time,
                       let duration = scene.files?.first?.duration,
                       duration > 0,
                       resumeTime > 0,
                       resumeTime < duration {
                        
                        let progress = min(max(resumeTime / duration, 0), 1)
                        
                        VStack {
                            Spacer()
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.4))
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: proxy.size.width * progress)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }
                .frame(height: 300)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 8)
    }
    
    private var streamSettingsMenu: some View {
        Menu {
            if availableStreams.isEmpty {
                Text("Loading streams...")
            } else {
                Text("Select Stream Quality")
                Divider()
                
                ForEach(availableStreams) { endpoint in
                    Button {
                        onSelectStream(endpoint)
                    } label: {
                        HStack {
                            Text(endpoint.displayLabel)
                            if endpoint.id == selectedStream?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22))
                .foregroundColor(heroAccentColor)
                .frame(width: 28)
                .padding(.top, 3)
        }
    }
}
