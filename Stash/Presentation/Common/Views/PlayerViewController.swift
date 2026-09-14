import SwiftUI
import AVKit

struct PlayerViewController: UIViewControllerRepresentable {
    let player: AVPlayer

    init(player: AVPlayer) {
        self.player = player
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // We provide custom controls in SwiftUI overlay
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Keep the player instance in sync if needed
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
