import ComposableArchitecture
import SwiftUI

/// 3D(シリンダー)と FLAT(2Dマップ)を1枚の`Canvas`(Metal即時描画)で描く統合ビュー。
///
/// Webと同じ設計: ビュー階層を持たず、毎フレーム90枚のタイルを直接描画する。
/// SwiftUIビュー90枚を120Hzで差分評価する構造的な重さを丸ごと除去した。
/// - 配置則(Web準拠): z=(cos+1)/2, scale=0.45+z*0.82, alpha=0.38+z*0.5, 自動スピン0.052rad/s
/// - 遷移: from/toを明示したトゥイーン + カードごとのスタッガー + cineイージング + バースト
/// - ズーム: カメラモデル。FLATはピンチ位置を不動点に世界が寄る、3Dはドリーイン
/// - FLATの既定(zoom=1)のタイルサイズが基準。起動時は必ずこの見た目
struct SpatialCanvasView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    // シリンダー回転
    @State private var baseRotation: Double = 0
    @State private var dragDelta: Double = 0
    @State private var isDragging = false
    @State private var spinEpoch = Date()
    // フリックの指数減衰モメンタム(τ秒で減衰し自動スピンに溶ける)
    @State private var flingVelocity: Double = 0
    @State private var flingEpoch = Date()
    // カメラ(共通ズーム / FLATパン / 3Dの上下トラック)
    @State private var zoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var dragPan: CGSize = .zero
    @State private var cylPanY: CGFloat = 0
    @State private var dragCylPanY: CGFloat = 0
    // ピンチ中の基準値(ピンチ位置を不動点にするための開始スナップショット)
    @State private var pinchAnchor: CGPoint?
    @State private var pinchStartZoom: CGFloat = 1
    @State private var pinchStartPan: CGSize = .zero
    // モード遷移: from→to を明示(モード切替時に現在位置から張り直す)
    @State private var transitionStart: Date?
    @State private var tFrom: Double = 0
    @State private var tTo: Double = 0
    // 長押しの位置(タッチ追跡)
    @State private var lastTouch: CGPoint = .zero
    // FLAT座標はビデオ一覧が変わった時だけ正規化し直す
    @State private var flatPositions: [String: CGPoint] = [:]
    // 背景の分類軸ラベル(モック寄り: 実タイプがあればクラスタ重心、なければ固定配置)
    @State private var axisLabels: [(label: String, norm: CGPoint)] = []

    private static let spinRate = 0.052
    private static let flingTau = 0.85
    private static let zoomRange: ClosedRange<CGFloat> = 0.5...3.0
    private static let transitionDuration: Double = 0.85
    private static let staggerMax: Double = 0.22
    private static let verticalSpread: CGFloat = 1.1
    /// シリンダーの横の広がり(画面幅比)と縮小率。重なりを減らすため広く・小さく
    private static let cylinderSpreadX: CGFloat = 0.46
    private static let cylinderScaleFactor: CGFloat = 0.8
    /// FLATの世界の広がり(画面比)。タイルを小さく+広がりを増やして重なりを減らす
    private static let flatSpreadX: CGFloat = 2.6
    private static let flatSpreadY: CGFloat = 2.0

    /// タイルの既定サイズ(zoom=1)。群全体に対して控えめにして重なりを抑える。
    private static func tileBaseSize(for id: String) -> (width: CGFloat, height: CGFloat) {
        let width = 66 + jitter(id, 3) * 34
        let portrait = jitter(id, 2) > 0.5
        return (width, portrait ? width * 1.16 : width * 0.72)
    }

    /// 1タイルの描画パラメータ(レイアウト計算とヒットテストで共有)。
    private struct CardLayout {
        let video: VaultVideo
        let center: CGPoint
        let size: CGSize
        let alpha: Double
        let tilt: Double
        let depth: Double     // シリンダーのz(0..1)
        let order: Double     // 描画順(小さい方が奥)
        let t: Double         // 遷移進行(0=3D, 1=FLAT)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: isSettled)) { timeline in
                // ThumbnailStoreの観測はbody側で読んでCanvasへ渡す(確実に再描画させる)
                let thumbnails = ThumbnailStore.shared.images
                let layouts = computeLayouts(at: timeline.date, in: geo.size)
                Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(VSTheme.paper))
                    drawWatermark(context, size: size)
                    drawAxisLabels(context, size: size)
                    for card in layouts.sorted(by: { $0.order < $1.order }) {
                        draw(card, in: &context, thumbnails: thumbnails)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                handleTap(at: value.location, in: geo.size)
            })
            .gesture(dragGesture(size: geo.size))
            .simultaneousGesture(magnifyGesture(size: geo.size))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { lastTouch = $0.startLocation }
            )
            .onLongPressGesture(minimumDuration: 0.4) {
                handleLongPress(at: lastTouch, in: geo.size)
            }
        }
        .clipped()
        .onChange(of: store.mode) { _, newMode in
            // 現在の進行位置から目標へ張り直す(連打しても連続)
            tFrom = globalT(at: Date())
            tTo = newMode == .flat ? 1 : 0
            transitionStart = Date()
        }
        .onAppear { rebuildFlatPositions(); prefetchPosters() }
        .onChange(of: store.videos) { _, _ in
            rebuildFlatPositions()
            prefetchPosters()
        }
    }

    // MARK: - レイアウト計算(描画とヒットテストの共有ソース)

    private func computeLayouts(at date: Date, in size: CGSize) -> [CardLayout] {
        let videos = store.videos
        guard !videos.isEmpty else { return [] }
        let raw = rawProgress(at: date)
        let rotation = effectiveRotation(at: date)
        let effZoom = zoom
        let step = 2 * .pi / Double(videos.count)
        let panX = panOffset.width + dragPan.width
        let panY = panOffset.height + dragPan.height

        return videos.enumerated().map { index, video in
            // --- カード固有の遷移進行(スタッガー + cineイージング) ---
            let stagger = Double(Self.jitter(video.id, 5)) * Self.staggerMax
            let local = min(max((raw * (Self.transitionDuration + Self.staggerMax) - stagger) / Self.transitionDuration, 0), 1)
            let t = tFrom + (tTo - tFrom) * Self.cineEase(local)

            // --- シリンダー座標(カメラドリー: 広がりもスケールもzoomに追従) ---
            let angle = rotation + Double(index) * step
            let z = (cos(angle) + 1) / 2
            let cylScale = (0.45 + z * 0.82) * Self.cylinderScaleFactor * effZoom
            let cylX = size.width / 2 + sin(angle) * size.width * Self.cylinderSpreadX * effZoom
            let cylY = size.height / 2
                + (Self.jitter(video.id, 1) - 0.5) * size.height * Self.verticalSpread * effZoom
                + cylPanY + dragCylPanY
            // 奥は薄く沈めて手前を際立たせる(密集の視覚ノイズを下げる)
            let cylAlpha = 0.22 + z * 0.78

            // --- FLAT座標(zoom=1が既定サイズ。ピンチはカメラが寄る=世界が広がる) ---
            let norm = flatPositions[video.id] ?? CGPoint(x: 0.5, y: 0.5)
            let flatX = size.width / 2 + (norm.x - 0.5) * size.width * Self.flatSpreadX * effZoom + panX
            let flatY = size.height / 2 + (norm.y - 0.5) * size.height * Self.flatSpreadY * effZoom + panY
            let flatScale = 1.0 * effZoom

            // --- 補間 + 散開バースト ---
            let x = Self.lerp(cylX, flatX, t)
            let y = Self.lerp(cylY, flatY, t)
            let dx = x - size.width / 2
            let dy = y - size.height / 2
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let wave = CGFloat(sin(t * .pi))
            let burst = wave * (40 + Self.jitter(video.id, 6) * 24)
            let tilt = Double(Self.jitter(video.id, 7) - 0.5) * 9 * Double(wave)

            let scale = Self.lerp(cylScale, flatScale, t)
            let (baseWidth, baseHeight) = Self.tileBaseSize(for: video.id)

            return CardLayout(
                video: video,
                center: CGPoint(x: x + dx / dist * burst, y: y + dy / dist * burst),
                size: CGSize(width: baseWidth * scale, height: baseHeight * scale),
                alpha: Self.lerp(cylAlpha, 1.0, t),
                tilt: tilt,
                depth: z,
                order: Self.lerp(CGFloat(z), Self.jitter(video.id, 4), t),
                t: t
            )
        }
    }

    // MARK: - 描画

    private func draw(_ card: CardLayout, in context: inout GraphicsContext, thumbnails: [String: UIImage]) {
        let w = card.size.width
        let h = card.size.height
        guard w > 6 else { return }

        context.drawLayer { ctx in
            ctx.opacity = card.alpha
            ctx.translateBy(x: card.center.x, y: card.center.y)
            if abs(card.tilt) > 0.05 {
                ctx.rotate(by: .degrees(card.tilt))
            }

            let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
            let cardPath = Path(roundedRect: rect, cornerRadius: 2)

            // 影は手前のカードだけ(Webと同じ。全カード影はGPUを食う)
            if card.depth > 0.72 || card.t > 0.6 {
                ctx.addFilter(.shadow(color: VSTheme.ink.opacity(0.12), radius: 4, x: 0, y: 2.5))
            }
            ctx.fill(cardPath, with: .color(VSTheme.paperHi))

            // メディア(内側インセット + 下端のタイトル帯はWebのdrawTile準拠)
            let inset = min(max(w * 0.06, 3), 9)
            let strip = min(15, h * 0.2)
            let mediaRect = CGRect(
                x: rect.minX + inset,
                y: rect.minY + inset,
                width: w - inset * 2,
                height: h - inset * 2 - strip
            )
            if let posterUrl = card.video.posterUrl,
               let url = MediaURL.url(mediaPath: posterUrl),
               let uiImage = thumbnails[url.absoluteString] {
                ctx.drawLayer { media in
                    media.clip(to: Path(roundedRect: mediaRect, cornerRadius: 1))
                    // aspect-fill
                    let iw = uiImage.size.width
                    let ih = uiImage.size.height
                    let fill = max(mediaRect.width / iw, mediaRect.height / ih)
                    let drawSize = CGSize(width: iw * fill, height: ih * fill)
                    media.draw(
                        Image(uiImage: uiImage),
                        in: CGRect(
                            x: mediaRect.midX - drawSize.width / 2,
                            y: mediaRect.midY - drawSize.height / 2,
                            width: drawSize.width,
                            height: drawSize.height
                        )
                    )
                }
            } else {
                ctx.fill(Path(roundedRect: mediaRect, cornerRadius: 1), with: .color(VSTheme.paperLow))
                var line = Path()
                line.move(to: CGPoint(x: mediaRect.minX, y: mediaRect.minY))
                line.addLine(to: CGPoint(x: mediaRect.maxX, y: mediaRect.maxY))
                ctx.stroke(line, with: .color(VSTheme.line), lineWidth: 1)
            }

            // タイトル帯(手前 or FLATのみ。奥の小さいカードには描かない — Web準拠)
            if w > 68, card.depth > 0.56 || card.t > 0.5 {
                let title = Text(card.video.title)
                    .font(.system(size: 9))
                    .foregroundColor(VSTheme.ink)
                ctx.drawLayer { text in
                    text.clip(to: cardPath)
                    text.draw(
                        title,
                        in: CGRect(
                            x: rect.minX + inset,
                            y: rect.maxY - strip - 1,
                            width: w - inset * 2,
                            height: strip
                        )
                    )
                }
            }

            ctx.stroke(cardPath, with: .color(VSTheme.lineFaint), lineWidth: 1)
        }
    }

    /// 背景の分類軸ラベル。FLATの世界座標に置くのでパン/ズームに追従し、
    /// 地図の地名のようにカードの背後にうっすら見える。
    private func drawAxisLabels(_ context: GraphicsContext, size: CGSize) {
        guard !axisLabels.isEmpty else { return }
        let panX = panOffset.width + dragPan.width
        let panY = panOffset.height + dragPan.height
        for item in axisLabels {
            let x = size.width / 2 + (item.norm.x - 0.5) * size.width * 2.3 * zoom + panX
            let y = size.height / 2 + (item.norm.y - 0.5) * size.height * 1.7 * zoom + panY
            let text = Text(item.label.uppercased())
                .font(.instrumentSerifItalic(26))
                .foregroundColor(VSTheme.ink.opacity(0.11))
            context.draw(text, at: CGPoint(x: x, y: y))
        }
    }

    private func drawWatermark(_ context: GraphicsContext, size: CGSize) {
        let vault = Text("VAULT").font(.instrumentSerif(110)).foregroundColor(VSTheme.watermark)
        context.draw(vault, at: CGPoint(x: 24, y: 70), anchor: .leading)
        let mode = Text(store.mode == .flat ? "FLAT" : "3D")
            .font(.instrumentSerif(80))
            .foregroundColor(VSTheme.watermark)
        context.draw(mode, at: CGPoint(x: size.width - 24, y: size.height - 60), anchor: .trailing)
    }

    // MARK: - ヒットテスト(タップ=Wiki / 長押し=詳細)

    private func hitTest(at point: CGPoint, in size: CGSize) -> VaultVideo? {
        let layouts = computeLayouts(at: Date(), in: size)
        // 手前(orderが大きい)から探す。3Dでは奥のカードは無効
        for card in layouts.sorted(by: { $0.order > $1.order }) {
            guard card.t > 0.5 || card.depth > 0.55 else { continue }
            let rect = CGRect(
                x: card.center.x - card.size.width / 2,
                y: card.center.y - card.size.height / 2,
                width: card.size.width,
                height: card.size.height
            )
            if rect.insetBy(dx: -4, dy: -4).contains(point) {
                return card.video
            }
        }
        return nil
    }

    private func handleTap(at point: CGPoint, in size: CGSize) {
        if let video = hitTest(at: point, in: size) {
            store.send(.videoTapped(video.id))
        }
    }

    private func handleLongPress(at point: CGPoint, in size: CGSize) {
        if let video = hitTest(at: point, in: size) {
            store.send(.videoDetailRequested(video.id))
        }
    }

    // MARK: - 遷移・回転・ジェスチャ

    /// 全カードが目標に到達しFLATで静止していたらtickを止める(電池対策)。
    private var isSettled: Bool {
        guard store.mode == .flat else { return false }
        guard let start = transitionStart else { return true }
        return Date().timeIntervalSince(start) > Self.transitionDuration + Self.staggerMax
    }

    private func rawProgress(at date: Date) -> Double {
        guard let start = transitionStart else { return 1 }
        return min(max(date.timeIntervalSince(start) / (Self.transitionDuration + Self.staggerMax), 0), 1)
    }

    /// スタッガー抜きの代表進行位置(モード連打時の張り直し用)。
    private func globalT(at date: Date) -> Double {
        let raw = rawProgress(at: date)
        let local = min(max(raw * (Self.transitionDuration + Self.staggerMax) / Self.transitionDuration, 0), 1)
        return tFrom + (tTo - tFrom) * Self.cineEase(local)
    }

    /// Webの --ease-cine: cubic-bezier(0.22,1,0.36,1) 相当の強いease-out。
    private static func cineEase(_ x: Double) -> Double {
        1 - pow(1 - x, 3.4)
    }

    private func effectiveRotation(at date: Date) -> Double {
        var rotation = baseRotation + dragDelta
        if !isDragging {
            rotation += date.timeIntervalSince(spinEpoch) * Self.spinRate
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
                        baseRotation = effectiveRotation(at: Date())
                        flingVelocity = 0
                        isDragging = true
                    }
                    // 横 = 回転 / 縦 = 上下トラック(カメラの高さ移動)
                    dragDelta = Double(value.translation.width / max(size.width, 1)) * .pi * 1.4
                    dragCylPanY = value.translation.height
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
                    cylPanY += value.translation.height
                    dragCylPanY = 0
                    flingVelocity = Double(value.velocity.width / max(size.width, 1)) * .pi * 1.4
                    flingEpoch = Date()
                    spinEpoch = Date()
                    isDragging = false
                }
            }
    }

    /// カメラ型ズーム: ピンチ位置を不動点に世界がスケールする(FLAT)。
    /// 3Dはドリーイン(広がりとスケールが同時に迫る)。
    private func magnifyGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchAnchor == nil {
                    pinchAnchor = value.startLocation
                    pinchStartZoom = zoom
                    pinchStartPan = panOffset
                }
                let newZoom = (pinchStartZoom * value.magnification).clamped(to: Self.zoomRange)
                zoom = newZoom
                if store.mode == .flat, let anchor = pinchAnchor {
                    // p = C + w·zoom + pan の不動点解: pan' = (a−C) − (a−C−pan₀)·(zoom'/zoom₀)
                    let ax = anchor.x - size.width / 2
                    let ay = anchor.y - size.height / 2
                    let ratio = newZoom / max(pinchStartZoom, 0.001)
                    panOffset = CGSize(
                        width: ax - (ax - pinchStartPan.width) * ratio,
                        height: ay - (ay - pinchStartPan.height) * ratio
                    )
                }
            }
            .onEnded { _ in
                pinchAnchor = nil
            }
    }

    // MARK: - helpers

    private func prefetchPosters() {
        let urls = store.videos.compactMap { video in
            video.posterUrl.flatMap { MediaURL.url(mediaPath: $0) }
        }
        ThumbnailStore.shared.prefetch(urls)
    }

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
        flatPositions = relaxOverlaps(result)
        rebuildAxisLabels()
    }

    /// 重なり解消の緩和計算。zoom=1のFLATワールドをptで再現し、
    /// タイル同士が食い込んでいるペアを浅い軸方向に押し離す(40イテレーション)。
    /// マップの全体形状(クラスタ感)は保ちつつ、密集部だけほどける。
    private func relaxOverlaps(_ normalized: [String: CGPoint]) -> [String: CGPoint] {
        // 代表的な画面サイズでのワールド寸法(比率が合っていれば十分)
        let worldW: CGFloat = 393 * Self.flatSpreadX
        let worldH: CGFloat = 760 * Self.flatSpreadY
        let gap: CGFloat = 10  // タイル間に最低確保する余白

        struct Body {
            let id: String
            var x: CGFloat
            var y: CGFloat
            let halfW: CGFloat
            let halfH: CGFloat
        }
        var bodies: [Body] = normalized.map { id, norm in
            let (w, h) = Self.tileBaseSize(for: id)
            return Body(id: id, x: norm.x * worldW, y: norm.y * worldH, halfW: (w + gap) / 2, halfH: (h + gap) / 2)
        }
        guard bodies.count > 1 else { return normalized }

        for _ in 0..<40 {
            var moved = false
            for i in 0..<(bodies.count - 1) {
                for j in (i + 1)..<bodies.count {
                    let dx = bodies[j].x - bodies[i].x
                    let dy = bodies[j].y - bodies[i].y
                    let overlapX = bodies[i].halfW + bodies[j].halfW - abs(dx)
                    let overlapY = bodies[i].halfH + bodies[j].halfH - abs(dy)
                    guard overlapX > 0, overlapY > 0 else { continue }
                    moved = true
                    // 食い込みの浅い軸方向へ半分ずつ押し離す
                    if overlapX < overlapY {
                        let push = overlapX / 2 * (dx >= 0 ? 1 : -1)
                        bodies[i].x -= push
                        bodies[j].x += push
                    } else {
                        let push = overlapY / 2 * (dy >= 0 ? 1 : -1)
                        bodies[i].y -= push
                        bodies[j].y += push
                    }
                }
            }
            if !moved { break }
        }

        // 押し出しで広がった分ごと0..1に再正規化(全体は常に収まる)
        let xs = bodies.map(\.x)
        let ys = bodies.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let spanX = max(maxX - minX, 1)
        let spanY = max(maxY - minY, 1)
        var result: [String: CGPoint] = [:]
        for body in bodies {
            result[body.id] = CGPoint(x: (body.x - minX) / spanX, y: (body.y - minY) / spanY)
        }
        return result
    }

    /// 分類軸ラベルを組み立てる(見た目だけのモック)。
    /// videoTypeLabel のクラスタ重心に置くと「なんとなく分類されている」ように見える。
    /// タイプが乏しいときは定番ワードを固定配置で足す。
    private func rebuildAxisLabels() {
        var clusters: [String: [CGPoint]] = [:]
        for video in store.videos {
            guard let type = video.videoTypeLabel, !type.isEmpty,
                  let norm = flatPositions[video.id] else { continue }
            clusters[type, default: []].append(norm)
        }
        var labels: [(label: String, norm: CGPoint)] = clusters
            .filter { $0.value.count >= 3 }
            .map { label, points in
                let cx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
                let cy = points.map(\.y).reduce(0, +) / CGFloat(points.count)
                return (label, CGPoint(x: cx, y: cy))
            }
            .sorted { $0.label < $1.label }
        labels = Array(labels.prefix(8))

        let mocks: [(String, CGPoint)] = [
            ("Vlog", CGPoint(x: 0.16, y: 0.22)),
            ("Launch Video", CGPoint(x: 0.78, y: 0.28)),
            ("Self Storytelling", CGPoint(x: 0.26, y: 0.78)),
            ("Brand Film", CGPoint(x: 0.82, y: 0.74)),
        ]
        for mock in mocks where labels.count < 4 {
            if !labels.contains(where: { $0.label.caseInsensitiveCompare(mock.0) == .orderedSame }) {
                labels.append(mock)
            }
        }
        axisLabels = labels
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
