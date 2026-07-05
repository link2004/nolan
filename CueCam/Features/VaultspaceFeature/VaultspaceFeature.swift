import ComposableArchitecture
import Foundation

/// Webの "3D / FLAT" トグルに対応する表示モード。
enum VaultMode: String, Equatable, Sendable {
    case cylinder  // 3D: 回転するシリンダー
    case flat      // FLAT: 2Dマップ
}

@Reducer
struct VaultspaceFeature {
    @ObservableState
    struct State: Equatable {
        var mode: VaultMode = .cylinder
        var videos: [VaultVideo] = []
        var clipsById: [String: VaultClip] = [:]
        var stillsById: [String: VaultStill] = [:]
        var base: URL?
        var loadState: LoadState = .idle
        var zoom: CGFloat = 1
        @Presents var detail: VideoDetailFeature.State?
        /// ズームトランジションの発火元(タップした写真のスクリーン座標)
        var zoomAnchor: ZoomAnchor?
    }

    struct ZoomAnchor: Equatable, Sendable {
        let slug: String
        let rect: CGRect
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case refresh
        case loaded(Result<VaultManifest, any Error>)
        case videoTapped(String, sourceRect: CGRect?)
        case videoDetailRequested(String)
        case detail(PresentationAction<VideoDetailFeature.Action>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case openWikiNote(WikiNoteRef)
        }
    }

    @Dependency(\.vaultspaceClient) var vaultspaceClient
    @Dependency(\.serverConfig) var serverConfig

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                guard state.loadState == .idle || state.loadState.isFailure else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case .loaded(.success(let manifest)):
                state.loadState = .loaded
                state.videos = manifest.videos
                // idの重複はデータ異常だが、クラッシュせず先勝ちで拾う
                state.clipsById = Dictionary(manifest.clips.map { ($0.id, $0) }) { first, _ in first }
                state.stillsById = Dictionary(manifest.stills.map { ($0.id, $0) }) { first, _ in first }
                return .none

            case .loaded(.failure(let error)):
                state.loadState = .failed(error.localizedDescription)
                return .none

            // タップ = そのビデオのWikiノートへ(wikiUrlが無いものは詳細シートへフォールバック)
            case .videoTapped(let id, let sourceRect):
                guard let video = state.videos.first(where: { $0.id == id }) else { return .none }
                if let ref = Self.wikiRef(for: video) {
                    // アンカーを先に置いてから遷移(matchedTransitionSourceが1フレーム先行する)
                    if let sourceRect {
                        state.zoomAnchor = ZoomAnchor(slug: ref.slug, rect: sourceRect)
                    }
                    return .send(.delegate(.openWikiNote(ref)))
                }
                return .send(.videoDetailRequested(id))

            case .videoDetailRequested(let id):
                guard let video = state.videos.first(where: { $0.id == id }) else { return .none }
                let clips = (video.clipIds ?? []).compactMap { state.clipsById[$0] }
                let stills = (video.stillIds ?? []).compactMap { state.stillsById[$0] }
                state.detail = VideoDetailFeature.State(
                    video: video,
                    clips: clips,
                    stills: stills,
                    base: state.base
                )
                return .none

            case .detail:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            VideoDetailFeature()
        }
    }

    /// wikiUrl(例: https://wiki.tenkstudios.com/References/Library/…)のパスをデコードして
    /// contentIndexのslugに変換する。
    static func wikiRef(for video: VaultVideo) -> WikiNoteRef? {
        guard let raw = video.wikiUrl, let url = URL(string: raw) else { return nil }
        let slug = (url.path.removingPercentEncoding ?? url.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !slug.isEmpty else { return nil }
        return WikiNoteRef(slug: slug, title: video.title)
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.loadState = .loading
        do {
            state.base = try serverConfig.baseURL(.vaultspace)
        } catch {
            state.loadState = .failed(error.localizedDescription)
            return .none
        }
        let base = state.base!
        return .run { send in
            await send(.loaded(Result {
                try await vaultspaceClient.manifest(base)
            }))
        }
    }
}
