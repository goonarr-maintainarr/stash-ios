import SwiftUI
import NukeUI
import AVKit

/// A compact list row for displaying a scene.
///
/// **Used by:** `SceneListView` (List Layout)
struct SceneCompactRow: View {
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
        HStack(alignment: .top, spacing: 0) {
            // Thumbnail
            SceneCardThumbnail(
                config: config,
                isPlayingPreview: $isPlayingPreview,
                player: player,
                scrubTime: $scrubTime,
                actions: actions,
                isPressed: $isPressed
            )
            .frame(width: 180)
            .clipped()
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(config.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
//                    .fixedSize(horizontal: false, vertical: true)
                
                
                if let studio = config.studio {
                    Text(studio)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            HapticManager.lightImpact()
                            actions.onStudioClick?()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let date = config.date {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 0) {
                    if !config.performers.isEmpty {
                        ForEach(Array(config.performers.enumerated()), id: \.element.id) { index, cardPerformer in
                            if let performer = scene.performers?.first(where: { $0.id == cardPerformer.id }) {
                                if index > 0 {
                                    Text(", ")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                Text(cardPerformer.name)
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                    .onTapGesture {
                                        HapticManager.lightImpact()
                                        actions.onPerformerClick?(performer.id, performer.name ?? "Unknown")
                                    }
                            } else {
                                if index > 0 {
                                    Text(", ")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(cardPerformer.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6){
                        // Markers
                        if let markers = scene.scene_markers, !markers.isEmpty {
                            HStack(spacing: 2) {
                                Image("MapMarker")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                Text("\(markers.count)")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        }
                        
                        // O-Counter
                        if let oCounter = scene.o_counter, oCounter > 0 {
                            HStack(spacing: 2) {
                                Image("SweatDrops") // Updated icon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                Text("\(oCounter)")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        }
                        
                        //Rating
                        if let rating = scene.rating100 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                Text(String(format: "%g", Double(rating) / 20.0))
                                    .font(.caption)
                            }
                            .foregroundColor(.yellow)
                        }
                    }
                    
                }
            }
            .padding(8) // Padding for info section only
        }
        .frame(height: 120)
        .background(Color.stashCardBackground)
        .cornerRadius(8)
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



// Scene extension moved to Scene+Extensions.swift

#Preview {
    ZStack {
        Color.stashBackground.ignoresSafeArea()
        SceneCompactRow(scene: Scene.preview)
            .environmentObject(SettingsStore())
            .padding()
    }
}
