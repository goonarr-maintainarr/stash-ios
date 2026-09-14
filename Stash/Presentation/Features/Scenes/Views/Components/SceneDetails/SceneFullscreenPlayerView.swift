import SwiftUI
import AVKit

/// A dedicated view for full-screen video playback.
///
/// **Presented by:** `SceneDetailView` (Landscape/Expand)
struct SceneFullscreenPlayerView: View {
    let player: AVPlayer
    let scene: Scene
    let spriteManager: SpriteManager?
    let heroColor: Color
    @Binding var isPresented: Bool
    
    @State private var showControls = true
    @State private var autoHideTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            CustomVideoPlayer(player: player)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    toggleControls()
                }
            
            // Controls Overlay
            VStack {
                // Top Bar - Optional Close Button or Title?
                // For now just consistent scrubber at bottom
                HStack {
                    Button(action: {
                        // Return to portrait/dismiss
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 48) // Align with scrubber
                    .padding(.top, 40)
                    
                    Spacer()
                }
                
                Spacer()
                
                if let duration = scene.files?.first?.duration, duration > 0 {
                    VideoScrubber(
                        player: player,
                        spriteManager: spriteManager,
                        duration: duration,
                        tintColor: heroColor,
                        markers: scene.scene_markers ?? []
                    )
                    .padding(.horizontal, 48)
                    .padding(.bottom, 32)
                    // Prevent auto-hide when scrubbing
                    .simultaneousGesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            autoHideTask?.cancel()
                            showControls = true
                        }
                        .onEnded { _ in
                            scheduleAutoHide()
                        }
                    )
                }
            }
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showControls)
        }
        .statusBar(hidden: !showControls)
        .onAppear {
            scheduleAutoHide()
        }
        .onDisappear {
            autoHideTask?.cancel()
        }
    }
    
    private func toggleControls() {
        showControls.toggle()
        
        if showControls {
            scheduleAutoHide()
        } else {
            autoHideTask?.cancel()
        }
    }
    
    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                showControls = false
            }
        }
    }
}
