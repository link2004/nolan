import ComposableArchitecture
import SwiftUI

/// アプリのルート画面(ホーム)。タブは無く、四隅のタイポグラフィで遷移する:
/// 左下 MAKE VIDEO → Storyboard / 右下 WIKI → Wikiルート / 右上 歯車 → 設定。
struct VaultspaceView: View {
    @Bindable var store: StoreOf<VaultspaceFeature>
    /// 写真→Wikiノートのズームトランジション(AppViewの@Namespace)
    let zoomNamespace: Namespace.ID

    var body: some View {
        content
            // セーフエリア(ステータスバー/ホームインジケータ)まで紙色で貫通させ、
            // システム白との色割れをなくす
            .background(VSTheme.paper.ignoresSafeArea())
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
                    NavigationLink(state: AppReducer.Path.State.settings(SettingsFeature.State())) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(VSTheme.ink)
                    }
                }
            }
            // ヘッダーは塗りではなくグラデーションフェードで馴染ませる(下のoverlay参照)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                .overlay {
                    // ヘッダー(ステータスバー+ナビバー)と下端の両方を紙色フェードで覆う。
                    // ignoresSafeAreaをコンテナ全体にかけてバーの裏まで確実に届かせる
                    VStack(spacing: 0) {
                        edgeFade(.top)
                        Spacer()
                        edgeFade(.bottom)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) { zoomSourceAnchor }
                .overlay(alignment: .bottomLeading) {
                    cornerLink("MAKE VIDEO", state: .storyboard(ProjectsFeature.State()))
                }
                .overlay(alignment: .bottomTrailing) {
                    cornerLink("WIKI", state: .wiki(WikiFeature.State()))
                }
        }
    }

    /// 画面上下の紙色グラデーションフェード。カードが端でヘッダー/四隅の文字と
    /// 重なっても読めるよう、端に向かって紙に溶ける。
    private func edgeFade(_ edge: VerticalAlignment) -> some View {
        LinearGradient(
            stops: [
                .init(color: VSTheme.paper, location: 0),
                .init(color: VSTheme.paper.opacity(0.9), location: 0.45),
                .init(color: VSTheme.paper.opacity(0), location: 1),
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: 150)
    }

    /// タップした写真の矩形に透明なアンカーを重ね、ズームトランジションの発火元にする。
    @ViewBuilder
    private var zoomSourceAnchor: some View {
        if let anchor = store.zoomAnchor {
            Color.clear
                .frame(width: anchor.rect.width, height: anchor.rect.height)
                .matchedTransitionSource(id: anchor.slug, in: zoomNamespace)
                .offset(x: anchor.rect.minX, y: anchor.rect.minY)
                .allowsHitTesting(false)
        }
    }

    /// Webの四隅タイポグラフィ(透明・セリフ・ink 86%)。
    private func cornerLink(_ label: String, state: AppReducer.Path.State) -> some View {
        NavigationLink(state: state) {
            Text(label)
                .font(.instrumentSerif(22))
                .foregroundStyle(VSTheme.ink.opacity(0.86))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
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
            // ダウンサンプル済みキャッシュから即描画。未取得ならリクエストして
            // 完了時にふわっとフェードイン(AsyncImageのフルデコードは使わない)
            let thumbnail = ThumbnailStore.shared.image(for: url)
            ZStack {
                VSTheme.paperLow
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.28), value: thumbnail != nil)
            .onAppear { ThumbnailStore.shared.request(url) }
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
