import ComposableArchitecture
import Foundation

@Reducer
struct ProjectsFeature {
    @ObservableState
    struct State: Equatable {
        var projects: [SBProject] = []
        var loadState: LoadState = .idle
        var base: URL?
    }

    enum Action {
        case task
        case refresh
        case loaded(Result<[SBProject], any Error>)
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

            case .loaded(.success(let projects)):
                state.loadState = .loaded
                state.projects = projects
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
            // ベースURLはロード時に解決してStateに保存し、行のメディアURL組み立てにも使う
            let base = try serverConfig.baseURL(.storyboard)
            state.base = base
            return .run { send in
                await send(.loaded(Result {
                    try await storyboardClient.projects(base: base)
                }))
            }
        } catch {
            state.loadState = .failed(error.localizedDescription)
            return .none
        }
    }
}
