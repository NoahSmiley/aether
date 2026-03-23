import SwiftUI
import AVKit

struct LiveStreamPlayerView: View {
    let streamName: String
    let streamURL: URL

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                SimplePlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            let avPlayer = AVPlayer(url: streamURL)
            avPlayer.automaticallyWaitsToMinimizeStalling = true
            self.player = avPlayer
            avPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }
}

struct SimplePlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}
