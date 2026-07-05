import AVKit
import SwiftUI

/// クリップのフルスクリーン再生シート。非ミュートで、キャプション・出典・タイムコードを重ねる。
/// R2署名URLの失効でAVPlayerItemが.failedになったら、元URLからitemを作り直してリトライする。
struct FullscreenClipView: View {
    let url: URL
    let reference: SBReference

    @Environment(\.dismiss) private var dismiss
    @State private var player = AVPlayer()
    @State private var retryCount = 0

    /// 失効リトライの上限。恒久的な404等で無限ループしないように。
    private static let maxRetries = 3

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) { metadataOverlay }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
        }
        .background(.black)
        .task {
            loadItem()
            player.play()
        }
        .onReceive(player.publisher(for: \.currentItem?.status)) { status in
            // 署名URL失効対策: failedになったら元URLからitemを差し替えて再開
            if status == .failed, retryCount < Self.maxRetries {
                retryCount += 1
                loadItem()
                player.play()
            }
        }
        .onDisappear { player.pause() }
    }

    private func loadItem() {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let caption = reference.caption, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            HStack(spacing: 12) {
                if let platform = reference.platform, !platform.isEmpty {
                    Label(platform, systemImage: "play.rectangle")
                }
                if let timecode = reference.timecode, !timecode.isEmpty {
                    Label(timecode, systemImage: "clock")
                }
                if let source = reference.sourceUrl, let sourceURL = URL(string: source) {
                    Link(destination: sourceURL) {
                        Label("出典", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .padding()
        .padding(.bottom, 44) // VideoPlayer標準コントロールと重ならないように
    }
}
