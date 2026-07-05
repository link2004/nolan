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

            if store.showsClose, store.phase != .recording {
                closeButton
            }
        }
        .statusBarHidden()
        .onAppear {
            OrientationLock.lock(.landscape)
            store.send(.onAppear)
        }
        .onDisappear {
            OrientationLock.lock(.portrait)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Button {
                    store.send(.closeButtonTapped)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Spacer()
        }
        .padding(16)
    }

    // MARK: - 撮影中オーバーレイ

    private var shootingOverlay: some View {
        ZStack {
            if store.session == nil {
                Text("Camera unavailable (run on a physical device)")
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("\(store.currentIndex + 1)/\(store.scripts.count)")
                    .font(.footnote.bold().monospacedDigit())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColor.accent, in: Capsule())

                if let slate = store.currentScript?.slate {
                    Text(slate)
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.6))
                }

                ForEach(store.currentScript?.techniques ?? [], id: \.self) { technique in
                    ShootTechniqueChip(text: technique)
                }

                Spacer(minLength: 0)

                if !store.title.isEmpty {
                    Text(store.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Text(store.currentScript?.text ?? "")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let direction = store.currentScript?.direction {
                Text(direction)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
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
                    Button("Retake") { store.send(.retakeTapped) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Button("OK, Next") { store.send(.okTapped) }
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
            Text("All \(store.scripts.count) shots complete!")
                .font(.title3.bold())
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                Button("Start Over") { store.send(.restartTapped) }
                    .buttonStyle(.bordered)
                    .tint(.white)
                if store.showsClose {
                    Button("Done") { store.send(.closeButtonTapped) }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.accent)
                }
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
            Text("Camera and microphone access is required to shoot")
                .foregroundStyle(.white)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
        }
    }
}

/// techniqueチップ。StoryboardFeature の TechniqueTag と同意匠だが、
/// ShootCam ターゲットに StoryboardFeature を含めないためローカル定義
struct ShootTechniqueChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1)
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
