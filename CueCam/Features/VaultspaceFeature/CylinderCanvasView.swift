import ComposableArchitecture
import SwiftUI

/// Webの3D(cylinder)モードを再現: カードが回転する円筒の壁面に並び、
/// 奥行き z = (cos(angle)+1)/2 がスケール(0.45+z*0.82)と透明度(0.38+z*0.5)を決める。
/// 自動スピン 0.052 rad/s。横ドラッグで回転(慣性つき)、ピンチで拡大縮小、
/// タップ = Wikiノートへ / 長押し = 詳細シート。
struct CylinderCanvasView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    /// 確定済みの回転角。ドラッグ確定・スピン起点のベース。
    @State private var baseRotation: Double = 0
    /// ドラッグ中の増分。
    @State private var dragDelta: Double = 0
    @State private var isDragging = false
    /// 自動スピンの起点時刻(ドラッグ終了ごとにリセット)。
    @State private var spinEpoch = Date()
    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1

    private static let spinRate = 0.052                    // rad/s (Webと同値)
    private static let zoomRange: ClosedRange<CGFloat> = 0.5...2.2

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let rotation = effectiveRotation(at: timeline.date)
                let videos = store.videos
                ZStack {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        card(video, index: index, count: videos.count, rotation: rotation, in: geo.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(VSTheme.paper)
            .background(alignment: .topLeading) { watermark }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
            .simultaneousGesture(magnifyGesture)
        }
        .clipped()
    }

    // MARK: - カード配置

    @ViewBuilder
    private func card(_ video: VaultVideo, index: Int, count: Int, rotation: Double, in size: CGSize) -> some View {
        let effZoom = (zoom * gestureZoom).clamped(to: Self.zoomRange)
        let step = 2 * .pi / Double(max(count, 1))
        let angle = rotation + Double(index) * step
        let z = (cos(angle) + 1) / 2                       // 0(奥)〜1(手前)
        let scale = (0.45 + z * 0.82) * effZoom
        // Webのジッター: サイズと縦位置を銘柄ごとに散らす(決定的な擬似乱数)
        let tileWidth = 84 + Self.jitter(video.id, 3) * 44
        let portrait = Self.jitter(video.id, 2) > 0.5
        let tileHeight = portrait ? tileWidth * 1.16 : tileWidth * 0.72
        let x = size.width / 2 + sin(angle) * size.width * 0.38
        let y = size.height / 2 + (Self.jitter(video.id, 1) - 0.5) * size.height * 0.34

        VaultTileView(
            video: video,
            size: CGSize(width: tileWidth, height: tileHeight),
            onTap: { store.send(.videoTapped(video.id)) },
            onLongPress: { store.send(.videoDetailRequested(video.id)) }
        )
        .scaleEffect(scale)
        .opacity(0.38 + z * 0.5)
        .position(x: x, y: y)
        .zIndex(z)
        // 奥のカードは触れない(手前のカードとの誤タップ防止)
        .allowsHitTesting(z > 0.55)
    }

    /// 背景の "VAULT" / "3D" ウォーターマーク。
    private var watermark: some View {
        ZStack(alignment: .topLeading) {
            VSTheme.paper
            Text("VAULT")
                .font(.instrumentSerif(110))
                .foregroundStyle(VSTheme.watermark)
                .fixedSize()
                .padding(.leading, 12)
            Text("3D")
                .font(.instrumentSerif(80))
                .foregroundStyle(VSTheme.watermark)
                .fixedSize()
                .padding([.trailing, .bottom], 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 回転・ズーム

    private func effectiveRotation(at date: Date) -> Double {
        var rotation = baseRotation + dragDelta
        if !isDragging {
            rotation += date.timeIntervalSince(spinEpoch) * Self.spinRate
        }
        return rotation
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if !isDragging {
                    // スピン分をベースに焼き込んでからドラッグ追従に切り替える
                    baseRotation = effectiveRotation(at: Date())
                    isDragging = true
                }
                dragDelta = Double(value.translation.width / max(width, 1)) * .pi * 1.4
            }
            .onEnded { value in
                // 慣性: 予測終端との差分を減衰させて足す
                let fling = Double((value.predictedEndTranslation.width - value.translation.width) / max(width, 1)) * .pi * 0.6
                baseRotation += dragDelta + fling
                dragDelta = 0
                spinEpoch = Date()
                isDragging = false
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureZoom = value.magnification
            }
            .onEnded { value in
                zoom = (zoom * value.magnification).clamped(to: Self.zoomRange)
                gestureZoom = 1
            }
    }

    /// 銘柄idから決定的に0..1を返す(Webの per-card jitter 相当)。
    private static func jitter(_ id: String, _ salt: UInt64) -> CGFloat {
        var hash: UInt64 = 5381
        for byte in id.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        hash ^= salt &* 0x9E37_79B9_7F4A_7C15
        return CGFloat(hash % 1000) / 1000
    }
}
