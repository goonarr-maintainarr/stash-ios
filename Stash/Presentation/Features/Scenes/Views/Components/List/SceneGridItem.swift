import SwiftUI
import NukeUI
import AVKit

/// A grid item for displaying a scene.
///
/// **Used by:** `SceneListView` (Grid Layout)
struct SceneGridItem: View {
    let scene: Scene
    let actions: SceneCardActions
    @EnvironmentObject var settings: SettingsStore
    @State private var scrubTime: Double?
    @State private var isPlayingPreview = false
    @State private var player: AVPlayer?
    @State private var playerObserver: NSObjectProtocol?
    @State private var isPressed = false  // For bounce animation
    
    init(scene: Scene, actions: SceneCardActions = .none) {
        self.scene = scene
        self.actions = actions
    }
    
    private var config: SceneCardConfiguration {
        SceneCardConfiguration(scene: scene, settings: settings)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with navigation handled via callbacks
            SceneCardThumbnail(
                config: config,
                isPlayingPreview: $isPlayingPreview,
                player: player,
                scrubTime: $scrubTime,
                actions: actions,
                isPressed: $isPressed
            )
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(8)
            .clipped()
            
            // Info
            VStack(alignment: .leading, spacing: 0) {
                // Title at the top - Fixed height ensures it always takes up 2 lines of space
                Text(config.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    // Set a fixed height for 2 lines so 1-line titles don't collapse the space
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.lightImpact()
                        actions.onSceneClick?(scrubTime)
                    }
                
                // This pushes the performers to the absolute bottom of the container
                Spacer(minLength: 4)
                
                // Performers at the bottom
                if let performers = scene.performers, !performers.isEmpty {
                    HStack(spacing: 2) {
                        let topPerformers = Array(performers.prefix(2))
                        ForEach(topPerformers.indices, id: \.self) { index in
                            let performer = topPerformers[index]
                            if index > 0 {
                                Text(",")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Text(performer.name ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.lightImpact()
                                    actions.onPerformerClick?(performer.id, performer.name ?? "Unknown")
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60) // Fixed height for consistency
            .background(Color.stashCardBackground)
        }
        .background(Color.stashCardBackground)
        .cornerRadius(8) // Apply corner radius to default container
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onChange(of: isPlayingPreview) { _, playing in
            if playing {
                if player == nil {
                    startPreview()
                }
            } else {
                stopPreview()
            }
        }
        .onDisappear {
            scrubTime = nil
            if isPlayingPreview {
                isPlayingPreview = false
            }
            stopPreview()
        }
    }
    
    // MARK: - Preview Player
    
    private func startPreview() {
        guard let url = config.videoPreviewUrl else { return }
        
        // Only create player if needed
        if player == nil {
            let playerItem = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.isMuted = true
            newPlayer.actionAtItemEnd = .none // Loop
            
            // Loop logic - store observer for cleanup
            let observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak newPlayer] _ in
                newPlayer?.seek(to: .zero)
                newPlayer?.play()
            }
            
            self.playerObserver = observer
            self.player = newPlayer
            newPlayer.play()
        } else {
            player?.play()
        }
    }
    
    private func stopPreview() {
        player?.pause()
        player = nil // Release player
        
        // Remove notification observer to prevent memory leak
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
    }
}


#Preview {
    ZStack {
        Color.stashBackground.ignoresSafeArea()
        SceneGridItem(scene: Scene.preview)
            .environmentObject(SettingsStore())
            .padding()
            .frame(width: 200)
    }
}
