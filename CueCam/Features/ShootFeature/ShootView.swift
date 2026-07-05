import AVFoundation
import AVKit
import ComposableArchitecture
import SwiftUI
import UIKit

/// 横持ちの撮影画面(ダークシネマ = SBTheme)。
/// カメラは16:9のステージにレターボックス表示し、UIはステージ外の余白に置いて映像と重ねない
struct ShootView: View {
    @Bindable var store: StoreOf<ShootFeature>
    @Environment(\.openURL) private var openURL
    @Namespace private var pipNamespace
    @State private var pipExpanded = false

    private static let recordRed = Color.rgb(0xd6453c)
    private static let barHeight: CGFloat = 76

    var body: some View {
        ZStack {
            SBTheme.bg.ignoresSafeArea()

            switch store.phase {
            case .preparing:
                ProgressView()
                    .tint(SBTheme.fg2)

            case .denied:
                deniedView

            case .ready, .recording:
                shootingLayout

            case .reviewing(let url):
                reviewLayout(url: url)

            case .finished:
                finishedView
            }

            if pipExpanded, let reference = store.currentScript?.reference {
                expandedReference(reference)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            OrientationLock.lock(.landscape)
            store.send(.onAppear)
        }
        .onDisappear {
            OrientationLock.lock(.portrait)
        }
        .onChange(of: store.currentScript?.id) {
            pipExpanded = false
        }
    }

    // MARK: - 撮影レイアウト

    private var shootingLayout: some View {
        VStack(spacing: 0) {
            ZStack {
                cameraStage
                stageRails
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if let saveError = store.saveError {
                    saveErrorBanner(saveError)
                        .padding(.top, 10)
                }
            }
            scriptBar
        }
    }

    /// 16:9でレターボックスされたカメラ映像 + フレーミングガイド
    private var cameraStage: some View {
        Group {
            if let session = store.session {
                CameraPreviewView(session: session)
            } else {
                ZStack {
                    SBTheme.bgRaised
                    Text("CAMERA UNAVAILABLE — RUN ON DEVICE")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(SBTheme.fg3)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            FramingGuideOverlay(
                motion: store.currentScript.flatMap(MotionCoach.detect)
            )
            .id(store.currentScript?.id)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SBTheme.hairline, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            if store.phase == .recording {
                recIndicator
                    .padding(.top, 10)
            }
        }
        .padding(.vertical, 10)
    }

    /// ステージ左右の余白に置くコントロール(映像と重ねない)
    private var stageRails: some View {
        HStack {
            // 左レール: 閉じる
            VStack {
                if store.showsClose, store.phase != .recording {
                    closeButton
                }
                Spacer()
            }

            Spacer()

            // 右レール: 参照PiP(上) + 録画ボタン(REFの下の残り空間の中央 — 重ならない)
            VStack(spacing: 0) {
                if let reference = store.currentScript?.reference, !pipExpanded {
                    referenceThumb(reference)
                }
                Spacer()
                recordButton
                Spacer()
            }
            .frame(width: 104)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var recIndicator: some View {
        HStack(spacing: 6) {
            PulsingDot(color: Self.recordRed)
            Text("REC")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(SBTheme.fg1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private func saveErrorBanner(_ message: String) -> some View {
        Text("CAMERA ROLL SAVE FAILED — \(message)")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1)
            .lineLimit(1)
            .foregroundStyle(SBTheme.fg1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(SBTheme.crimson.opacity(0.9), in: Capsule())
    }

    private var closeButton: some View {
        Button {
            store.send(.closeButtonTapped)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBTheme.fg2)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.35), in: Circle())
                .overlay {
                    Circle().strokeBorder(SBTheme.hairlineStrong, lineWidth: 1)
                }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var recordButton: some View {
        Button {
            store.send(.recordButtonTapped)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(SBTheme.fg1.opacity(0.75), lineWidth: 2.5)
                    .frame(width: 64, height: 64)
                if store.phase == .recording {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Self.recordRed)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Self.recordRed)
                        .frame(width: 50, height: 50)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: store.phase)
    }

    // MARK: - 下部スクリプトバー

    private var scriptBar: some View {
        HStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%02d", store.currentIndex + 1))
                    .font(.instrumentSerif(30))
                    .foregroundStyle(SBTheme.fg1)
                Text("/ \(String(format: "%02d", store.scripts.count))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(SBTheme.fg3)
            }

            Rectangle()
                .fill(SBTheme.hairline)
                .frame(width: 1, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                if store.currentScript?.slate != nil || store.currentScript?.techniques.isEmpty == false {
                    HStack(spacing: 8) {
                        if let slate = store.currentScript?.slate {
                            Text(slate)
                                .font(.system(size: 10, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(SBTheme.fg3)
                        }
                        ForEach(store.currentScript?.techniques ?? [], id: \.self) { technique in
                            ShootTechniqueChip(text: technique)
                        }
                    }
                }
                Text(store.currentScript?.text ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SBTheme.fg1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let direction = store.currentScript?.direction {
                    Text(direction)
                        .font(.system(size: 11))
                        .foregroundStyle(SBTheme.fg2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if !store.title.isEmpty {
                Text(store.title)
                    .font(.instrumentSerifItalic(14))
                    .foregroundStyle(SBTheme.fg3)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: Self.barHeight)
        .background(SBTheme.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(SBTheme.hairline).frame(height: 1)
        }
    }

    // MARK: - 参照メディア(お手本)

    private func referenceThumb(_ reference: ShotReference) -> some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                pipExpanded = true
            }
        } label: {
            ReferenceMediaView(reference: reference, isMuted: true)
                .frame(width: 92, height: 115)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(SBTheme.hairlineStrong, lineWidth: 1)
                }
                .overlay(alignment: .bottomLeading) {
                    Text("REF")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(SBTheme.fg1.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(4)
                }
                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .matchedGeometryEffect(id: "reference-pip", in: pipNamespace)
        .id(store.currentScript?.id)
    }

    /// タップで拡大した参照メディア。もう一度タップで閉じる
    private func expandedReference(_ reference: ShotReference) -> some View {
        ZStack {
            SBTheme.bg.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ReferenceMediaView(
                    reference: reference,
                    isMuted: store.phase == .recording,
                    gravity: .resizeAspect
                )
                .matchedGeometryEffect(id: "reference-pip", in: pipNamespace)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 20)

                Text("REFERENCE — TAP TO CLOSE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(SBTheme.fg3)
                    .padding(.bottom, 16)
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                pipExpanded = false
            }
        }
    }

    // MARK: - テイク確認(カメラは消してプレビューに集中)

    private func reviewLayout(url: URL) -> some View {
        VStack(spacing: 0) {
            LoopingPlayerView(url: url, gravity: .resizeAspect)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 10)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TAKE\(store.currentScript?.slate.map { " — \($0)" } ?? "")")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(SBTheme.fg3)
                    Text(store.currentScript?.text ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SBTheme.fg1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 12)

                CineButton("RETAKE", style: .ghost) {
                    store.send(.retakeTapped)
                }
                CineButton("USE TAKE", style: .primary) {
                    store.send(.okTapped)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: Self.barHeight)
            .background(SBTheme.bg)
            .overlay(alignment: .top) {
                Rectangle().fill(SBTheme.hairline).frame(height: 1)
            }
        }
    }

    // MARK: - 完了 / 権限拒否

    private var finishedView: some View {
        VStack(spacing: 20) {
            Text("That's a wrap.")
                .font(.instrumentSerif(38))
                .foregroundStyle(SBTheme.fg1)
            Text("\(store.approvedTakes.count) TAKES — SAVED TO CAMERA ROLL")
                .font(.system(size: 10, design: .monospaced))
                .tracking(2)
                .foregroundStyle(SBTheme.fg3)
            HStack(spacing: 12) {
                CineButton("START OVER", style: .ghost) {
                    store.send(.restartTapped)
                }
                if store.showsClose {
                    CineButton("DONE", style: .primary) {
                        store.send(.closeButtonTapped)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(SBTheme.fg3)
            Text("Camera and microphone access is required to shoot")
                .font(.system(size: 14))
                .foregroundStyle(SBTheme.fg2)
            CineButton("OPEN SETTINGS", style: .primary) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - 共有コンポーネント

/// ダークシネマ調のボタン。primary = 温白フィル、ghost = ヘアライン枠
struct CineButton: View {
    enum Style {
        case primary, ghost
    }

    let label: String
    let style: Style
    let action: () -> Void

    init(_ label: String, style: Style, action: @escaping () -> Void) {
        self.label = label
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(style == .primary ? SBTheme.bg : SBTheme.fg2)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background {
                    if style == .primary {
                        Capsule().fill(SBTheme.fg1)
                    }
                }
                .overlay {
                    if style == .ghost {
                        Capsule().strokeBorder(SBTheme.hairlineStrong, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// 押下で軽く沈むフィードバック
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// RECの点滅ドット
struct PulsingDot: View {
    let color: Color
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(dimmed ? 0.25 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

/// 参照メディアの中身(クリップ=ループ再生 / 静止画)。サイズ・装飾は呼び出し側で付ける
struct ReferenceMediaView: View {
    let reference: ShotReference
    var isMuted = true
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    var body: some View {
        Group {
            if reference.isClip {
                LoopingPlayerView(url: reference.url, isMuted: isMuted, gravity: gravity)
            } else {
                AsyncImage(url: reference.url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: gravity == .resizeAspect ? .fit : .fill)
                } placeholder: {
                    Rectangle().fill(SBTheme.bgRaised)
                }
            }
        }
    }
}

/// techniqueチップ。StoryboardFeature の TechniqueTag と同意匠だが、
/// ShootCam ターゲットに StoryboardFeature を含めないためローカル定義
struct ShootTechniqueChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(SBTheme.fg2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay {
                Capsule().strokeBorder(SBTheme.hairline, lineWidth: 1)
            }
    }
}

/// コントロール無しでループ再生するプレイヤー(テイク確認・参照PiPで共用)
private struct LoopingPlayerView: UIViewRepresentable {
    let url: URL
    var isMuted = false
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = gravity
        context.coordinator.configure(view: view, url: url, isMuted: isMuted)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.videoGravity = gravity
        context.coordinator.configure(view: uiView, url: url, isMuted: isMuted)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        func configure(view: PlayerUIView, url: URL, isMuted: Bool) {
            if url != currentURL {
                currentURL = url
                let item = AVPlayerItem(url: url)
                let player = AVQueuePlayer(items: [item])
                looper = AVPlayerLooper(player: player, templateItem: item)
                self.player = player
                view.playerLayer.player = player
                player.play()
            }
            player?.isMuted = isMuted
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
