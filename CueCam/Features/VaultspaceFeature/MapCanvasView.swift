import ComposableArchitecture
import SwiftUI

struct VaultspaceView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Vaultspace")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Webのセリフ体モードトグルを模したタイトル(操作は不要なので表示のみ)
                    ToolbarItem(placement: .principal) {
                        Text("VAULT · FLAT")
                            .font(.instrumentSerif(22))
                            .foregroundStyle(VSTheme.ink)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.send(.refresh)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(VSTheme.ink)
                        }
                    }
                }
                .toolbarBackground(VSTheme.paper, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        // Vaultspaceタブは常に紙のライトテーマで描く(Webと同一の世界観)
        .preferredColorScheme(.light)
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
            VideoDetailView(store: detailStore)
        }
        .task { store.send(.task) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Loading manifest…")
                .tint(VSTheme.charcoal)
                .foregroundStyle(VSTheme.charcoal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VSTheme.paper)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
                .foregroundStyle(VSTheme.charcoal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VSTheme.paper)
        case .loaded:
            MapCanvasView(store: store)
        }
    }
}

/// 2Dマップ本体。map座標を正規化して仮想キャンバスに配置し、ピンチでズームする。
struct MapCanvasView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    /// ピンチ中の一時倍率。確定時に store.zoom に畳み込む。
    @State private var gestureZoom: CGFloat = 1

    private static let canvasSize: CGFloat = 3000
    private static let padding: CGFloat = 200
    /// Webの drawTile 相当: カード全体 120×100(上部にメディア、下部に~15ptのタイトル帯)
    private static let tileSize = CGSize(width: 120, height: 100)
    private static let titleStripHeight: CGFloat = 15
    private static let mediaInset: CGFloat = 6
    private static let zoomRange: ClosedRange<CGFloat> = 0.4...3.0

    var body: some View {
        let zoom = effectiveZoom
        let side = Self.canvasSize * zoom
        let positions = normalizedPositions()

        ScrollView([.horizontal, .vertical]) {
            ZStack {
                ForEach(store.videos) { video in
                    if let point = positions[video.id] {
                        thumbnail(for: video)
                            .position(x: point.x * zoom, y: point.y * zoom)
                    }
                }
            }
            .frame(width: side, height: side)
        }
        .defaultScrollAnchor(.center)
        .background(VSTheme.paper)
        // Web版の巨大ウォーターマーク。可視領域に固定で敷く(キャンバスと一緒にスクロールしない)
        .background(alignment: .topLeading) {
            watermark
        }
        .gesture(magnifyGesture)
    }

    /// 背景の "VAULT" / "FLAT" ウォーターマーク。
    private var watermark: some View {
        ZStack(alignment: .topLeading) {
            VSTheme.paper
            Text("VAULT")
                .font(.instrumentSerif(110))
                .foregroundStyle(VSTheme.watermark)
                .fixedSize()
                .padding(.leading, 12)
            Text("FLAT")
                .font(.instrumentSerif(80))
                .foregroundStyle(VSTheme.watermark)
                .fixedSize()
                .padding([.trailing, .bottom], 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var effectiveZoom: CGFloat {
        (store.zoom * gestureZoom).clamped(to: Self.zoomRange)
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureZoom = value.magnification
            }
            .onEnded { value in
                // 確定倍率をclampして保存。キャンバス全体をスケールするので
                // アンカー中央のScrollViewが位置を自然に追従する
                store.zoom = (store.zoom * value.magnification).clamped(to: Self.zoomRange)
                gestureZoom = 1
            }
    }

    /// Webの drawTile を再現したカード: paperHiの面 + lineFaintの枠 + 淡い影、
    /// メディアを6pt内側に敷き、カード内下部にタイトル帯を持つ。
    private func thumbnail(for video: VaultVideo) -> some View {
        VStack(spacing: 0) {
            tileMedia(for: video)
                .frame(
                    width: Self.tileSize.width - Self.mediaInset * 2,
                    height: Self.tileSize.height - Self.titleStripHeight - Self.mediaInset * 2
                )
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .padding(Self.mediaInset)

            // タイトル帯(カード内部・下端)
            Text(video.title)
                .font(.system(size: 9))
                .foregroundStyle(VSTheme.ink)
                .lineLimit(1)
                .frame(
                    width: Self.tileSize.width - Self.mediaInset * 2,
                    height: Self.titleStripHeight,
                    alignment: .leading
                )
                .padding(.bottom, Self.mediaInset - 2)
        }
        .frame(width: Self.tileSize.width, height: Self.tileSize.height)
        .background(VSTheme.paperHi)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(VSTheme.lineFaint, lineWidth: 1)
        }
        .shadow(color: VSTheme.ink.opacity(0.09), radius: 5, x: 0, y: 3)
        // タップ = Wikiノートへ / 長押し = クリップ・スチルの詳細シート
        .onTapGesture { store.send(.videoTapped(video.id)) }
        .onLongPressGesture { store.send(.videoDetailRequested(video.id)) }
    }

    @ViewBuilder
    private func tileMedia(for video: VaultVideo) -> some View {
        if let posterUrl = video.posterUrl,
           let url = MediaURL.url(mediaPath: posterUrl) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                VSTheme.paperLow
            }
        } else {
            // ポスターなし: paperLowに斜線1本 + タイプ名(Webのプレースホルダー)
            VSTheme.paperLow
                .overlay {
                    DiagonalLine()
                        .stroke(VSTheme.line, lineWidth: 1)
                }
                .overlay {
                    Text(video.videoTypeLabel ?? "VIDEO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(VSTheme.ink)
                        .lineLimit(1)
                }
        }
    }

    /// space.positions(なければvideo.map)のmin/maxを取り、パディング込みの
    /// 3000ptキャンバス座標へ正規化する。
    private func normalizedPositions() -> [String: CGPoint] {
        var raw: [String: VaultPoint] = [:]
        for video in store.videos {
            if let point = video.map {
                raw[video.id] = point
            }
        }
        guard !raw.isEmpty else { return [:] }

        let xs = raw.values.map(\.x)
        let ys = raw.values.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let spanX = max(maxX - minX, .ulpOfOne)
        let spanY = max(maxY - minY, .ulpOfOne)
        let usable = Self.canvasSize - Self.padding * 2

        var result: [String: CGPoint] = [:]
        for (id, point) in raw {
            result[id] = CGPoint(
                x: Self.padding + CGFloat((point.x - minX) / spanX) * usable,
                y: Self.padding + CGFloat((point.y - minY) / spanY) * usable
            )
        }
        return result
    }
}

/// プレースホルダー用の対角線(左上→右下)。
private struct DiagonalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
