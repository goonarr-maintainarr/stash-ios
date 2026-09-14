import SwiftUI
import AVKit

/// A draggable, resizable floating video player (PIP style) that overlays the entire app.
///
/// **Used by:**
/// - `MainTabView` (Root overlay)
/// - Controlled by `FloatingVideoPlayerService`
struct FloatingVideoPlayerView: View {
    @EnvironmentObject var settings: SettingsStore
    
    var manager: FloatingVideoPlayerService
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    @State private var spriteManager: SpriteManager?
    @State private var heroAccentColor: Color = .red
    
    @State private var showControls = true
    @State private var autoHideTask: Task<Void, Never>?
    
    let basePlayerWidth: CGFloat = 224
    let basePlayerHeight: CGFloat = 126
    
    var playerWidth: CGFloat { basePlayerWidth * scale }
    var playerHeight: CGFloat { basePlayerHeight * scale }
    
    var body: some View {
        GeometryReader { geometry in
            if manager.isPlaying, let player = manager.currentPlayer {
                ZStack(alignment: .topTrailing) {
                    // Video player
                    CustomVideoPlayer(
                        player: player
                    )
                        .frame(width: playerWidth, height: playerHeight)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        .onTapGesture {
                            toggleControls()
                        }
                    
                    Group {
                        // Scrubber Overlay
                        if let scene = manager.currentScene,
                           let duration = scene.files?.first?.duration,
                           duration > 0 {
                            VideoScrubber(
                                player: player,
                                spriteManager: spriteManager,
                                duration: duration,
                                tintColor: heroAccentColor,
                                markers: scene.scene_markers ?? []
                            )
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .frame(width: playerWidth, height: playerHeight, alignment: .bottom)
                            .simultaneousGesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    autoHideTask?.cancel()
                                }
                                .onEnded { _ in
                                    scheduleAutoHide()
                                }
                            )
                        }
                        
                        // Close button
                        Button(action: {
                            HapticManager.lightImpact()
                            manager.stopPlaying()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                    .opacity(showControls ? 1 : 0)
                }
                .position(
                    x: manager.playerPosition.x + offset.width,
                    y: manager.playerPosition.y + offset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                HapticManager.lightImpact()
                            }
                            offset = value.translation
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // Update permanent position
                            let newPosition = CGPoint(
                                x: manager.playerPosition.x + offset.width,
                                y: manager.playerPosition.y + offset.height
                            )
                            offset = .zero
                            
                            // Snap to edges with animation
                            snapToNearestEdge(from: newPosition, in: geometry.size)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            let newScale = scale * delta
                            // Constrain scale between 0.5x and 2.5x
                            scale = min(max(newScale, 0.5), 2.5)
                        }
                        .onEnded { value in
                            lastScale = 1.0
                            HapticManager.lightImpact()
                        }
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: manager.playerPosition)
                .animation(nil, value: offset)
                .task(id: manager.currentScene?.id) {
                    await loadSprites()
                }
                .onAppear {
                    scheduleAutoHide()
                }
                .onDisappear {
                    autoHideTask?.cancel()
                }
            }
        }
    }
    
    private func snapToNearestEdge(from position: CGPoint, in screenSize: CGSize) {
        let padding: CGFloat = 4
        
        // Constrain to screen bounds
        var newX = position.x
        var newY = position.y
        
        // Keep within horizontal bounds
        if newX < playerWidth / 2 + padding {
            newX = playerWidth / 2 + padding
        } else if newX > screenSize.width - playerWidth / 2 - padding {
            newX = screenSize.width - playerWidth / 2 - padding
        }
        
        // Keep within vertical bounds
        if newY < playerHeight / 2 + padding + 60 { // Account for nav bar
            newY = playerHeight / 2 + padding + 60
        } else if newY > screenSize.height - playerHeight / 2 - padding - 100 { // Account for tab bar
            newY = screenSize.height - playerHeight / 2 - padding - 100
        }
        

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            manager.playerPosition = CGPoint(x: newX, y: newY)
        }
    }
    
    private func toggleControls() {
        withAnimation {
            showControls.toggle()
        }
        
        if showControls {
            scheduleAutoHide()
        } else {
            autoHideTask?.cancel()
        }
    }
    
    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation {
                    showControls = false
                }
            }
        }
    }
    
    private func loadSprites() async {
        guard let scene = manager.currentScene else { return }
        
        // Load sprites for scrubber thumbnails
        if scene.paths?.sprite != nil, scene.paths?.vtt != nil {
            let loader = SceneScrubberLoader(settings: settings)
            spriteManager = try? await loader.loadScrubber(for: scene)
        }
        
        // Extract accent color
        if let screenshotPath = scene.paths?.screenshot,
           let screenshotURL = settings.createImageUrl(path: screenshotPath) {
            if let extractedColor = await HeroAccentColor.extract(from: screenshotURL) {
                heroAccentColor = extractedColor
            }
        }
    }
}
