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
                    // Webのセリフ体モードトグル "3D / FLAT"(タップで切り替え)
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            modeWord("3D", .cylinder)
                            Text("/")
                                .font(.instrumentSerif(22))
                                .foregroundStyle(VSTheme.ink.opacity(0.32))
                            modeWord("FLAT", .flat)
                        }
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
            // 3D/FLATは統合キャンバスが1枚で描き、切替時はモーフィングで遷移する
            SpatialCanvasView(store: store)
        }
    }

    private func modeWord(_ label: String, _ mode: VaultMode) -> some View {
        Text(label)
            .font(.instrumentSerif(22))
            .foregroundStyle(VSTheme.ink.opacity(store.mode == mode ? 0.92 : 0.32))
            .onTapGesture { store.send(.binding(.set(\.mode, mode))) }
    }
}

/// Webの drawTile を再現したカード: paperHiの面 + lineFaintの枠 + 淡い影、
/// メディアを6pt内側に敷き、カード内下部にタイトル帯を持つ。マップとシリンダーで共有。
struct VaultTileView: View {
    let video: VaultVideo
    var size: CGSize = CGSize(width: 120, height: 100)
    let onTap: () -> Void
    let onLongPress: () -> Void

    private static let titleStripHeight: CGFloat = 15
    private static let mediaInset: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            media
                .frame(
                    width: size.width - Self.mediaInset * 2,
                    height: size.height - Self.titleStripHeight - Self.mediaInset * 2
                )
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .padding(Self.mediaInset)

            // タイトル帯(カード内部・下端)
            Text(video.title)
                .font(.system(size: 9))
                .foregroundStyle(VSTheme.ink)
                .lineLimit(1)
                .frame(
                    width: size.width - Self.mediaInset * 2,
                    height: Self.titleStripHeight,
                    alignment: .leading
                )
                .padding(.bottom, Self.mediaInset - 2)
        }
        .frame(width: size.width, height: size.height)
        .background(VSTheme.paperHi)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(VSTheme.lineFaint, lineWidth: 1)
        }
        .shadow(color: VSTheme.ink.opacity(0.09), radius: 5, x: 0, y: 3)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(perform: onLongPress)
    }

    @ViewBuilder
    private var media: some View {
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
}

/// プレースホルダー用の対角線(左上→右下)。
struct DiagonalLine: Shape {
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
