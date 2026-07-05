import ComposableArchitecture
import Foundation

@Reducer
struct BoardFeature {
    @ObservableState
    struct State: Equatable {
        let note: String
        let title: String
        var base: URL?
        var board: SBBoard?
        var loadState: LoadState = .idle
        @Presents var shoot: ShootFeature.State?

        init(note: String, title: String) {
            self.note = note
            self.title = title
        }
    }

    enum Action {
        case task
        case refresh
        case loaded(Result<SBBoard, any Error>)
        case shootButtonTapped
        case shoot(PresentationAction<ShootFeature.Action>)
    }

    @Dependency(\.storyboardClient) var storyboardClient
    @Dependency(\.serverConfig) var serverConfig
    @Dependency(\.cameraClient) var cameraClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.loadState == .idle || state.loadState.isFailure else { return .none }
                return load(&state)

            case .refresh:
                return load(&state)

            case .loaded(.success(let board)):
                state.loadState = .loaded
                state.board = board
                return .none

            case .loaded(.failure(let error)):
                state.loadState = .failed(error.localizedDescription)
                return .none

            case .shootButtonTapped:
                guard let board = state.board else { return .none }
                let scripts = board.shotScripts
                guard !scripts.isEmpty else { return .none }
                state.shoot = ShootFeature.State(
                    scripts: scripts,
                    title: board.title,
                    showsClose: true
                )
                return .none

            case .shoot(.presented(.delegate(.close))):
                state.shoot = nil
                // presentが閉じてもカメラセッションは生きているので明示的に止める
                return .run { _ in await cameraClient.stopSession() }

            case .shoot:
                return .none
            }
        }
        .ifLet(\.$shoot, action: \.shoot) {
            ShootFeature()
        }
    }

    private func load(_ state: inout State) -> Effect<Action> {
        state.loadState = .loading
        do {
            let base = try serverConfig.baseURL(.storyboard)
            state.base = base
            let note = state.note
            return .run { send in
                await send(.loaded(Result {
                    try await storyboardClient.board(base: base, note: note)
                }))
            }
        } catch {
            state.loadState = .failed(error.localizedDescription)
            return .none
        }
    }
}
