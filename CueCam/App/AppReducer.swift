import ComposableArchitecture

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var home = HomeFeature.State()
        @Presents var shoot: ShootFeature.State?
    }

    enum Action {
        case home(HomeFeature.Action)
        case shoot(PresentationAction<ShootFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {
            case .home(.delegate(.startShooting(let theme))):
                state.shoot = ShootFeature.State(theme: theme)
                return .none

            case .home:
                return .none

            case .shoot(.presented(.delegate(.finished))):
                state.shoot = nil
                return .none

            case .shoot:
                return .none
            }
        }
        .ifLet(\.$shoot, action: \.shoot) {
            ShootFeature()
        }
    }
}
