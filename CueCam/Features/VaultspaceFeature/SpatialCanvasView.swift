import ComposableArchitecture
import SwiftUI

/// 3D(シリンダー)と FLAT(2Dマップ)を1枚のキャンバスで描く統合ビュー。
/// 各カードの位置・スケール・透明度をシリンダー座標とマップ座標の間で補間するので、
/// モード切替時は回転する円筒が散開(バースト)してマップへ整列するモーフィングになる。
///
/// シリンダーはWebと同じ配置則: z=(cos+1)/2, scale=0.45+z*0.82, alpha=0.38+z*0.5,
/// 自動スピン0.052rad/s。3Dは横ドラッグ=回転、FLATはドラッグ=パン。ピンチは共通ズーム。
struct SpatialCanvasView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    // シリンダー回転
    @State private var baseRotation: Double = 0
    @State private var dragDelta: Double = 0
    @State private var isDragging = false
    @State private var spinEpoch = Date()
    // 共通ズーム / FLATパン
    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var dragPan: CGSize = .zero
    // モード遷移の進行(0=3D, 1=FLAT)。TimelineViewのtickで自前トゥイーンする
    @State private var transitionStart: Date?
    @State private var tAtStart: Double = 0

    private static let spinRate = 0.052                     // rad/s (Webと同値)
    private static let zoomRange: ClosedRange<CGFloat> = 0.5...2.6
    private static let transitionDuration: Double = 0.72
    /// 縦方向の散らばり(画面高さに対する比)。中央に固まらないよう上下いっぱいに使う
    private static let verticalSpread: CGFloat = 0.78

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isSettledFlat)) { timeline in
                let now = timeline.date
                let t = progress(at: now)
                let rotation = effectiveRotation(at: now)
                let flat = flatNormalizedPositions()
                let videos = store.videos
                ZStack {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        card(
                            video,
                            index: index,
                            count: videos.count,
                            rotation: rotation,
                            t: t,
                            flatNorm: flat[video.id],
                            in: geo.size
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(VSTheme.paper)
            .background(alignment: .topLeading) { watermark }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: geo.size))
            .simultaneousGesture(magnifyGesture)
        }
        .clipped()
        .onChange(of: store.mode) { _, _ in
            // 現在の進行位置から目標モードへトゥイーンを張り直す(連打しても連続)
            tAtStart = progress(at: Date())
            transitionStart = Date()
        }
    }

    /// FLATに完全に落ち着いたらtickを止める(自動スピン不要・電池対策)。
    private var isSettledFlat: Bool {
        guard store.mode == .flat else { return false }
        guard let start = transitionStart else { return true }
        return Date().timeIntervalSince(start) > Self.transitionDuration
    }

    // MARK: - カード

    @ViewBuilder
    private func card(
        _ video: VaultVideo,
        index: Int,
        count: Int,
        rotation: Double,
        t: Double,
        flatNorm: CGPoint?,
        in size: CGSize
    ) -> some View {
        let effZoom = (zoom * gestureZoom).clamped(to: Self.zoomRange)

        // --- シリンダー座標(Webの配置則 + 縦ジッターを画面全域に) ---
        let step = 2 * .pi / Double(max(count, 1))
        let angle = rotation + Double(index) * step
        let z = (cos(angle) + 1) / 2
        let cylScale = (0.45 + z * 0.82) * effZoom
        let cylX = size.width / 2 + sin(angle) * size.width * 0.38
        let cylY = size.height / 2 + (Self.jitter(video.id, 1) - 0.5) * size.height * Self.verticalSpread
        let cylAlpha = 0.38 + z * 0.5

        // --- FLAT座標(map正規化 → 画面より広いキャンバスに展開、パン追従) ---
        let norm = flatNorm ?? CGPoint(x: 0.5, y: 0.5)
        let panX = panOffset.width + dragPan.width
        let panY = panOffset.height + dragPan.height
        let flatX = size.width / 2 + (norm.x - 0.5) * size.width * 2.3 * effZoom + panX
        let flatY = size.height / 2 + (norm.y - 0.5) * size.height * 1.7 * effZoom + panY
        let flatScale = 0.95 * effZoom

        // --- 補間 + 散開バースト(遷移中点で中心から外向きに膨らむ) ---
        let x = Self.lerp(cylX, flatX, t)
        let y = Self.lerp(cylY, flatY, t)
        let dx = x - size.width / 2
        let dy = y - size.height / 2
        let dist = max(sqrt(dx * dx + dy * dy), 1)
        let burst = CGFloat(sin(t * .pi)) * 70
        let finalX = x + dx / dist * burst
        let finalY = y + dy / dist * burst

        let scale = Self.lerp(cylScale, flatScale, t)
        let alpha = Self.lerp(cylAlpha, 1.0, t)
        let zIndexValue = Self.lerp(CGFloat(z), Self.jitter(video.id, 4), t)

        // カードごとのサイズジッター(Webの per-card jitter)
        let tileWidth = 84 + Self.jitter(video.id, 3) * 44
        let portrait = Self.jitter(video.id, 2) > 0.5
        let tileHeight = portrait ? tileWidth * 1.16 : tileWidth * 0.72

        VaultTileView(
            video: video,
            size: CGSize(width: tileWidth, height: tileHeight),
            onTap: { store.send(.videoTapped(video.id)) },
            onLongPress: { store.send(.videoDetailRequested(video.id)) }
        )
        .scaleEffect(scale)
        .opacity(alpha)
        .position(x: finalX, y: finalY)
        .zIndex(Double(zIndexValue))
        // 3Dでは奥のカードに触れない(誤タップ防止)。FLATは全カード可
        .allowsHitTesting(t > 0.5 || z > 0.55)
    }

    /// 背景の "VAULT" + モード名ウォーターマーク。
    private var watermark: some View {
        ZStack(alignment: .topLeading) {
            VSTheme.paper
            Text("VAULT")
                .font(.instrumentSerif(110))
                .foregroundStyle(VSTheme.watermark)
                .fixedSize()
                .padding(.leading, 12)
            Text(store.mode == .flat ? "FLAT" : "3D")
                .font(.instrumentSerif(80))
                .foregroundStyle(VSTheme.watermark)
                .fixedSize()
                .padding([.trailing, .bottom], 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 遷移・回転・ジェスチャ

    /// モード遷移の進行(0=3D→1=FLAT)。easeInOutCubicで自前トゥイーン。
    private func progress(at date: Date) -> Double {
        let target: Double = store.mode == .flat ? 1 : 0
        guard let start = transitionStart else { return target }
        let raw = min(max(date.timeIntervalSince(start) / Self.transitionDuration, 0), 1)
        let eased = raw < 0.5 ? 4 * raw * raw * raw : 1 - pow(-2 * raw + 2, 3) / 2
        return tAtStart + (target - tAtStart) * eased
    }

    private func effectiveRotation(at date: Date) -> Double {
        var rotation = baseRotation + dragDelta
        if !isDragging {
            rotation += date.timeIntervalSince(spinEpoch) * Self.spinRate
        }
        return rotation
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if store.mode == .flat {
                    dragPan = value.translation
                } else {
                    if !isDragging {
                        // スピン分をベースに焼き込んでからドラッグ追従に切り替える
                        baseRotation = effectiveRotation(at: Date())
                        isDragging = true
                    }
                    dragDelta = Double(value.translation.width / max(size.width, 1)) * .pi * 1.4
                }
            }
            .onEnded { value in
                if store.mode == .flat {
                    panOffset.width += value.translation.width
                    panOffset.height += value.translation.height
                    dragPan = .zero
                } else {
                    // 慣性: 予測終端との差分を減衰させて足す
                    let fling = Double((value.predictedEndTranslation.width - value.translation.width) / max(size.width, 1)) * .pi * 0.6
                    baseRotation += dragDelta + fling
                    dragDelta = 0
                    spinEpoch = Date()
                    isDragging = false
                }
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

    // MARK: - helpers

    /// video.map のmin/maxを0..1に正規化(FLATレイアウトの元座標)。
    private func flatNormalizedPositions() -> [String: CGPoint] {
        var raw: [String: VaultPoint] = [:]
        for video in store.videos {
            if let point = video.map { raw[video.id] = point }
        }
        guard !raw.isEmpty else { return [:] }
        let xs = raw.values.map(\.x)
        let ys = raw.values.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let spanX = max(maxX - minX, .ulpOfOne)
        let spanY = max(maxY - minY, .ulpOfOne)
        var result: [String: CGPoint] = [:]
        for (id, point) in raw {
            result[id] = CGPoint(
                x: CGFloat((point.x - minX) / spanX),
                y: CGFloat((point.y - minY) / spanY)
            )
        }
        return result
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
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
