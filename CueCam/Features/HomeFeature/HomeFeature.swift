import ComposableArchitecture

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var theme = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startButtonTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case startShooting(theme: String)
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .startButtonTapped:
                let theme = state.theme.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !theme.isEmpty else { return .none }
                return .send(.delegate(.startShooting(theme: theme)))

            case .delegate:
                return .none
            }
        }
    }
}
