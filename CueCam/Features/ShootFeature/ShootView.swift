import AVFoundation
import AVKit
import ComposableArchitecture
import SwiftUI
import UIKit

/// 横持ち前提の撮影画面。全面プレビュー + 下部スクリプトバー + 右端録画ボタン
struct ShootView: View {
    @Bindable var store: StoreOf<ShootFeature>
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let session = store.session {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            }

            switch store.phase {
            case .preparing:
                ProgressView()
                    .tint(.white)

            case .denied:
                deniedView

            case .ready, .recording:
                shootingOverlay

            case .reviewing(let url):
                reviewOverlay(url: url)

            case .finished:
                finishedView
            }
        }
        .statusBarHidden()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - 撮影中オーバーレイ

    private var shootingOverlay: some View {
        ZStack {
            if store.session == nil {
                Text("カメラを利用できません(実機で実行してください)")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack {
                if store.phase == .recording {
                    recIndicator
                        .padding(.top, 12)
                }
                Spacer()
                scriptBar
            }

            HStack {
                Spacer()
                recordButton
            }
            .padding(.trailing, 28)
        }
    }

    private var recIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppColor.record)
                .frame(width: 10, height: 10)
            Text("REC")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.5), in: Capsule())
    }

    private var scriptBar: some View {
        HStack(spacing: 12) {
            Text("\(store.currentIndex + 1)/\(store.scripts.count)")
                .font(.footnote.bold().monospacedDigit())
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColor.accent, in: Capsule())

            Text(store.currentScript?.text ?? "")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var recordButton: some View {
        Button {
            store.send(.recordButtonTapped)
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 68, height: 68)
                if store.phase == .recording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.record)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(AppColor.record)
                        .frame(width: 56, height: 56)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - テイク確認オーバーレイ

    private func reviewOverlay(url: URL) -> some View {
        ZStack {
            LoopingPlayerView(url: url)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Text(store.currentScript?.text ?? "")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Button("撮り直す") { store.send(.retakeTapped) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Button("OK 次へ") { store.send(.okTapped) }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - 完了 / 権限拒否

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.accent)
            Text("全\(store.scripts.count)カットの撮影が完了しました")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Button("最初から撮る") { store.send(.restartTapped) }
                .buttonStyle(.bordered)
                .tint(.white)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
            Text("撮影にはカメラとマイクの許可が必要です")
                .foregroundStyle(.white)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
        }
    }
}

/// コントロール無しでテイクをループ再生するプレイヤー
private struct LoopingPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        context.coordinator.configure(view: view, url: url)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        context.coordinator.configure(view: uiView, url: url)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        func configure(view: PlayerUIView, url: URL) {
            guard url != currentURL else { return }
            currentURL = url
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer(items: [item])
            looper = AVPlayerLooper(player: player, templateItem: item)
            self.player = player
            view.playerLayer.player = player
            player.play()
        }
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ShootView(
        store: Store(initialState: ShootFeature.State(scripts: .mock)) {
            ShootFeature()
        }
    )
}
