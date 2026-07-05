import AVFoundation
import SwiftUI

/// AVPlayerLayerを直接貼るUIViewラッパー。コントロール非表示のインライン再生用。
/// VideoPlayer(AVKit)と違い再生UIを一切出さず、カードのメディア枠を埋める。
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }

    /// layerClassの差し替えでUIView自体をAVPlayerLayerにする(フレーム追従が自動になる)。
    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
