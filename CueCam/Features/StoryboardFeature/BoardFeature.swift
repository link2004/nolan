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

        init(note: String, title: String) {
            self.note = note
            self.title = title
        }
    }

    enum Action {
        case task
        case refresh
        case loaded(Result<SBBoard, any Error>)
    }

    @Dependency(\.storyboardClient) var storyboardClient
    @Dependency(\.serverConfig) var serverConfig

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
            }
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
