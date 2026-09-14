import SwiftUI
import AVKit

/// Configuration options for the CustomVideoPlayer dependency injection
struct VideoPlayerConfiguration {
    var gravity: AVLayerVideoGravity = .resizeAspect
    var showsPlaybackControls: Bool = false
    var allowsPictureInPicturePlayback: Bool = false
    var backgroundColor: UIColor = .black
    
    static let standard = VideoPlayerConfiguration()
    static let fill = VideoPlayerConfiguration(gravity: .resizeAspectFill)
}

/// A custom video player wrapper utilizing AVKit.
///
/// **Used by:**
/// - `VideoScrubber` (Preview thumbnail generation context)
/// - `SceneDetailView` (Embedded playback)
struct CustomVideoPlayer: View {
    let player: AVPlayer
    var configuration: VideoPlayerConfiguration = .standard
    
    var body: some View {
        AVPlayerContainerViewController(player: player, configuration: configuration)
    }
}

private struct AVPlayerContainerViewController: UIViewControllerRepresentable {
    let player: AVPlayer
    let configuration: VideoPlayerConfiguration

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        applyConfiguration(to: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player {
            uiViewController.player = player
        }
        applyConfiguration(to: uiViewController)
    }
    
    private func applyConfiguration(to controller: AVPlayerViewController) {
        if controller.showsPlaybackControls != configuration.showsPlaybackControls {
            controller.showsPlaybackControls = configuration.showsPlaybackControls
        }
        if controller.videoGravity != configuration.gravity {
            controller.videoGravity = configuration.gravity
        }
        if controller.allowsPictureInPicturePlayback != configuration.allowsPictureInPicturePlayback {
            controller.allowsPictureInPicturePlayback = configuration.allowsPictureInPicturePlayback
        }
        if controller.view.backgroundColor != configuration.backgroundColor {
            controller.view.backgroundColor = configuration.backgroundColor
        }
    }
}
