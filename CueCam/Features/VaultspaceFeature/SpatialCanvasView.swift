import ComposableArchitecture
import SwiftUI

/// 3D(シリンダー)と FLAT(2Dマップ)を1枚のキャンバスで描く統合ビュー。
/// 各カードの位置・スケール・透明度をシリンダー座標とマップ座標の間で補間し、
/// モード切替はカードごとに時間差をつけた散開(スタッガー)モーフィングで遷移する。
///
/// シリンダーはWebと同じ配置則: z=(cos+1)/2, scale=0.45+z*0.82, alpha=0.38+z*0.5,
/// 自動スピン0.052rad/s。3Dは横ドラッグ=回転(指数減衰モメンタム)、FLATはドラッグ=パン。
/// ピンチは共通ズーム。描画はProMotionのフルリフレッシュレート。
struct SpatialCanvasView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    // シリンダー回転
    @State private var baseRotation: Double = 0
    @State private var dragDelta: Double = 0
    @State private var isDragging = false
    @State private var spinEpoch = Date()
    // フリックの指数減衰モメンタム(rad/s、τ秒で減衰し自動スピンに溶ける)
    @State private var flingVelocity: Double = 0
    @State private var flingEpoch = Date()
    // 共通ズーム / FLATパン
    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var dragPan: CGSize = .zero
    // モード遷移(0=3D, 1=FLAT)。TimelineViewのtickで自前トゥイーン
    @State private var transitionStart: Date?
    @State private var tAtStart: Double = 0
    // FLAT座標はビデオ一覧が変わった時だけ正規化し直す(毎フレーム計算しない)
    @State private var flatPositions: [String: CGPoint] = [:]

    private static let spinRate = 0.052                     // rad/s (Webと同値)
    private static let flingTau = 0.85                      // モメンタム減衰の時定数(s)
    private static let zoomRange: ClosedRange<CGFloat> = 0.5...2.6
    private static let transitionDuration: Double = 0.85
    /// カードごとの出発遅延の最大値。全体が一斉に動かず波のように散開する
    private static let staggerMax: Double = 0.22
    /// 縦方向の散らばり(画面高さに対する比)
    private static let verticalSpread: CGFloat = 0.78

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: isSettledFlat)) { timeline in
                let now = timeline.date
                let raw = rawProgress(at: now)
                let target: Double = store.mode == .flat ? 1 : 0
                let rotation = effectiveRotation(at: now)
                let videos = store.videos
                ZStack {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        card(
                            video,
                            index: index,
                            count: videos.count,
                            rotation: rotation,
                            raw: raw,
                            target: target,
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
            tAtStart = currentGlobalT(at: Date())
            transitionStart = Date()
        }
        .onAppear { rebuildFlatPositions(); prefetchPosters() }
        .onChange(of: store.videos) { _, _ in
            rebuildFlatPositions()
            prefetchPosters()
        }
    }

    /// FLATに完全に落ち着いたらtickを止める(自動スピン不要・電池対策)。
    private var isSettledFlat: Bool {
        guard store.mode == .flat else { return false }
        guard let start = transitionStart else { return true }
        return Date().timeIntervalSince(start) > Self.transitionDuration + Self.staggerMax
    }

    // MARK: - カード

    @ViewBuilder
    private func card(
        _ video: VaultVideo,
        index: Int,
        count: Int,
        rotation: Double,
        raw: Double,
        target: Double,
        in size: CGSize
    ) -> some View {
        let effZoom = (zoom * gestureZoom).clamped(to: Self.zoomRange)

        // --- カード固有の遷移進行(スタッガー + cineイージング) ---
        let stagger = Double(Self.jitter(video.id, 5)) * Self.staggerMax
        let local = min(max((raw * (Self.transitionDuration + Self.staggerMax) - stagger) / Self.transitionDuration, 0), 1)
        let eased = Self.cineEase(local)
        let t = tAtStart + (target - tAtStart) * eased

        // --- シリンダー座標(Webの配置則 + 縦ジッターを画面全域に) ---
        let step = 2 * .pi / Double(max(count, 1))
        let angle = rotation + Double(index) * step
        let z = (cos(angle) + 1) / 2
        let cylScale = (0.45 + z * 0.82) * effZoom
        let cylX = size.width / 2 + sin(angle) * size.width * 0.38
        let cylY = size.height / 2 + (Self.jitter(video.id, 1) - 0.5) * size.height * Self.verticalSpread
        let cylAlpha = 0.38 + z * 0.5

        // --- FLAT座標(map正規化 → 画面より広いキャンバスに展開、パン追従) ---
        let norm = flatPositions[video.id] ?? CGPoint(x: 0.5, y: 0.5)
        let panX = panOffset.width + dragPan.width
        let panY = panOffset.height + dragPan.height
        let flatX = size.width / 2 + (norm.x - 0.5) * size.width * 2.3 * effZoom + panX
        let flatY = size.height / 2 + (norm.y - 0.5) * size.height * 1.7 * effZoom + panY
        let flatScale = 0.95 * effZoom

        // --- 補間 + 散開バースト(中間点で中心から外向きに膨らみ、わずかに傾く) ---
        let x = Self.lerp(cylX, flatX, t)
        let y = Self.lerp(cylY, flatY, t)
        let dx = x - size.width / 2
        let dy = y - size.height / 2
        let dist = max(sqrt(dx * dx + dy * dy), 1)
        let wave = CGFloat(sin(t * .pi))
        let burst = wave * (40 + Self.jitter(video.id, 6) * 24)
        let finalX = x + dx / dist * burst
        let finalY = y + dy / dist * burst
        let tilt = Double(Self.jitter(video.id, 7) - 0.5) * 9 * Double(wave)

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
        .rotationEffect(.degrees(tilt))
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
                .contentTransition(.opacity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 遷移・回転・ジェスチャ

    /// 遷移の線形進行(0..1)。スタッガー分を含む全長で正規化する。
    private func rawProgress(at date: Date) -> Double {
        guard let start = transitionStart else { return 1 }
        return min(max(date.timeIntervalSince(start) / (Self.transitionDuration + Self.staggerMax), 0), 1)
    }

    /// スタッガーを無視した全体代表の進行位置(モード連打時の張り直し用)。
    private func currentGlobalT(at date: Date) -> Double {
        let target: Double = store.mode == .flat ? 1 : 0
        let raw = rawProgress(at: date)
        let local = min(max(raw * (Self.transitionDuration + Self.staggerMax) / Self.transitionDuration, 0), 1)
        return tAtStart + (target - tAtStart) * Self.cineEase(local)
    }

    /// Webの --ease-cine: cubic-bezier(0.22,1,0.36,1) 相当の強いease-out。
    private static func cineEase(_ x: Double) -> Double {
        1 - pow(1 - x, 3.4)
    }

    private func effectiveRotation(at date: Date) -> Double {
        var rotation = baseRotation + dragDelta
        if !isDragging {
            rotation += date.timeIntervalSince(spinEpoch) * Self.spinRate
            // フリック: v0·τ·(1-e^(-t/τ)) — すーっと減速して自動スピンに溶ける
            let dt = date.timeIntervalSince(flingEpoch)
            rotation += flingVelocity * Self.flingTau * (1 - exp(-dt / Self.flingTau))
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
                        // スピン+モメンタム分をベースに焼き込んでからドラッグ追従へ
                        baseRotation = effectiveRotation(at: Date())
                        flingVelocity = 0
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
                    baseRotation += dragDelta
                    dragDelta = 0
                    // 指を離した瞬間の角速度をそのまま引き継ぐ
                    flingVelocity = Double(value.velocity.width / max(size.width, 1)) * .pi * 1.4
                    flingEpoch = Date()
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

    private func prefetchPosters() {
        let urls = store.videos.compactMap { video in
            video.posterUrl.flatMap { MediaURL.url(mediaPath: $0) }
        }
        ThumbnailStore.shared.prefetch(urls)
    }

    /// video.map のmin/maxを0..1に正規化(FLATレイアウトの元座標)。
    private func rebuildFlatPositions() {
        var raw: [String: VaultPoint] = [:]
        for video in store.videos {
            if let point = video.map { raw[video.id] = point }
        }
        guard !raw.isEmpty else {
            flatPositions = [:]
            return
        }
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
        flatPositions = result
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
