import ComposableArchitecture
import Foundation

@Reducer
struct VaultspaceFeature {
    @ObservableState
    struct State: Equatable {
        var videos: [VaultVideo] = []
        var clipsById: [String: VaultClip] = [:]
        var stillsById: [String: VaultStill] = [:]
        var base: URL?
        var loadState: LoadState = .idle
        var zoom: CGFloat = 1
        @Presents var detail: VideoDetailFeature.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case refresh
        case loaded(Result<VaultManifest, any Error>)
        case videoTapped(String)
        case detail(PresentationAction<VideoDetailFeature.Action>)
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

            case .videoTapped(let id):
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
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            VideoDetailFeature()
        }
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
