import ComposableArchitecture
import SwiftUI

struct VaultspaceView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Vaultspace")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.send(.refresh)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
            VideoDetailView(store: detailStore)
        }
        .task { store.send(.task) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("マニフェストを読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorRetryView(message: message) { store.send(.refresh) }
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
    private static let thumbSize = CGSize(width: 120, height: 68)
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
        .background(Color(.systemGroupedBackground))
        .gesture(magnifyGesture)
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

    private func thumbnail(for video: VaultVideo) -> some View {
        VStack(spacing: 4) {
            Group {
                if let base = store.base, let posterUrl = video.posterUrl,
                   let url = MediaURL.url(base: base, mediaPath: posterUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemFill)
                    }
                } else {
                    Color(.systemFill)
                        .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                }
            }
            .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)

            Text(video.title)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: Self.thumbSize.width)
        }
        .onTapGesture { store.send(.videoTapped(video.id)) }
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

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
